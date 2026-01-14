import SwiftUI
import os.log

/// ViewModel for the repository view.
/// Manages tabs, selected file, and repository state.
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

    /// Loading state
    var isLoading = false

    /// Error message to display
    var errorMessage: String?

    /// Logger
    private let logger = Logger(subsystem: "com.codevoyager", category: "RepositoryViewModel")

    // MARK: - Initialization

    init(repository: Repository) {
        self.repository = repository
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
    func openFile(_ fileNode: FileNode) {
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
    }

    /// Close a tab.
    func closeTab(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }

        tabs.remove(at: index)

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
        selectedTabID = nil
    }
}

/// Represents a tab in the editor.
/// Note: Hashable is implemented manually to only include immutable properties,
/// preventing issues when mutable state (selectionRange, scrollOffset) changes.
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
