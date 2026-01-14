import SwiftUI

/// Main view for an opened repository.
/// Uses NavigationSplitView for three-column layout.
struct RepositoryView: View {
    let repository: Repository
    @State private var viewModel: RepositoryViewModel

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    init(repository: Repository) {
        self.repository = repository
        self._viewModel = State(initialValue: RepositoryViewModel(repository: repository))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: File tree
            FileTreePlaceholder()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } content: {
            // Content: Code editor with tabs
            CodeEditorAreaView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // Detail: Git history
            GitHistoryPlaceholder()
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 500)
        }
        .navigationTitle(repository.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .task {
            await viewModel.load()
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

/// Placeholder for File Tree (to be implemented in Phase 2).
struct FileTreePlaceholder: View {
    var body: some View {
        PlaceholderView(icon: "folder.fill", title: "File Tree", subtitle: "Coming in Phase 2")
    }
}

/// Placeholder for Git History (to be implemented in Phase 3).
struct GitHistoryPlaceholder: View {
    var body: some View {
        PlaceholderView(icon: "clock.arrow.circlepath", title: "Git History", subtitle: "Coming in Phase 3")
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
                CodeEditorPlaceholder(tab: selectedTab)
            } else {
                EmptyEditorView()
            }
        }
    }
}

/// Placeholder for Code Editor (to be implemented in Phase 2).
struct CodeEditorPlaceholder: View {
    let tab: TabItem

    var body: some View {
        PlaceholderView(icon: "doc.text", title: tab.title, subtitle: "Code Editor - Coming in Phase 2")
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
