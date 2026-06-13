import SwiftUI

/// Debug logging helper - writes to file for easier debugging
private func debugLog(_ message: String) {
    let logFile = URL(fileURLWithPath: "/tmp/codevoyager_debug.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
    print(message)
}

/// Main view for an opened repository.
/// Uses NavigationSplitView for three-column layout.
struct RepositoryView: View {
    let repository: Repository
    @State private var viewModel: RepositoryViewModel
    @State private var fileTreeViewModel: FileTreeViewModel
    @State private var gitHistoryViewModel: GitHistoryViewModel

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    init(repository: Repository) {
        self.repository = repository
        self._viewModel = State(initialValue: RepositoryViewModel(repository: repository))
        self._fileTreeViewModel = State(initialValue: FileTreeViewModel(repository: repository))
        self._gitHistoryViewModel = State(initialValue: GitHistoryViewModel(repository: repository))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: File tree
            FileTreeView(viewModel: fileTreeViewModel) { fileNode in
                Task {
                    await viewModel.openFile(fileNode)
                    // Update Git history to show commits for the selected file
                    let repoPath = repository.url.path
                    let filePath = fileNode.path
                    // Calculate relative path by removing repository root prefix
                    let relativePath = filePath.hasPrefix(repoPath)
                        ? String(filePath.dropFirst(repoPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        : filePath
                    await gitHistoryViewModel.setSelectedFile(relativePath)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } content: {
            // Content: Code editor with tabs
            CodeEditorAreaView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // Detail: Git history
            GitHistoryView(viewModel: gitHistoryViewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 500)
        }
        .navigationTitle(repository.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await fileTreeViewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .task {
            debugLog("[RepositoryView] Task started for: \(repository.url.path)")
            // Load file tree and git history
            await viewModel.load()
            await gitHistoryViewModel.loadInitialData()
            debugLog("[RepositoryView] Task completed")
        }
    }
}

/// Generic placeholder view for features not yet implemented.
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Area containing tabs and code editor.
struct CodeEditorAreaView: View {
    @Bindable var viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(tabs: $viewModel.tabs, selectedTab: $viewModel.selectedTabID)

            // Editor content
            if let selectedTab = viewModel.selectedTab {
                FileContentView(viewModel: viewModel, tab: selectedTab)
            } else {
                EmptyEditorView()
            }
        }
    }
}

/// View that displays file content based on loading state.
struct FileContentView: View {
    @Bindable var viewModel: RepositoryViewModel
    let tab: TabItem

    /// Local scroll offset that syncs with ViewModel.
    /// Initialized from ViewModel's saved value to preserve position on view recreation.
    @State private var scrollOffset: CGFloat

    /// Whether this is a newly opened file (should scroll to top).
    /// Computed from ViewModel state to survive view recreation.
    private var isNewFile: Bool {
        !viewModel.hasTabBeenViewed(tab.id)
    }

    init(viewModel: RepositoryViewModel, tab: TabItem) {
        self.viewModel = viewModel
        self.tab = tab
        // Initialize scroll offset from saved value in ViewModel
        self._scrollOffset = State(initialValue: viewModel.getScrollOffset(for: tab.id))
    }

    var body: some View {
        Group {
            switch viewModel.loadingState(for: tab.id) {
            case .idle, .loading:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                if let content = viewModel.fileContent(for: tab.id) {
                    CodeEditorView(
                        content: content,
                        fileName: tab.title,
                        scrollOffset: $scrollOffset,
                        isNewFile: isNewFile
                    )
                    .onAppear {
                        // Mark tab as viewed after first appearance
                        if !viewModel.hasTabBeenViewed(tab.id) {
                            viewModel.markTabAsViewed(tab.id)
                        }
                    }
                    .onDisappear {
                        // Save scroll position when leaving this tab
                        viewModel.updateScrollOffset(for: tab.id, offset: scrollOffset)
                    }
                    .onChange(of: scrollOffset) { _, newValue in
                        // Continuously update scroll position in ViewModel
                        viewModel.updateScrollOffset(for: tab.id, offset: newValue)
                    }
                } else {
                    EmptyEditorView()
                }

            case .binaryFile:
                BinaryFilePlaceholder(fileName: tab.title)

            case .largeFile(let size):
                LargeFileWarning(
                    fileName: tab.title,
                    fileSize: size,
                    onConfirm: {
                        Task {
                            await viewModel.forceLoadLargeFile(tabID: tab.id)
                        }
                    }
                )

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("Error loading file")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// View shown when no file is open.
struct EmptyEditorView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No File Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Select a file from the sidebar to view its contents")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RepositoryView(repository: Repository(url: URL(fileURLWithPath: "/tmp/test-repo")))
}
