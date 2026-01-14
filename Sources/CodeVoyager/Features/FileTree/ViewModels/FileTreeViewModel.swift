import Foundation
import os.log

/// ViewModel for the file tree sidebar.
/// Manages file tree state including expansion, selection, and lazy loading.
@MainActor
@Observable
final class FileTreeViewModel {
    // MARK: - Properties

    /// Root nodes of the file tree
    private(set) var rootNodes: [FileNode] = []

    /// Version number to force view refresh when tree structure changes
    private(set) var treeVersion: Int = 0

    /// Set of expanded directory IDs
    private(set) var expandedIDs: Set<UUID> = []

    /// Set of directory IDs that failed to load (问题 6 修复)
    private(set) var failedToLoadIDs: Set<UUID> = []

    /// Currently selected file node
    var selectedNode: FileNode?

    /// Loading state
    var isLoading = false

    /// Error message
    var errorMessage: String?

    /// Repository being displayed
    let repository: Repository

    /// File system service
    private let fileSystemService: FileSystemServiceProtocol

    /// Set of gitignored relative paths
    private var gitIgnoredPaths: Set<String> = []

    /// Logger
    private let logger = Logger(subsystem: "com.codevoyager", category: "FileTreeViewModel")

    /// Storage key for expansion state
    private var expansionStorageKey: String {
        "fileTree.expanded.\(repository.url.path.hash)"
    }

    // MARK: - Initialization

    init(repository: Repository, fileSystemService: FileSystemServiceProtocol? = nil) {
        self.repository = repository
        self.fileSystemService = fileSystemService ?? FileSystemService()
        loadExpansionState()
    }

    // MARK: - Public Methods

    /// Load the root level of the file tree.
    func loadRootLevel() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load gitignored paths first (returns empty set on failure, logged as warning)
            gitIgnoredPaths = await fileSystemService.gitIgnoredPaths(in: repository.url)
            logger.debug("Loaded \(self.gitIgnoredPaths.count) gitignored paths")

            // Load root directory contents
            var nodes = try await fileSystemService.contents(of: repository.url)

            // Mark gitignored files
            nodes = markGitIgnoredStatus(nodes)

            rootNodes = nodes
            logger.info("Loaded \(nodes.count) root nodes")

        } catch {
            logger.error("Failed to load file tree: \(error.localizedDescription)")
            errorMessage = "Failed to load files. Please try again."
        }

        isLoading = false
    }

    /// Toggle the expansion state of a directory.
    func toggleExpansion(_ node: FileNode) async {
        guard node.isDirectory else { return }

        logger.debug("toggleExpansion called for: \(node.name), isLoaded: \(node.isLoaded)")

        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
            logger.debug("Collapsed: \(node.name)")
        } else {
            expandedIDs.insert(node.id)
            logger.debug("Expanded: \(node.name), will load children: \(!node.isLoaded)")

            // Load children if not already loaded
            if !node.isLoaded {
                await loadChildren(for: node)
            }
        }

        saveExpansionState()
    }

    /// Check if a directory is expanded.
    func isExpanded(_ node: FileNode) -> Bool {
        expandedIDs.contains(node.id)
    }

    /// Select a file node.
    func selectNode(_ node: FileNode) {
        selectedNode = node
    }

    /// Get children of a node (for OutlineGroup).
    func children(of node: FileNode) -> [FileNode]? {
        guard node.isDirectory else { return nil }
        return node.children?.isEmpty == false ? node.children : nil
    }

    /// Find a node by ID in the tree.
    /// Used by views to get the latest version of a node after updates.
    func findNode(by id: UUID) -> FileNode? {
        findNodeRecursively(in: rootNodes, id: id)
    }

    private func findNodeRecursively(in nodes: [FileNode], id: UUID) -> FileNode? {
        for node in nodes {
            if node.id == id {
                return node
            }
            if let children = node.children,
               let found = findNodeRecursively(in: children, id: id) {
                return found
            }
        }
        return nil
    }

    /// Refresh the file tree.
    func refresh() async {
        await loadRootLevel()
    }

    // MARK: - Private Methods

    /// Load children for a directory node.
    private func loadChildren(for node: FileNode) async {
        // Clear any previous failure state for this node
        failedToLoadIDs.remove(node.id)

        logger.debug("loadChildren started for: \(node.name) at \(node.url.path)")

        do {
            var children = try await fileSystemService.contents(of: node.url)
            logger.debug("Loaded \(children.count) children for \(node.name)")

            // Mark gitignored files
            children = markGitIgnoredStatus(children)

            // Update the node in the tree
            updateNode(node.id, children: children)

            // Verify update
            if let updated = findNode(by: node.id) {
                logger.debug("After update: \(node.name) has \(updated.children?.count ?? 0) children, isLoaded: \(updated.isLoaded)")
            }

        } catch {
            logger.error("Failed to load children for \(node.name): \(error.localizedDescription)")
            // Mark node as failed to load so UI can show error state (问题 6 修复)
            failedToLoadIDs.insert(node.id)
        }
    }
    
    /// Check if a directory failed to load its children.
    func hasLoadError(_ node: FileNode) -> Bool {
        failedToLoadIDs.contains(node.id)
    }
    
    /// Retry loading children for a failed directory.
    func retryLoadChildren(for node: FileNode) async {
        guard node.isDirectory, failedToLoadIDs.contains(node.id) else { return }
        await loadChildren(for: node)
    }

    /// Update a node's children in the tree.
    private func updateNode(_ nodeID: UUID, children: [FileNode]) {
        rootNodes = rootNodes.map { node in
            updateNodeRecursively(node, targetID: nodeID, children: children)
        }
        // Increment version to force view refresh
        treeVersion += 1
        logger.debug("Tree updated, version: \(self.treeVersion)")
    }

    private func updateNodeRecursively(
        _ node: FileNode,
        targetID: UUID,
        children: [FileNode]
    ) -> FileNode {
        if node.id == targetID {
            var updated = node
            updated.children = children
            updated.isLoaded = true
            return updated
        }

        guard let nodeChildren = node.children else { return node }

        var updated = node
        updated.children = nodeChildren.map { child in
            updateNodeRecursively(child, targetID: targetID, children: children)
        }
        return updated
    }

    /// Check if a path is gitignored.
    private func isPathGitIgnored(_ url: URL) -> Bool {
        let relativePath = url.path.replacingOccurrences(
            of: repository.url.path + "/",
            with: ""
        )
        return gitIgnoredPaths.contains(relativePath)
            || gitIgnoredPaths.contains(relativePath + "/")
    }

    /// Mark gitignore status for a list of nodes.
    private func markGitIgnoredStatus(_ nodes: [FileNode]) -> [FileNode] {
        nodes.map { node in
            var updated = node
            updated.isGitIgnored = isPathGitIgnored(node.url)
            return updated
        }
    }

    // MARK: - Expansion State Persistence (TODO: Implement path-based tracking)

    /// Load expansion state from persistent storage.
    /// - Note: Currently not implemented. We can't persist UUID-based expansion across sessions
    ///   because nodes get new UUIDs when reloaded. A future improvement would be to use
    ///   path-based expansion tracking instead of UUID-based.
    private func loadExpansionState() {
        // TODO: Implement path-based expansion state persistence
    }

    /// Save expansion state to persistent storage.
    /// - Note: Currently not implemented. Requires path-based tracking which is planned
    ///   for a future version.
    private func saveExpansionState() {
        // TODO: Implement path-based expansion state persistence
    }
}


// MARK: - Display Helpers

/// Helper for path truncation (not actor-isolated for testability)
enum PathDisplayHelper {
    /// Truncate a long path for display (middle truncation as per PRD).
    /// Example: "src/components/very/long/path/Button.tsx" -> "src/.../Button.tsx"
    static func truncatePath(_ path: String, maxLength: Int = 40) -> String {
        guard path.count > maxLength else { return path }

        let components = path.components(separatedBy: "/")
        guard components.count > 2 else { return path }

        let first = components.first ?? ""
        let last = components.last ?? ""

        // Always return the truncated format since we've already verified:
        // 1. Path is longer than maxLength
        // 2. Path has more than 2 components
        return "\(first)/.../\(last)"
    }
}

extension FileTreeViewModel {
    /// Truncate a long path for display.
    static func truncatePath(_ path: String, maxLength: Int = 40) -> String {
        PathDisplayHelper.truncatePath(path, maxLength: maxLength)
    }
}
