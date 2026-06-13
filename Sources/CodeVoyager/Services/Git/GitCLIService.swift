import Foundation
import OSLog

/// Git service implementation using the git CLI.
///
/// Uses the system's git executable for all operations, parsing the output
/// with `GitLogParser`. This approach provides access to all git features
/// and handles complex scenarios better than library-based implementations.
///
/// ## Thread Safety
/// All methods are async and safe to call from any actor context.
/// Internal shell execution is isolated.
///
/// ## Usage
/// ```swift
/// let service = GitCLIService()
/// let commits = try await service.commits(in: repoURL, limit: 100, offset: 0)
/// ```
actor GitCLIService: GitServiceProtocol {
    private let logger = Logger(subsystem: "com.codevoyager", category: "GitCLIService")

    /// Git executable path. Uses system git by default.
    private let gitPath: String

    /// Initialize with custom git path (useful for testing).
    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    // MARK: - Repository

    func isGitRepository(at url: URL) async throws -> Bool {
        do {
            let output = try await runGit(["rev-parse", "--is-inside-work-tree"], in: url)
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            // git rev-parse returns error for non-repositories
            return false
        }
    }

    func repositoryRoot(for url: URL) async throws -> URL {
        let output = try await runGit(["rev-parse", "--show-toplevel"], in: url)
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            throw GitError.notARepository(url)
        }

        return URL(fileURLWithPath: path)
    }

    // MARK: - Branches

    func branches(in repository: URL) async throws -> [Branch] {
        // Get current branch name
        let headBranch = try await currentBranchName(in: repository)

        // Get all branches with format: name|sha|isRemote|remoteName|
        // Using -a to include remote branches
        let format = "%(refname:short)|%(objectname:short)|%(if)%(symref)%(then)true%(else)%(if:equals=refs/remotes)%(refname:rstrip=-2)%(then)true%(else)false%(end)%(end)|%(if:equals=refs/remotes)%(refname:rstrip=-2)%(then)%(upstream:remotename)%(end)|"

        // Actually, let's use a simpler approach: separate calls for local and remote
        async let localBranchesTask = fetchLocalBranches(in: repository, headBranch: headBranch)
        async let remoteBranchesTask = fetchRemoteBranches(in: repository)

        let localBranches = try await localBranchesTask
        let remoteBranches = try await remoteBranchesTask

        return localBranches + remoteBranches
    }

    private func fetchLocalBranches(in repository: URL, headBranch: String?) async throws -> [Branch] {
        let format = "%(refname:short)|%(objectname:short)|false||"
        let output = try await runGit(["branch", "--format=\(format)"], in: repository)
        return try GitLogParser.parseBranches(from: output, headBranch: headBranch)
    }

    private func fetchRemoteBranches(in repository: URL) async throws -> [Branch] {
        let format = "%(refname:short)|%(objectname:short)|true|%(upstream:remotename)|"
        do {
            let output = try await runGit(["branch", "-r", "--format=\(format)"], in: repository)
            return try GitLogParser.parseBranches(from: output, headBranch: nil)
        } catch {
            // Repository may not have remotes
            logger.debug("No remote branches found: \(error.localizedDescription)")
            return []
        }
    }

    func currentBranch(in repository: URL) async throws -> Branch? {
        guard let branchName = try await currentBranchName(in: repository) else {
            return nil  // Detached HEAD
        }

        let sha = try await runGit(["rev-parse", "--short", "HEAD"], in: repository)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Branch(
            name: branchName,
            isHead: true,
            isRemote: false,
            remoteName: nil,
            upstream: nil,
            commitSHA: sha
        )
    }

    private func currentBranchName(in repository: URL) async throws -> String? {
        do {
            let output = try await runGit(["symbolic-ref", "--short", "HEAD"], in: repository)
            let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        } catch {
            // Detached HEAD state
            return nil
        }
    }

    // MARK: - Tags

    func tags(in repository: URL) async throws -> [Tag] {
        let format = "%(refname:short)|%(objectname:short)|%(contents:subject)"
        let output = try await runGit(["tag", "-l", "--format=\(format)"], in: repository)
        return try GitLogParser.parseTags(from: output)
    }

    // MARK: - Commits

    /// Git log format for parsing.
    /// Fields: SHA|parents|authorName|authorEmail|date|subject|body
    /// Separated by NUL character.
    private static let logFormat = "%H|%P|%an|%ae|%aI|%s|%B%x00"

    func commits(in repository: URL, limit: Int, offset: Int) async throws -> [Commit] {
        var args = [
            "log",
            "--format=\(Self.logFormat)",
            "-n", String(limit)
        ]

        if offset > 0 {
            args.append(contentsOf: ["--skip", String(offset)])
        }

        let output = try await runGit(args, in: repository)
        return try GitLogParser.parseCommits(from: output)
    }

    func commits(forFile filePath: String, in repository: URL, limit: Int, offset: Int) async throws -> [Commit] {
        var args = [
            "log",
            "--format=\(Self.logFormat)",
            "--follow",  // Track file across renames
            "-n", String(limit)
        ]

        if offset > 0 {
            args.append(contentsOf: ["--skip", String(offset)])
        }

        // Add separator and file path (must come after --)
        args.append("--")
        args.append(filePath)

        let output = try await runGit(args, in: repository)
        return try GitLogParser.parseCommits(from: output)
    }

    func commit(sha: String, in repository: URL) async throws -> Commit? {
        let args = [
            "log",
            "--format=\(Self.logFormat)",
            "-n", "1",
            sha
        ]

        do {
            let output = try await runGit(args, in: repository)
            let commits = try GitLogParser.parseCommits(from: output)
            return commits.first
        } catch {
            // Invalid SHA or commit not found
            logger.debug("Commit not found for SHA \(sha): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Changed Files

    func changedFiles(for commitSHA: String, in repository: URL) async throws -> [ChangedFile] {
        // Get status (A/M/D/R) with old and new paths
        let statusArgs = [
            "diff-tree",
            "--no-commit-id",
            "--name-status",
            "-r",
            "-M",  // Detect renames
            commitSHA
        ]

        // Get numstat (additions/deletions)
        let numstatArgs = [
            "diff-tree",
            "--no-commit-id",
            "--numstat",
            "-r",
            "-M",
            commitSHA
        ]

        async let statusTask = runGit(statusArgs, in: repository)
        async let numstatTask = runGit(numstatArgs, in: repository)

        let statusOutput = try await statusTask
        let numstatOutput = try await numstatTask

        return try GitLogParser.parseChangedFiles(statusOutput: statusOutput, numstatOutput: numstatOutput)
    }

    // MARK: - Diff

    func diff(for commitSHA: String, parentIndex: Int, in repository: URL) async throws -> [DiffResult] {
        // Get the parent SHA
        let parentsOutput = try await runGit(["rev-parse", "\(commitSHA)^@"], in: repository)
        let parents = parentsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        let parentSHA: String
        if parents.isEmpty {
            // Initial commit - diff against empty tree
            parentSHA = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"  // Empty tree SHA
        } else if parentIndex < parents.count {
            parentSHA = parents[parentIndex]
        } else {
            parentSHA = parents[0]
        }

        let output = try await runGit([
            "diff",
            parentSHA,
            commitSHA,
            "--unified=3"
        ], in: repository)

        return parseDiffOutput(output)
    }

    func fileDiff(for filePath: String, commitSHA: String, parentIndex: Int, in repository: URL) async throws -> DiffResult? {
        let results = try await diff(for: commitSHA, parentIndex: parentIndex, in: repository)
        return results.first { $0.filePath == filePath || $0.oldPath == filePath }
    }

    private func parseDiffOutput(_ output: String) -> [DiffResult] {
        // Simple diff parser - can be enhanced later
        var results: [DiffResult] = []
        var currentFile: (oldPath: String?, newPath: String?, hunks: [DiffHunk])?

        let lines = output.components(separatedBy: .newlines)
        var hunkLines: [DiffLine] = []
        var currentHunk: (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)?

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Save previous file
                if let file = currentFile {
                    if let hunk = currentHunk, !hunkLines.isEmpty {
                        currentFile?.hunks.append(DiffHunk(
                            oldStart: hunk.oldStart,
                            oldCount: hunk.oldCount,
                            newStart: hunk.newStart,
                            newCount: hunk.newCount,
                            lines: hunkLines
                        ))
                    }
                    if let newPath = file.newPath {
                        let oldPath = file.oldPath != file.newPath ? file.oldPath : nil
                        results.append(DiffResult(
                            filePath: newPath,
                            oldPath: oldPath,
                            hunks: currentFile?.hunks ?? []
                        ))
                    }
                }
                currentFile = (nil, nil, [])
                currentHunk = nil
                hunkLines = []
            } else if line.hasPrefix("--- a/") {
                currentFile?.oldPath = String(line.dropFirst(6))
            } else if line.hasPrefix("+++ b/") {
                currentFile?.newPath = String(line.dropFirst(6))
            } else if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk, !hunkLines.isEmpty {
                    currentFile?.hunks.append(DiffHunk(
                        oldStart: hunk.oldStart,
                        oldCount: hunk.oldCount,
                        newStart: hunk.newStart,
                        newCount: hunk.newCount,
                        lines: hunkLines
                    ))
                }
                hunkLines = []

                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
                if let match = parseHunkHeader(line) {
                    currentHunk = match
                }
            } else if currentHunk != nil {
                if line.hasPrefix("+") && !line.hasPrefix("+++") {
                    hunkLines.append(DiffLine(content: String(line.dropFirst()), type: .addition))
                } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                    hunkLines.append(DiffLine(content: String(line.dropFirst()), type: .deletion))
                } else if line.hasPrefix(" ") || line.isEmpty {
                    let content = line.isEmpty ? "" : String(line.dropFirst())
                    hunkLines.append(DiffLine(content: content, type: .context))
                }
            }
        }

        // Save last file
        if let file = currentFile {
            if let hunk = currentHunk, !hunkLines.isEmpty {
                currentFile?.hunks.append(DiffHunk(
                    oldStart: hunk.oldStart,
                    oldCount: hunk.oldCount,
                    newStart: hunk.newStart,
                    newCount: hunk.newCount,
                    lines: hunkLines
                ))
            }
            if let newPath = file.newPath {
                let oldPath = file.oldPath != file.newPath ? file.oldPath : nil
                results.append(DiffResult(
                    filePath: newPath,
                    oldPath: oldPath,
                    hunks: currentFile?.hunks ?? []
                ))
            }
        }

        return results
    }

    private func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)? {
        // @@ -1,5 +1,7 @@ or @@ -1 +1 @@
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func extract(_ index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: line) else { return 1 }
            return Int(line[range]) ?? 1
        }

        return (
            oldStart: extract(1),
            oldCount: match.range(at: 2).location != NSNotFound ? extract(2) : 1,
            newStart: extract(3),
            newCount: match.range(at: 4).location != NSNotFound ? extract(4) : 1
        )
    }

    // MARK: - File Content

    func fileContent(at path: String, commitSHA: String, in repository: URL) async throws -> String {
        let output = try await runGit(["show", "\(commitSHA):\(path)"], in: repository)
        return output
    }

    // MARK: - Status

    func status(in repository: URL) async throws -> [ChangedFile] {
        let output = try await runGit([
            "status",
            "--porcelain=v1",
            "-uall"
        ], in: repository)

        return parseStatusOutput(output)
    }

    private func parseStatusOutput(_ output: String) -> [ChangedFile] {
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        return lines.compactMap { line -> ChangedFile? in
            guard line.count > 3 else { return nil }

            let statusChar = line[line.index(line.startIndex, offsetBy: 1)]
            let path = String(line.dropFirst(3))

            let status: ChangeStatus
            switch statusChar {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R": status = .renamed
            case "?": status = .untracked
            default: status = .modified
            }

            return ChangedFile(
                path: path,
                status: status,
                additions: 0,
                deletions: 0,
                oldPath: nil
            )
        }
    }

    // MARK: - Submodules

    func submodules(in repository: URL) async throws -> [Submodule] {
        do {
            let output = try await runGit([
                "submodule",
                "status",
                "--recursive"
            ], in: repository)

            return parseSubmoduleOutput(output)
        } catch {
            // No submodules or error
            return []
        }
    }

    private func parseSubmoduleOutput(_ output: String) -> [Submodule] {
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        return lines.compactMap { line -> Submodule? in
            // Format: [+-U ]SHA path (branch)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard parts.count >= 2 else { return nil }

            var sha = parts[0]
            // Remove status prefix if present
            if sha.hasPrefix("+") || sha.hasPrefix("-") || sha.hasPrefix("U") {
                sha = String(sha.dropFirst())
            }

            let path = parts[1]

            return Submodule(
                name: (path as NSString).lastPathComponent,
                path: path,
                url: "",  // Would need to parse .gitmodules for URL
                commitSHA: sha
            )
        }
    }

    // MARK: - Shell Execution

    /// Runs a git command and returns the output.
    ///
    /// - Parameters:
    ///   - arguments: Git command arguments (without "git" prefix)
    ///   - directory: Working directory for the command
    /// - Returns: Standard output as string
    /// - Throws: `GitError.commandFailed` if the command fails
    private func runGit(_ arguments: [String], in directory: URL) async throws -> String {
        let gitPath = self.gitPath
        let logFile = URL(fileURLWithPath: "/tmp/codevoyager_debug.log")

        func log(_ msg: String) {
            let line = "[GIT] \(msg)\n"
            if let data = line.data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }

        log("runGit called: \(arguments.joined(separator: " ")) in \(directory.path)")

        return try await withCheckedThrowingContinuation { continuation in
            // Run Process on a background queue to avoid blocking the actor
            DispatchQueue.global(qos: .userInitiated).async {
                log("DispatchQueue started")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: gitPath)
                process.arguments = arguments
                process.currentDirectoryURL = directory

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    log("Starting process...")
                    try process.run()
                    log("Process running, waiting...")
                    process.waitUntilExit()
                    log("Process exited with status: \(process.terminationStatus)")

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""

                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: GitError.commandFailed(
                            "git \(arguments.joined(separator: " ")): \(errorOutput)"
                        ))
                    } else {
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: GitError.commandFailed(error.localizedDescription))
                }
            }
        }
    }
}
