import Foundation
import Testing
@testable import CodeVoyager

@Suite("Branch Tests")
struct BranchTests {
    @Test("Branch displayName removes remote prefix")
    func displayNameRemovesRemotePrefix() {
        let remoteBranch = Branch(
            name: "origin/feature/login",
            isHead: false,
            isRemote: true,
            remoteName: "origin",
            upstream: nil,
            commitSHA: "abc123"
        )
        #expect(remoteBranch.displayName == "feature/login")
    }

    @Test("Branch displayName keeps local branch name unchanged")
    func displayNameLocalBranch() {
        let localBranch = Branch(
            name: "feature/login",
            isHead: true,
            isRemote: false,
            remoteName: nil,
            upstream: "origin/feature/login",
            commitSHA: "abc123"
        )
        #expect(localBranch.displayName == "feature/login")
    }

    @Test("Branch id equals name")
    func idEqualsName() {
        let branch = Branch(
            name: "main",
            isHead: true,
            isRemote: false,
            remoteName: nil,
            upstream: nil,
            commitSHA: "abc123"
        )
        #expect(branch.id == "main")
    }
}

@Suite("Tag Tests")
struct TagTests {
    @Test("Tag identifies annotated tags correctly")
    func isAnnotated() {
        let annotatedTag = Tag(
            name: "v1.0.0",
            commitSHA: "abc123",
            message: "Release version 1.0.0"
        )
        #expect(annotatedTag.isAnnotated == true)

        let lightweightTag = Tag(
            name: "v1.0.1",
            commitSHA: "def456",
            message: nil
        )
        #expect(lightweightTag.isAnnotated == false)
    }

    @Test("Tag id equals name")
    func idEqualsName() {
        let tag = Tag(name: "v2.0.0", commitSHA: "abc", message: nil)
        #expect(tag.id == "v2.0.0")
    }
}
