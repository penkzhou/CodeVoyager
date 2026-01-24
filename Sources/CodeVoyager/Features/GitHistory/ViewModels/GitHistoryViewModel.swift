import Foundation
import OSLog

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

/// Loading state for async operations.
enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

/// ViewModel for Git commit history.
///
/// Manages the state for displaying commit history, including:
/// - Paginated commit list
/// - Branch and tag information
/// - Commit selection and details
///
/// ## Thread Safety
/// This class is marked `@MainActor` to ensure all UI state updates happen on the main thread.
///
/// ## Usage
/// ```swift
/// let viewModel = GitHistoryViewModel(repository: repo)
/// await viewModel.loadInitialData()
/// ```
@MainActor
@Observable
final class GitHistoryViewModel {
    private static let logger = Logger(subsystem: "com.codevoyager", category: "GitHistoryViewModel")

    // MARK: - Public State

    /// All loaded commits (paginated)
    private(set) var commits: [Commit] = []

    /// All branches in the repository
    private(set) var branches: [Branch] = []

    /// All tags in the repository
    private(set) var tags: [Tag] = []

    /// Currently selected commit
    var selectedCommit: Commit?

    /// Files changed in the selected commit
    private(set) var selectedCommitFiles: [ChangedFile] = []

    /// Current loading state
    private(set) var loadingState: LoadingState = .idle

    /// Whether more commits are available to load
    private(set) var hasMoreCommits = true

    /// Currently selected file path (relative to repository root).
    /// When set, only commits that modified this file are shown.
    private(set) var selectedFilePath: String?

    /// Index mapping commit SHA to branches pointing to it
    private(set) var branchesBySHA: [String: [Branch]] = [:]

    /// Index mapping commit SHA to tags pointing to it
    private(set) var tagsBySHA: [String: [Tag]] = [:]

    // MARK: - Private State

    /// Number of commits to fetch per page
    private let pageSize = 500

    /// Current pagination offset
    private var currentOffset = 0

    /// Repository being viewed
    private let repository: Repository

    /// Git service for data fetching
    private let gitService: GitServiceProtocol

    /// Whether initial load has completed
    private var hasLoadedInitially = false

    // MARK: - Initialization

    /// Creates a new GitHistoryViewModel.
    ///
    /// - Parameters:
    ///   - repository: The repository to display history for
    ///   - gitService: Git service for data operations. Defaults to GitCLIService.
    init(repository: Repository, gitService: GitServiceProtocol? = nil) {
        self.repository = repository
        self.gitService = gitService ?? GitCLIService()
    }

    // MARK: - Public Methods

    /// Loads initial data: commits, branches, and tags.
    ///
    /// This performs parallel fetches for optimal performance.
    /// Call this when the view first appears.
    func loadInitialData() async {
        guard !hasLoadedInitially else {
            Self.logger.debug("Initial data already loaded, skipping")
            return
        }

        Self.logger.info("Starting to load initial data for repository: \(self.repository.url.path)")
        debugLog("[GitHistory] Starting to load for: \(repository.url.path)")

        loadingState = .loading

        do {
            // Fetch commits, branches, and tags in parallel
            debugLog("[GitHistory] Fetching commits...")
            async let commitsTask = fetchCommits(offset: 0)
            async let branchesTask = gitService.branches(in: repository.url)
            async let tagsTask = gitService.tags(in: repository.url)

            let (fetchedCommits, fetchedBranches, fetchedTags) = try await (
                commitsTask,
                branchesTask,
                tagsTask
            )

            debugLog("[GitHistory] Fetched \(fetchedCommits.count) commits")

            commits = fetchedCommits
            branches = fetchedBranches
            tags = fetchedTags

            // Build SHA indexes for quick lookup
            buildIndexes()

            // Update pagination state
            currentOffset = commits.count
            hasMoreCommits = fetchedCommits.count >= pageSize

            hasLoadedInitially = true
            debugLog("[GitHistory] Setting loadingState to .loaded")
            loadingState = .loaded
            debugLog("[GitHistory] loadingState is now: \(self.loadingState)")

            Self.logger.info("Loaded \(fetchedCommits.count) commits, \(fetchedBranches.count) branches, \(fetchedTags.count) tags")
            debugLog("[GitHistory] Done loading: \(fetchedCommits.count) commits")
        } catch {
            Self.logger.error("Failed to load initial data: \(error.localizedDescription)")
            debugLog("[GitHistory] ERROR: \(error)")
            loadingState = .error(error.localizedDescription)
        }
    }

    /// Loads more commits for infinite scrolling.
    ///
    /// Call this when the user scrolls near the end of the list.
    func loadMoreCommits() async {
        guard hasMoreCommits else {
            Self.logger.debug("No more commits to load")
            return
        }

        guard loadingState != .loading else {
            Self.logger.debug("Already loading, skipping")
            return
        }

        do {
            let newCommits = try await fetchCommits(offset: currentOffset)

            commits.append(contentsOf: newCommits)
            currentOffset = commits.count
            hasMoreCommits = newCommits.count >= pageSize

            Self.logger.debug("Loaded \(newCommits.count) more commits, total: \(self.commits.count)")
        } catch {
            Self.logger.error("Failed to load more commits: \(error.localizedDescription)")
            // Don't change loading state for pagination errors
        }
    }

    /// Selects a commit and loads its changed files.
    ///
    /// - Parameter commit: The commit to select, or nil to clear selection
    func selectCommit(_ commit: Commit?) async {
        selectedCommit = commit
        selectedCommitFiles = []

        guard let commit = commit else {
            return
        }

        do {
            selectedCommitFiles = try await gitService.changedFiles(
                for: commit.sha,
                in: repository.url
            )
            Self.logger.debug("Loaded \(self.selectedCommitFiles.count) changed files for \(commit.shortSHA)")
        } catch {
            Self.logger.error("Failed to load changed files for \(commit.shortSHA): \(error.localizedDescription)")
        }
    }

    /// Sets the file to filter commit history by.
    ///
    /// When a file is selected, only commits that modified that file are shown.
    /// Pass `nil` to clear the filter and show all commits.
    ///
    /// - Parameter filePath: Relative path to the file, or nil to show all commits
    func setSelectedFile(_ filePath: String?) async {
        // Skip if the file hasn't changed
        guard selectedFilePath != filePath else { return }

        Self.logger.info("Setting selected file to: \(filePath ?? "nil")")
        selectedFilePath = filePath

        // Clear current commits and reload with the new filter
        commits = []
        selectedCommit = nil
        selectedCommitFiles = []
        currentOffset = 0
        hasMoreCommits = true
        hasLoadedInitially = false

        await loadInitialData()
    }

    /// Refreshes all data.
    ///
    /// Clears existing data and reloads from scratch.
    func refresh() async {
        commits = []
        branches = []
        tags = []
        selectedCommit = nil
        selectedCommitFiles = []
        branchesBySHA = [:]
        tagsBySHA = [:]
        currentOffset = 0
        hasMoreCommits = true
        hasLoadedInitially = false

        await loadInitialData()
    }

    // MARK: - Helper Methods

    /// Returns branches pointing to a specific commit.
    func branches(for commitSHA: String) -> [Branch] {
        branchesBySHA[commitSHA] ?? []
    }

    /// Returns tags pointing to a specific commit.
    func tags(for commitSHA: String) -> [Tag] {
        tagsBySHA[commitSHA] ?? []
    }

    // MARK: - Private Methods

    private func fetchCommits(offset: Int) async throws -> [Commit] {
        if let filePath = selectedFilePath {
            return try await gitService.commits(
                forFile: filePath,
                in: repository.url,
                limit: pageSize,
                offset: offset
            )
        } else {
            return try await gitService.commits(
                in: repository.url,
                limit: pageSize,
                offset: offset
            )
        }
    }

    /// Builds SHA -> branches/tags indexes for O(1) lookup.
    private func buildIndexes() {
        branchesBySHA = [:]
        tagsBySHA = [:]

        for branch in branches {
            branchesBySHA[branch.commitSHA, default: []].append(branch)
        }

        for tag in tags {
            tagsBySHA[tag.commitSHA, default: []].append(tag)
        }
    }
}
