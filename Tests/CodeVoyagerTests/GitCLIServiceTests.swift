import Foundation
import Testing
@testable import CodeVoyager

/// Integration tests for GitCLIService using the CodeVoyager repository itself.
///
/// These tests run against the actual CodeVoyager git repository to verify
/// real-world behavior. They are integration tests, not unit tests.
@Suite("GitCLIService Tests")
struct GitCLIServiceTests {
    /// Use the CodeVoyager repository itself for testing.
    /// We find the repo root by looking for Package.swift from the source file location.
    private var testRepoURL: URL {
        // Start from the source file and walk up to find Package.swift
        var url = URL(fileURLWithPath: #filePath)

        // Walk up the directory tree until we find Package.swift
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            let packageSwift = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageSwift.path) {
                return url
            }
        }

        // Fallback: try common development paths
        let fallbackPaths = [
            "/Users/penkzhou/Workspace/SwiftProject/CodeVoyager",
            FileManager.default.currentDirectoryPath
        ]

        for path in fallbackPaths {
            let url = URL(fileURLWithPath: path)
            let packageSwift = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageSwift.path) {
                return url
            }
        }

        fatalError("Could not find CodeVoyager repository root")
    }

    // MARK: - Repository Tests

    @Test("isGitRepository returns true for valid repository")
    func isGitRepositoryValid() async throws {
        let service = GitCLIService()
        let result = try await service.isGitRepository(at: testRepoURL)
        #expect(result == true)
    }

    @Test("isGitRepository returns false for non-repository")
    func isGitRepositoryInvalid() async throws {
        let service = GitCLIService()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try await service.isGitRepository(at: tempDir)
        #expect(result == false)
    }

    @Test("repositoryRoot returns correct path")
    func repositoryRoot() async throws {
        let service = GitCLIService()
        // Test from a subdirectory
        let subDir = testRepoURL.appendingPathComponent("Sources")
        let root = try await service.repositoryRoot(for: subDir)

        #expect(root.path == testRepoURL.path)
    }

    // MARK: - Commits Tests

    @Test("commits returns non-empty array with pagination")
    func commitsWithPagination() async throws {
        let service = GitCLIService()
        let commits = try await service.commits(in: testRepoURL, limit: 10, offset: 0)

        #expect(!commits.isEmpty)
        #expect(commits.count <= 10)

        // Verify commit structure
        let firstCommit = commits[0]
        #expect(!firstCommit.sha.isEmpty)
        #expect(!firstCommit.authorName.isEmpty)
        #expect(!firstCommit.message.isEmpty)
    }

    @Test("commits offset works correctly")
    func commitsOffset() async throws {
        let service = GitCLIService()

        // Get first 5 commits
        let firstBatch = try await service.commits(in: testRepoURL, limit: 5, offset: 0)
        // Get next 5 commits
        let secondBatch = try await service.commits(in: testRepoURL, limit: 5, offset: 5)

        // They should be different
        guard !firstBatch.isEmpty, !secondBatch.isEmpty else {
            Issue.record("Repository should have at least 10 commits for this test")
            return
        }

        #expect(firstBatch[0].sha != secondBatch[0].sha)
    }

    @Test("commit by SHA returns correct commit")
    func commitBySHA() async throws {
        let service = GitCLIService()

        // First get a commit SHA
        let commits = try await service.commits(in: testRepoURL, limit: 1, offset: 0)
        guard let expectedCommit = commits.first else {
            Issue.record("No commits found")
            return
        }

        // Then look it up by SHA
        let commit = try await service.commit(sha: expectedCommit.sha, in: testRepoURL)

        #expect(commit != nil)
        #expect(commit?.sha == expectedCommit.sha)
        #expect(commit?.message == expectedCommit.message)
    }

    @Test("commit by invalid SHA returns nil")
    func commitByInvalidSHA() async throws {
        let service = GitCLIService()
        let commit = try await service.commit(sha: "0000000000000000000000000000000000000000", in: testRepoURL)
        #expect(commit == nil)
    }

    // MARK: - Branches Tests

    @Test("branches returns at least main/master branch")
    func branchesIncludeMain() async throws {
        let service = GitCLIService()
        let branches = try await service.branches(in: testRepoURL)

        #expect(!branches.isEmpty)

        // Should have at least one local branch
        let localBranches = branches.filter { !$0.isRemote }
        #expect(!localBranches.isEmpty)

        // Should have exactly one HEAD branch
        let headBranches = branches.filter { $0.isHead }
        #expect(headBranches.count == 1)
    }

    @Test("currentBranch returns HEAD branch")
    func currentBranch() async throws {
        let service = GitCLIService()
        let current = try await service.currentBranch(in: testRepoURL)

        #expect(current != nil)
        #expect(current?.isHead == true)
    }

    // MARK: - Tags Tests

    @Test("tags returns array (may be empty)")
    func tagsReturnsArray() async throws {
        let service = GitCLIService()
        // Tags may or may not exist, just verify it doesn't throw
        _ = try await service.tags(in: testRepoURL)
    }

    // MARK: - Changed Files Tests

    @Test("changedFiles returns files for a commit")
    func changedFilesForCommit() async throws {
        let service = GitCLIService()

        // Get a recent commit
        let commits = try await service.commits(in: testRepoURL, limit: 20, offset: 0)
        // Find a commit that likely has changes (not a merge with no direct changes)
        let commitWithChanges = commits.first { !$0.isMerge }

        guard let commit = commitWithChanges else {
            Issue.record("Could not find a non-merge commit for testing")
            return
        }

        let files = try await service.changedFiles(for: commit.sha, in: testRepoURL)

        // A non-merge commit should have at least one changed file
        #expect(!files.isEmpty)

        // Verify file structure
        let firstFile = files[0]
        #expect(!firstFile.path.isEmpty)
    }

    // MARK: - Status Tests

    @Test("status returns array (may be empty for clean repo)")
    func statusReturnsArray() async throws {
        let service = GitCLIService()
        // Status may or may not have changes
        _ = try await service.status(in: testRepoURL)
    }
}
