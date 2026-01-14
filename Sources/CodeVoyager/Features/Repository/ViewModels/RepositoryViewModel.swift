import SwiftUI
import os.log

/// ViewModel for the repository view.
/// Manages tabs, selected file, and repository state.
@MainActor
@Observable
final class RepositoryViewModel {
    // MARK: - Properties

    let repository: Repository

    /// Open tabs
    var tabs: [TabItem] = []

    /// Currently selected tab ID
    var selectedTabID: UUID?

    /// Currently selected tab
    var selectedTab: TabItem? {
        tabs.first { $0.id == selectedTabID }
    }

    /// File contents cache (keyed by tab ID)
    private(set) var fileContents: [UUID: FileContent] = [:]

    /// File loading states (keyed by tab ID)
    private(set) var fileLoadingStates: [UUID: FileLoadingState] = [:]

    /// Loading state
    var isLoading = false

    /// Error message to display
    var errorMessage: String?

    /// File system service
    private let fileSystemService: FileSystemServiceProtocol

    /// Logger
    private let logger = Logger(subsystem: "com.codevoyager", category: "RepositoryViewModel")

    // MARK: - Initialization

    init(repository: Repository, fileSystemService: FileSystemServiceProtocol? = nil) {
        self.repository = repository
        self.fileSystemService = fileSystemService ?? FileSystemService()
    }

    // MARK: - Public Methods

    /// Load initial repository data.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        logger.info("Loading repository: \(self.repository.name)")

        // Check if it's a valid Git repository
        if !repository.isGitRepository {
            errorMessage = "This directory is not a Git repository. Please select a directory containing a .git folder, or initialize a new repository using 'git init' in the terminal."
            logger.warning("Not a Git repository: \(self.repository.path)")
        }
    }

    /// Open a file in a new tab.
    func openFile(_ fileNode: FileNode) async {
        // Check if already open
        if let existingTab = tabs.first(where: { $0.filePath == fileNode.path }) {
            selectedTabID = existingTab.id
            return
        }

        // Create new tab
        let newTab = TabItem(
            type: .file,
            filePath: fileNode.path,
            title: fileNode.name
        )
        tabs.append(newTab)
        selectedTabID = newTab.id

        logger.info("Opened file: \(fileNode.name)")

        // Load file content
        await loadFileContent(for: newTab)
    }

    /// Load file content for a tab.
    private func loadFileContent(for tab: TabItem) async {
        guard let path = tab.filePath else { return }

        fileLoadingStates[tab.id] = .loading

        do {
            let url = URL(fileURLWithPath: path)

            // Check file size first
            let size = try fileSystemService.fileSize(at: url)
            if size > 50 * 1024 * 1024 {
                fileLoadingStates[tab.id] = .largeFile(size: size)
                return
            }

            // Check if binary
            if try await fileSystemService.isBinary(at: url) {
                fileLoadingStates[tab.id] = .binaryFile
                return
            }

            // Read file content
            let content = try await fileSystemService.readFile(at: url)
            fileContents[tab.id] = content
            fileLoadingStates[tab.id] = .loaded

        } catch let error as FileSystemError {
            logger.error("Failed to load file '\(path)': \(error.localizedDescription)")
            fileLoadingStates[tab.id] = .error(error.localizedDescription)
        } catch {
            logger.error("Failed to load file '\(path)': \(error.localizedDescription)")
            fileLoadingStates[tab.id] = .error("Failed to read file: \(error.localizedDescription)")
        }
    }

    /// Force load a large file after user confirmation.
    func forceLoadLargeFile(tabID: UUID) async {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              let path = tab.filePath else { return }

        fileLoadingStates[tabID] = .loading

        do {
            let url = URL(fileURLWithPath: path)
            let content = try await fileSystemService.readFile(at: url)
            fileContents[tabID] = content
            fileLoadingStates[tabID] = .loaded
        } catch {
            logger.error("Failed to load large file '\(path)': \(error.localizedDescription)")
            fileLoadingStates[tabID] = .error("Failed to read large file: \(error.localizedDescription)")
        }
    }

    /// Get file content for a tab.
    func fileContent(for tabID: UUID) -> FileContent? {
        fileContents[tabID]
    }

    /// Get loading state for a tab.
    func loadingState(for tabID: UUID) -> FileLoadingState {
        fileLoadingStates[tabID] ?? .idle
    }

    // MARK: - Scroll Position Management

    /// Update the scroll offset for a tab.
    /// - Parameters:
    ///   - tabID: The ID of the tab to update.
    ///   - offset: The new scroll offset value.
    func updateScrollOffset(for tabID: UUID, offset: CGFloat) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].scrollOffset = offset
    }

    /// Get the saved scroll offset for a tab.
    /// - Parameter tabID: The ID of the tab.
    /// - Returns: The saved scroll offset, or 0 if no offset is saved or tab doesn't exist.
    func getScrollOffset(for tabID: UUID) -> CGFloat {
        tabs.first { $0.id == tabID }?.scrollOffset ?? 0
    }

    /// Mark a tab as having been viewed.
    /// After this, the tab will restore its scroll position when switching back instead of scrolling to top.
    /// - Parameter tabID: The ID of the tab to mark.
    func markTabAsViewed(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].hasBeenViewed = true
    }

    /// Check if a tab has been viewed before.
    /// - Parameter tabID: The ID of the tab.
    /// - Returns: true if the tab has been viewed, false if it's a new tab.
    func hasTabBeenViewed(_ tabID: UUID) -> Bool {
        tabs.first { $0.id == tabID }?.hasBeenViewed ?? false
    }

    /// Close a tab.
    func closeTab(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }

        tabs.remove(at: index)

        // Clean up file content and loading state
        fileContents.removeValue(forKey: tabID)
        fileLoadingStates.removeValue(forKey: tabID)

        // Select adjacent tab if closing current
        if selectedTabID == tabID {
            if !tabs.isEmpty {
                let newIndex = min(index, tabs.count - 1)
                selectedTabID = tabs[newIndex].id
            } else {
                selectedTabID = nil
            }
        }
    }

    /// Close all tabs.
    func closeAllTabs() {
        tabs.removeAll()
        fileContents.removeAll()
        fileLoadingStates.removeAll()
        selectedTabID = nil
    }
}

/// Represents a tab in the editor.
/// Note: Hashable is implemented manually to only include immutable properties,
/// preventing issues when mutable state (selectionRange, scrollOffset, hasBeenViewed) changes.
struct TabItem: Identifiable, Hashable {
    let id: UUID
    let type: TabType
    let filePath: String?
    let title: String

    /// Selection state for this tab (preserved when switching tabs)
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var selectionRange: Range<String.Index>?

    /// Scroll position (preserved when switching tabs)
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var scrollOffset: CGFloat = 0

    /// Whether this tab has been viewed at least once.
    /// Used to determine scroll behavior: new tabs scroll to top, viewed tabs restore position.
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var hasBeenViewed: Bool = false

    init(
        id: UUID = UUID(),
        type: TabType,
        filePath: String? = nil,
        title: String
    ) {
        self.id = id
        self.type = type
        self.filePath = filePath
        self.title = title
    }
    
    // MARK: - Hashable (only immutable properties)
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(filePath)
        hasher.combine(title)
    }
    
    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.filePath == rhs.filePath &&
        lhs.title == rhs.title
    }
}

/// Type of tab content.
enum TabType: Hashable {
    case file
    case diff(commitSHA: String)
    case welcome

    /// SF Symbol name for this tab type.
    var iconName: String {
        switch self {
        case .file: "doc.text"
        case .diff: "arrow.left.arrow.right"
        case .welcome: "house"
        }
    }
}

/// Loading state for file content.
enum FileLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case binaryFile
    case largeFile(size: Int64)
    case error(String)
}
