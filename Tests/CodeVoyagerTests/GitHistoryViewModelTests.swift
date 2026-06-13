import Foundation
import Testing
@testable import CodeVoyager

@Suite("GitHistoryViewModel Tests")
@MainActor
struct GitHistoryViewModelTests {

    // MARK: - Initial Load Tests

    @Test("loadInitialData loads commits, branches, and tags")
    func loadInitialDataLoadsAll() async throws {
        let mockService = MockGitService()
        await mockService.setStubbedCommits([
            MockGitService.makeTestCommit(sha: "abc123", message: "First commit"),
            MockGitService.makeTestCommit(sha: "def456", message: "Second commit")
        ])
        await mockService.setStubbedBranches([
            MockGitService.makeTestBranch(name: "main", isHead: true, commitSHA: "abc123")
        ])
        await mockService.setStubbedTags([
            MockGitService.makeTestTag(name: "v1.0", commitSHA: "abc123")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()

        #expect(viewModel.commits.count == 2)
        #expect(viewModel.branches.count == 1)
        #expect(viewModel.tags.count == 1)
        #expect(viewModel.loadingState == .loaded)
    }

    @Test("loadInitialData sets error state on failure")
    func loadInitialDataError() async throws {
        let mockService = MockGitService()
        await mockService.setErrorToThrow(GitError.commandFailed("Test error"))

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()

        if case .error(let message) = viewModel.loadingState {
            #expect(message.contains("Test error"))
        } else {
            Issue.record("Expected error state, got \(viewModel.loadingState)")
        }
    }

    @Test("loadInitialData builds branch and tag SHA indexes")
    func loadInitialDataBuildsIndexes() async throws {
        let mockService = MockGitService()
        await mockService.setStubbedCommits([
            MockGitService.makeTestCommit(sha: "abc123")
        ])
        await mockService.setStubbedBranches([
            MockGitService.makeTestBranch(name: "main", commitSHA: "abc123"),
            MockGitService.makeTestBranch(name: "feature", commitSHA: "abc123")
        ])
        await mockService.setStubbedTags([
            MockGitService.makeTestTag(name: "v1.0", commitSHA: "abc123")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()

        #expect(viewModel.branchesBySHA["abc123"]?.count == 2)
        #expect(viewModel.tagsBySHA["abc123"]?.count == 1)
    }

    // MARK: - Pagination Tests

    @Test("loadMoreCommits appends to existing commits")
    func loadMoreCommitsAppends() async throws {
        let mockService = MockGitService()
        // Create 600 commits to test pagination
        var commits: [Commit] = []
        for i in 0..<600 {
            commits.append(MockGitService.makeTestCommit(
                sha: String(format: "sha%03d", i),
                message: "Commit \(i)"
            ))
        }
        await mockService.setStubbedCommits(commits)

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        // Load initial data (500 commits by default)
        await viewModel.loadInitialData()
        let initialCount = viewModel.commits.count
        #expect(initialCount == 500)

        // Load more
        await viewModel.loadMoreCommits()
        #expect(viewModel.commits.count == 600)
        #expect(viewModel.hasMoreCommits == false)
    }

    @Test("loadMoreCommits does nothing when no more commits")
    func loadMoreCommitsNoMore() async throws {
        let mockService = MockGitService()
        await mockService.setStubbedCommits([
            MockGitService.makeTestCommit(sha: "abc123")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()
        #expect(viewModel.hasMoreCommits == false)

        // Try to load more - should not call service again
        let callCountBefore = await mockService.commitsCallCount
        await viewModel.loadMoreCommits()
        let callCountAfter = await mockService.commitsCallCount

        #expect(callCountBefore == callCountAfter)
    }

    // MARK: - Selection Tests

    @Test("selectCommit loads changed files")
    func selectCommitLoadsFiles() async throws {
        let mockService = MockGitService()
        let commit = MockGitService.makeTestCommit(sha: "abc123")
        await mockService.setStubbedCommits([commit])
        await mockService.setStubbedChangedFiles([
            MockGitService.makeTestChangedFile(path: "file1.swift"),
            MockGitService.makeTestChangedFile(path: "file2.swift")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()
        await viewModel.selectCommit(commit)

        #expect(viewModel.selectedCommit?.sha == "abc123")
        #expect(viewModel.selectedCommitFiles.count == 2)
    }

    @Test("selectCommit with nil clears selection")
    func selectCommitNilClears() async throws {
        let mockService = MockGitService()
        let commit = MockGitService.makeTestCommit(sha: "abc123")
        await mockService.setStubbedCommits([commit])
        await mockService.setStubbedChangedFiles([
            MockGitService.makeTestChangedFile(path: "file1.swift")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()
        await viewModel.selectCommit(commit)
        #expect(viewModel.selectedCommit != nil)

        await viewModel.selectCommit(nil)
        #expect(viewModel.selectedCommit == nil)
        #expect(viewModel.selectedCommitFiles.isEmpty)
    }

    // MARK: - Refresh Tests

    @Test("refresh reloads all data")
    func refreshReloadsData() async throws {
        let mockService = MockGitService()
        await mockService.setStubbedCommits([
            MockGitService.makeTestCommit(sha: "abc123")
        ])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        await viewModel.loadInitialData()
        let callCountAfterInitial = await mockService.commitsCallCount

        // Update stubbed data
        await mockService.setStubbedCommits([
            MockGitService.makeTestCommit(sha: "abc123"),
            MockGitService.makeTestCommit(sha: "def456")
        ])

        await viewModel.refresh()
        let callCountAfterRefresh = await mockService.commitsCallCount

        #expect(callCountAfterRefresh > callCountAfterInitial)
        #expect(viewModel.commits.count == 2)
    }

    // MARK: - Loading State Tests

    @Test("loadingState transitions correctly")
    func loadingStateTransitions() async throws {
        let mockService = MockGitService()
        await mockService.setStubbedCommits([MockGitService.makeTestCommit()])

        let repository = Repository(url: URL(fileURLWithPath: "/test/repo"))
        let viewModel = GitHistoryViewModel(repository: repository, gitService: mockService)

        #expect(viewModel.loadingState == .idle)

        await viewModel.loadInitialData()

        #expect(viewModel.loadingState == .loaded)
    }
}

// MARK: - MockGitService Helper Extensions

extension MockGitService {
    func setStubbedCommits(_ commits: [Commit]) async {
        stubbedCommits = commits
    }

    func setStubbedBranches(_ branches: [Branch]) async {
        stubbedBranches = branches
    }

    func setStubbedTags(_ tags: [CodeVoyager.Tag]) async {
        stubbedTags = tags
    }

    func setStubbedChangedFiles(_ files: [ChangedFile]) async {
        stubbedChangedFiles = files
    }

    func setErrorToThrow(_ error: Error?) async {
        errorToThrow = error
    }
}
