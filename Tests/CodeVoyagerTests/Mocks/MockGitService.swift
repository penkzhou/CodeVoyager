import Foundation
@testable import CodeVoyager

/// Mock implementation of GitServiceProtocol for testing.
///
/// Allows stubbing return values and tracking method calls.
actor MockGitService: GitServiceProtocol {
    // MARK: - Stubbed Return Values

    var stubbedIsGitRepository: Bool = true
    var stubbedRepositoryRoot: URL = URL(fileURLWithPath: "/test/repo")
    var stubbedBranches: [Branch] = []
    var stubbedCurrentBranch: Branch?
    var stubbedTags: [CodeVoyager.Tag] = []
    var stubbedCommits: [Commit] = []
    var stubbedCommit: Commit?
    var stubbedChangedFiles: [ChangedFile] = []
    var stubbedDiff: [DiffResult] = []
    var stubbedFileDiff: DiffResult?
    var stubbedFileContent: String = ""
    var stubbedStatus: [ChangedFile] = []
    var stubbedSubmodules: [Submodule] = []

    // MARK: - Error Simulation

    var errorToThrow: Error?

    // MARK: - Call Tracking

    private(set) var isGitRepositoryCallCount = 0
    private(set) var commitsCallCount = 0
    private(set) var lastCommitsLimit: Int?
    private(set) var lastCommitsOffset: Int?
    private(set) var changedFilesCallCount = 0
    private(set) var lastChangedFilesSHA: String?
    private(set) var commitsForFileCallCount = 0
    private(set) var lastCommitsForFilePath: String?

    /// Stubbed commits for specific files (keyed by file path).
    /// If nil or empty for a file, falls back to stubbedCommits filtered by the file.
    var stubbedCommitsForFile: [String: [Commit]] = [:]

    // MARK: - GitServiceProtocol Implementation

    func isGitRepository(at url: URL) async throws -> Bool {
        isGitRepositoryCallCount += 1
        if let error = errorToThrow { throw error }
        return stubbedIsGitRepository
    }

    func repositoryRoot(for url: URL) async throws -> URL {
        if let error = errorToThrow { throw error }
        return stubbedRepositoryRoot
    }

    func branches(in repository: URL) async throws -> [Branch] {
        if let error = errorToThrow { throw error }
        return stubbedBranches
    }

    func currentBranch(in repository: URL) async throws -> Branch? {
        if let error = errorToThrow { throw error }
        return stubbedCurrentBranch
    }

    func tags(in repository: URL) async throws -> [CodeVoyager.Tag] {
        if let error = errorToThrow { throw error }
        return stubbedTags
    }

    func commits(in repository: URL, limit: Int, offset: Int) async throws -> [Commit] {
        commitsCallCount += 1
        lastCommitsLimit = limit
        lastCommitsOffset = offset
        if let error = errorToThrow { throw error }

        // Simulate pagination
        let start = offset
        let end = min(start + limit, stubbedCommits.count)
        guard start < stubbedCommits.count else { return [] }
        return Array(stubbedCommits[start..<end])
    }

    func commits(forFile filePath: String, in repository: URL, limit: Int, offset: Int) async throws -> [Commit] {
        commitsForFileCallCount += 1
        lastCommitsForFilePath = filePath
        lastCommitsLimit = limit
        lastCommitsOffset = offset
        if let error = errorToThrow { throw error }

        // Use file-specific commits if available, otherwise filter stubbedCommits
        let fileCommits = stubbedCommitsForFile[filePath] ?? stubbedCommits

        // Simulate pagination
        let start = offset
        let end = min(start + limit, fileCommits.count)
        guard start < fileCommits.count else { return [] }
        return Array(fileCommits[start..<end])
    }

    func commit(sha: String, in repository: URL) async throws -> Commit? {
        if let error = errorToThrow { throw error }
        return stubbedCommit ?? stubbedCommits.first { $0.sha == sha }
    }

    func changedFiles(for commitSHA: String, in repository: URL) async throws -> [ChangedFile] {
        changedFilesCallCount += 1
        lastChangedFilesSHA = commitSHA
        if let error = errorToThrow { throw error }
        return stubbedChangedFiles
    }

    func diff(for commitSHA: String, parentIndex: Int, in repository: URL) async throws -> [DiffResult] {
        if let error = errorToThrow { throw error }
        return stubbedDiff
    }

    func fileDiff(for filePath: String, commitSHA: String, parentIndex: Int, in repository: URL) async throws -> DiffResult? {
        if let error = errorToThrow { throw error }
        return stubbedFileDiff
    }

    func fileContent(at path: String, commitSHA: String, in repository: URL) async throws -> String {
        if let error = errorToThrow { throw error }
        return stubbedFileContent
    }

    func status(in repository: URL) async throws -> [ChangedFile] {
        if let error = errorToThrow { throw error }
        return stubbedStatus
    }

    func submodules(in repository: URL) async throws -> [Submodule] {
        if let error = errorToThrow { throw error }
        return stubbedSubmodules
    }

    // MARK: - Test Helpers

    /// Resets all call tracking and stubbed values.
    func reset() {
        stubbedIsGitRepository = true
        stubbedRepositoryRoot = URL(fileURLWithPath: "/test/repo")
        stubbedBranches = []
        stubbedCurrentBranch = nil
        stubbedTags = []
        stubbedCommits = []
        stubbedCommit = nil
        stubbedChangedFiles = []
        stubbedDiff = []
        stubbedFileDiff = nil
        stubbedFileContent = ""
        stubbedStatus = []
        stubbedSubmodules = []
        errorToThrow = nil

        isGitRepositoryCallCount = 0
        commitsCallCount = 0
        lastCommitsLimit = nil
        lastCommitsOffset = nil
        changedFilesCallCount = 0
        lastChangedFilesSHA = nil
        commitsForFileCallCount = 0
        lastCommitsForFilePath = nil
        stubbedCommitsForFile = [:]
    }
}

// MARK: - Test Data Helpers

extension MockGitService {
    /// Creates a test commit with default values.
    static func makeTestCommit(
        sha: String = "abc123def456",
        message: String = "Test commit message",
        authorName: String = "Test Author",
        authorEmail: String = "test@example.com",
        date: Date = Date(),
        parents: [String] = [],
        branches: [String] = [],
        tags: [String] = []
    ) -> Commit {
        var commit = Commit(
            sha: sha,
            message: message,
            fullMessage: message,
            authorName: authorName,
            authorEmail: authorEmail,
            date: date,
            parents: parents,
            changedFiles: []
        )
        commit.branches = branches
        commit.tags = tags
        return commit
    }

    /// Creates a test branch with default values.
    static func makeTestBranch(
        name: String = "main",
        isHead: Bool = false,
        isRemote: Bool = false,
        commitSHA: String = "abc123"
    ) -> Branch {
        Branch(
            name: name,
            isHead: isHead,
            isRemote: isRemote,
            remoteName: isRemote ? "origin" : nil,
            upstream: nil,
            commitSHA: commitSHA
        )
    }

    /// Creates a test tag with default values.
    static func makeTestTag(
        name: String = "v1.0.0",
        commitSHA: String = "abc123",
        message: String? = nil
    ) -> CodeVoyager.Tag {
        CodeVoyager.Tag(name: name, commitSHA: commitSHA, message: message)
    }

    /// Creates a test changed file with default values.
    static func makeTestChangedFile(
        path: String = "test.swift",
        status: ChangeStatus = .modified,
        additions: Int = 10,
        deletions: Int = 5
    ) -> ChangedFile {
        ChangedFile(
            path: path,
            status: status,
            additions: additions,
            deletions: deletions,
            oldPath: nil
        )
    }
}
