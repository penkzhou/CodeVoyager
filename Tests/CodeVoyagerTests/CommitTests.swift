import Foundation
import Testing
@testable import CodeVoyager

@Suite("Commit Tests")
struct CommitTests {
    @Test("Commit shortSHA returns first 7 characters")
    func shortSHA() {
        let commit = makeCommit(sha: "abc123def456789")
        #expect(commit.shortSHA == "abc123d")
    }

    @Test("Commit shortSHA handles empty string")
    func shortSHAEmpty() {
        let commit = makeCommit(sha: "")
        #expect(commit.shortSHA == "")
    }

    @Test("Commit shortSHA handles string shorter than 7 characters")
    func shortSHAShorterThan7() {
        let commit = makeCommit(sha: "abc")
        #expect(commit.shortSHA == "abc")
    }

    @Test("Commit shortSHA handles exactly 7 characters")
    func shortSHAExactly7() {
        let commit = makeCommit(sha: "abc1234")
        #expect(commit.shortSHA == "abc1234")
    }

    @Test("Commit summary returns first line of message")
    func summary() {
        let commit = makeCommit(message: "First line\nSecond line\nThird line")
        #expect(commit.summary == "First line")
    }

    @Test("Commit summary handles single line message")
    func summarySingleLine() {
        let commit = makeCommit(message: "Only one line")
        #expect(commit.summary == "Only one line")
    }

    @Test("Commit identifies merge commits correctly")
    func isMerge() {
        let regularCommit = makeCommit(parents: ["parent1"])
        #expect(regularCommit.isMerge == false)

        let mergeCommit = makeCommit(parents: ["parent1", "parent2"])
        #expect(mergeCommit.isMerge == true)
    }

    @Test("Commit id equals sha")
    func idEqualsSha() {
        let sha = "abc123def456"
        let commit = makeCommit(sha: sha)
        #expect(commit.id == sha)
    }

    // MARK: - Helper

    private func makeCommit(
        sha: String = "abc123",
        message: String = "Test commit",
        parents: [String] = []
    ) -> Commit {
        Commit(
            sha: sha,
            message: message,
            fullMessage: message,
            authorName: "Test Author",
            authorEmail: "test@example.com",
            date: Date(),
            parents: parents,
            changedFiles: []
        )
    }
}

@Suite("ChangedFile Tests")
struct ChangedFileTests {
    @Test("ChangedFile extracts fileName from path")
    func fileName() {
        let file = ChangedFile(
            path: "src/components/Button.swift",
            status: .modified,
            additions: 10,
            deletions: 5,
            oldPath: nil
        )
        #expect(file.fileName == "Button.swift")
    }

    @Test("ChangedFile handles root level files")
    func rootLevelFile() {
        let file = ChangedFile(
            path: "README.md",
            status: .added,
            additions: 50,
            deletions: 0,
            oldPath: nil
        )
        #expect(file.fileName == "README.md")
    }
}

@Suite("ChangeStatus Tests")
struct ChangeStatusTests {
    @Test("ChangeStatus has correct display names")
    func displayNames() {
        #expect(ChangeStatus.added.displayName == "Added")
        #expect(ChangeStatus.modified.displayName == "Modified")
        #expect(ChangeStatus.deleted.displayName == "Deleted")
        #expect(ChangeStatus.renamed.displayName == "Renamed")
        #expect(ChangeStatus.copied.displayName == "Copied")
        #expect(ChangeStatus.untracked.displayName == "Untracked")
    }

    @Test("ChangeStatus has correct symbols")
    func symbols() {
        #expect(ChangeStatus.added.symbol == "+")
        #expect(ChangeStatus.modified.symbol == "~")
        #expect(ChangeStatus.deleted.symbol == "-")
        #expect(ChangeStatus.renamed.symbol == "→")
        #expect(ChangeStatus.copied.symbol == "⧉")
        #expect(ChangeStatus.untracked.symbol == "?")
    }
    
    @Test("ChangeStatus raw values match Git status codes")
    func rawValues() {
        #expect(ChangeStatus.added.rawValue == "A")
        #expect(ChangeStatus.modified.rawValue == "M")
        #expect(ChangeStatus.deleted.rawValue == "D")
        #expect(ChangeStatus.renamed.rawValue == "R")
        #expect(ChangeStatus.copied.rawValue == "C")
        #expect(ChangeStatus.untracked.rawValue == "?")
    }
}
