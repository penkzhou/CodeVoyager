import Foundation
import Testing
@testable import CodeVoyager

@Suite("Repository Tests")
struct RepositoryTests {
    @Test("Repository initializes with correct properties")
    func repositoryInitialization() {
        let url = URL(fileURLWithPath: "/tmp/test-repo")
        let repository = Repository(url: url)

        #expect(repository.name == "test-repo")
        #expect(repository.path == "/tmp/test-repo")
        #expect(repository.url == url)
    }

    @Test("Repository detects git directory")
    func gitRepositoryDetection() {
        // This test would need a real git repo to work properly
        let url = URL(fileURLWithPath: "/nonexistent")
        let repository = Repository(url: url)

        #expect(repository.isGitRepository == false)
    }
}

@Suite("Recent Repository Tests")
struct RecentRepositoryTests {
    @Test("RecentRepository initializes with default date")
    func recentRepositoryInitialization() {
        let url = URL(fileURLWithPath: "/tmp/test-repo")
        let recent = RecentRepository(url: url)

        #expect(recent.name == "test-repo")
        #expect(recent.path == "/tmp/test-repo")
    }

    @Test("RecentRepository checks existence")
    func existenceCheck() {
        let nonexistent = RecentRepository(url: URL(fileURLWithPath: "/nonexistent-path"))
        #expect(nonexistent.exists == false)

        let existing = RecentRepository(url: URL(fileURLWithPath: "/tmp"))
        #expect(existing.exists == true)
    }
}
