import Foundation
import Testing
@testable import CodeVoyager

@Suite("GitLogParser Tests")
struct GitLogParserTests {
    // MARK: - parseCommits Tests

    @Test("parseCommits parses valid output with single commit")
    func parseCommitsSingle() throws {
        // Format: SHA|parents|authorName|authorEmail|date|subject|body
        let output = "abc1234def5678|parent123|John Doe|john@test.com|2024-01-15T10:30:00+00:00|Fix login bug|Full message here\0"
        let commits = try GitLogParser.parseCommits(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].sha == "abc1234def5678")
        #expect(commits[0].parents == ["parent123"])
        #expect(commits[0].authorName == "John Doe")
        #expect(commits[0].authorEmail == "john@test.com")
        #expect(commits[0].message == "Fix login bug")
        #expect(commits[0].fullMessage == "Full message here")
    }

    @Test("parseCommits parses multiple commits")
    func parseCommitsMultiple() throws {
        let output = """
            abc123|parent1|Alice|alice@test.com|2024-01-15T10:00:00+00:00|First commit|First body\0\
            def456|abc123|Bob|bob@test.com|2024-01-14T09:00:00+00:00|Second commit|Second body\0
            """
        let commits = try GitLogParser.parseCommits(from: output)

        #expect(commits.count == 2)
        #expect(commits[0].sha == "abc123")
        #expect(commits[1].sha == "def456")
    }

    @Test("parseCommits handles merge commit with multiple parents")
    func parseCommitsMerge() throws {
        let output = "abc123|parent1 parent2|John|john@test.com|2024-01-15T10:00:00+00:00|Merge branch|Merge body\0"
        let commits = try GitLogParser.parseCommits(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].parents == ["parent1", "parent2"])
        #expect(commits[0].isMerge == true)
    }

    @Test("parseCommits handles commit without parents (initial commit)")
    func parseCommitsNoParents() throws {
        let output = "abc123||John|john@test.com|2024-01-15T10:00:00+00:00|Initial commit|Body\0"
        let commits = try GitLogParser.parseCommits(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].parents.isEmpty)
    }

    @Test("parseCommits handles empty output")
    func parseCommitsEmpty() throws {
        let commits = try GitLogParser.parseCommits(from: "")
        #expect(commits.isEmpty)
    }

    @Test("parseCommits handles whitespace-only output")
    func parseCommitsWhitespace() throws {
        let commits = try GitLogParser.parseCommits(from: "   \n\t  ")
        #expect(commits.isEmpty)
    }

    @Test("parseCommits handles body with special characters")
    func parseCommitsSpecialChars() throws {
        // Note: Subject field should not contain |, but body can
        let output = "abc123||John|john@test.com|2024-01-15T10:00:00+00:00|Fix special chars|Body with | and : and more | chars\0"
        let commits = try GitLogParser.parseCommits(from: output)

        #expect(commits.count == 1)
        #expect(commits[0].message == "Fix special chars")
        #expect(commits[0].fullMessage.contains("|"))
        #expect(commits[0].fullMessage == "Body with | and : and more | chars")
    }

    // MARK: - parseBranches Tests

    @Test("parseBranches parses local branch")
    func parseBranchesLocal() throws {
        let output = "main|abc123|false||\n"
        let branches = try GitLogParser.parseBranches(from: output, headBranch: "main")

        #expect(branches.count == 1)
        #expect(branches[0].name == "main")
        #expect(branches[0].commitSHA == "abc123")
        #expect(branches[0].isRemote == false)
        #expect(branches[0].isHead == true)
    }

    @Test("parseBranches parses remote branch")
    func parseBranchesRemote() throws {
        let output = "origin/main|abc123|true|origin|\n"
        let branches = try GitLogParser.parseBranches(from: output, headBranch: "main")

        #expect(branches.count == 1)
        #expect(branches[0].name == "origin/main")
        #expect(branches[0].isRemote == true)
        #expect(branches[0].remoteName == "origin")
        #expect(branches[0].isHead == false)
    }

    @Test("parseBranches parses multiple branches")
    func parseBranchesMultiple() throws {
        let output = """
            main|abc123|false||
            feature/login|def456|false||
            origin/main|abc123|true|origin|
            """
        let branches = try GitLogParser.parseBranches(from: output, headBranch: "main")

        #expect(branches.count == 3)
    }

    @Test("parseBranches handles empty output")
    func parseBranchesEmpty() throws {
        let branches = try GitLogParser.parseBranches(from: "", headBranch: nil)
        #expect(branches.isEmpty)
    }

    // MARK: - parseTags Tests

    @Test("parseTags parses lightweight tag")
    func parseTagsLightweight() throws {
        let output = "v1.0.0|abc123|\n"
        let tags = try GitLogParser.parseTags(from: output)

        #expect(tags.count == 1)
        #expect(tags[0].name == "v1.0.0")
        #expect(tags[0].commitSHA == "abc123")
        #expect(tags[0].message == nil)
        #expect(tags[0].isAnnotated == false)
    }

    @Test("parseTags parses annotated tag")
    func parseTagsAnnotated() throws {
        let output = "v1.0.0|abc123|Release version 1.0.0\n"
        let tags = try GitLogParser.parseTags(from: output)

        #expect(tags.count == 1)
        #expect(tags[0].message == "Release version 1.0.0")
        #expect(tags[0].isAnnotated == true)
    }

    @Test("parseTags handles empty output")
    func parseTagsEmpty() throws {
        let tags = try GitLogParser.parseTags(from: "")
        #expect(tags.isEmpty)
    }

    // MARK: - parseChangedFiles Tests

    @Test("parseChangedFiles parses added file")
    func parseChangedFilesAdded() throws {
        let statusOutput = "A\tnewfile.swift\n"
        let numstatOutput = "50\t0\tnewfile.swift\n"
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 1)
        #expect(files[0].path == "newfile.swift")
        #expect(files[0].status == .added)
        #expect(files[0].additions == 50)
        #expect(files[0].deletions == 0)
    }

    @Test("parseChangedFiles parses modified file")
    func parseChangedFilesModified() throws {
        let statusOutput = "M\texisting.swift\n"
        let numstatOutput = "10\t5\texisting.swift\n"
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 1)
        #expect(files[0].status == .modified)
        #expect(files[0].additions == 10)
        #expect(files[0].deletions == 5)
    }

    @Test("parseChangedFiles parses deleted file")
    func parseChangedFilesDeleted() throws {
        let statusOutput = "D\toldfile.swift\n"
        let numstatOutput = "0\t30\toldfile.swift\n"
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 1)
        #expect(files[0].status == .deleted)
        #expect(files[0].additions == 0)
        #expect(files[0].deletions == 30)
    }

    @Test("parseChangedFiles parses renamed file")
    func parseChangedFilesRenamed() throws {
        let statusOutput = "R100\told.swift\tnew.swift\n"
        let numstatOutput = "0\t0\told.swift => new.swift\n"
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 1)
        #expect(files[0].path == "new.swift")
        #expect(files[0].oldPath == "old.swift")
        #expect(files[0].status == .renamed)
    }

    @Test("parseChangedFiles handles binary files")
    func parseChangedFilesBinary() throws {
        let statusOutput = "A\timage.png\n"
        let numstatOutput = "-\t-\timage.png\n"
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 1)
        #expect(files[0].additions == 0)
        #expect(files[0].deletions == 0)
    }

    @Test("parseChangedFiles handles empty output")
    func parseChangedFilesEmpty() throws {
        let files = try GitLogParser.parseChangedFiles(statusOutput: "", numstatOutput: "")
        #expect(files.isEmpty)
    }

    @Test("parseChangedFiles parses multiple files")
    func parseChangedFilesMultiple() throws {
        let statusOutput = """
            A\tnew.swift
            M\tmodified.swift
            D\tdeleted.swift
            """
        let numstatOutput = """
            50\t0\tnew.swift
            10\t5\tmodified.swift
            0\t30\tdeleted.swift
            """
        let files = try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)

        #expect(files.count == 3)
    }
}
