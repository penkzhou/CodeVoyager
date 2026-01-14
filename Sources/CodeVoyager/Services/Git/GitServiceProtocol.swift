import Foundation

/// Protocol defining Git operations.
/// Implementations may use SwiftGit3, git CLI, or a hybrid approach.
protocol GitServiceProtocol {
    // MARK: - Repository

    /// Check if the given path is a valid Git repository.
    func isGitRepository(at url: URL) async throws -> Bool

    /// Get the root directory of the repository.
    func repositoryRoot(for url: URL) async throws -> URL

    // MARK: - Branches

    /// Get all branches (local and remote).
    func branches(in repository: URL) async throws -> [Branch]

    /// Get the current branch.
    func currentBranch(in repository: URL) async throws -> Branch?

    // MARK: - Tags

    /// Get all tags.
    func tags(in repository: URL) async throws -> [Tag]

    // MARK: - Commits

    /// Get commit history with pagination.
    /// - Parameters:
    ///   - repository: Repository URL
    ///   - limit: Maximum number of commits to fetch
    ///   - offset: Number of commits to skip
    /// - Returns: Array of commits
    func commits(
        in repository: URL,
        limit: Int,
        offset: Int
    ) async throws -> [Commit]

    /// Get a specific commit by SHA.
    func commit(sha: String, in repository: URL) async throws -> Commit?

    /// Get files changed in a commit.
    func changedFiles(for commitSHA: String, in repository: URL) async throws -> [ChangedFile]

    // MARK: - Diff

    /// Get diff for a specific commit.
    /// - Parameters:
    ///   - commitSHA: The commit to diff
    ///   - parentIndex: Index of parent to compare against (0 for first parent)
    func diff(
        for commitSHA: String,
        parentIndex: Int,
        in repository: URL
    ) async throws -> [DiffResult]

    /// Get diff for a specific file in a commit.
    func fileDiff(
        for filePath: String,
        commitSHA: String,
        parentIndex: Int,
        in repository: URL
    ) async throws -> DiffResult?

    // MARK: - File Content

    /// Get file content at a specific commit.
    func fileContent(
        at path: String,
        commitSHA: String,
        in repository: URL
    ) async throws -> String

    // MARK: - Status

    /// Get working directory status.
    func status(in repository: URL) async throws -> [ChangedFile]

    // MARK: - Submodules

    /// Get submodule information.
    func submodules(in repository: URL) async throws -> [Submodule]
}

/// Represents a Git submodule.
struct Submodule: Identifiable, Hashable {
    let name: String
    let path: String
    let url: String
    let commitSHA: String

    var id: String { path }
}

/// Errors that can occur during Git operations.
enum GitError: Error, LocalizedError {
    case notARepository(URL)
    case invalidCommit(String)
    case fileNotFound(String)
    case commandFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notARepository(let url):
            return "Not a Git repository: \(url.path)"
        case .invalidCommit(let sha):
            return "Invalid commit: \(sha)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .parseError(let message):
            return "Failed to parse Git output: \(message)"
        }
    }
}
