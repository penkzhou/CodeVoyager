import Foundation
import OSLog

/// Parses Git command output into domain entities.
///
/// This parser handles the output formats from various Git commands:
/// - `git log` with custom format using NUL separators
/// - `git branch` with structured output
/// - `git tag` with annotations
/// - `git diff-tree` for changed files
///
/// ## Design Note
/// Uses NUL (`\0`) as record separator to handle commit messages containing
/// newlines or pipe characters safely.
enum GitLogParser {
    private static let logger = Logger(subsystem: "com.codevoyager", category: "GitLogParser")

    // MARK: - Commits

    /// Git log format: `%H|%P|%an|%ae|%aI|%s|%B%x00`
    /// - H: Full SHA
    /// - P: Parent SHAs (space-separated)
    /// - an: Author name
    /// - ae: Author email
    /// - aI: ISO 8601 date
    /// - s: Subject (first line)
    /// - B: Full body
    /// - x00: NUL separator
    ///
    /// - Parameter output: Raw git log output
    /// - Returns: Array of parsed commits
    /// - Throws: `GitError.parseError` if format is invalid
    static func parseCommits(from output: String) throws -> [Commit] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        // Split by NUL character
        let records = trimmed.components(separatedBy: "\0")

        var commits: [Commit] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        for record in records {
            let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRecord.isEmpty else { continue }

            // Split by pipe with limit to preserve | in subject/body
            // SHA|parents|authorName|authorEmail|date|subject|body
            // Use split with maxSplits to preserve | in the last field (body)
            // But subject can also contain |, so we need a smarter approach
            let parts = splitWithLimit(trimmedRecord, separator: "|", limit: 7)
            guard parts.count >= 6 else {
                logger.warning("Skipping malformed commit record: insufficient fields (\(parts.count) < 6)")
                continue
            }

            let sha = parts[0]
            let parentsString = parts[1]
            let authorName = parts[2]
            let authorEmail = parts[3]
            let dateString = parts[4]
            // Parts 5 is subject, parts 6+ is body (which may contain |)
            let subject = parts.count > 5 ? parts[5] : ""
            let body = parts.count > 6 ? parts[6] : ""

            // Parse parents (space-separated)
            let parents = parentsString.isEmpty
                ? []
                : parentsString.components(separatedBy: " ").filter { !$0.isEmpty }

            // Parse date
            let date: Date
            if let parsedDate = dateFormatter.date(from: dateString) {
                date = parsedDate
            } else {
                logger.warning("Failed to parse date '\(dateString)' for commit \(sha), using current date")
                date = Date()
            }

            let commit = Commit(
                sha: sha,
                message: subject,
                fullMessage: body.isEmpty ? subject : body,
                authorName: authorName,
                authorEmail: authorEmail,
                date: date,
                parents: parents,
                changedFiles: []
            )
            commits.append(commit)
        }

        return commits
    }

    // MARK: - Branches

    /// Git branch format: `%(refname:short)|%(objectname)|%(if)%(HEAD)%(then)true%(else)false%(end)|%(upstream:remotename)|`
    ///
    /// - Parameters:
    ///   - output: Raw git branch output
    ///   - headBranch: Name of the current HEAD branch (for marking isHead)
    /// - Returns: Array of parsed branches
    static func parseBranches(from output: String, headBranch: String?) throws -> [Branch] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let lines = trimmed.components(separatedBy: .newlines)
        var branches: [Branch] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let parts = trimmedLine.components(separatedBy: "|")
            guard parts.count >= 4 else {
                logger.warning("Skipping malformed branch line: \(trimmedLine)")
                continue
            }

            let name = parts[0]
            let commitSHA = parts[1]
            let isRemote = parts[2] == "true"
            let remoteName = parts[3].isEmpty ? nil : parts[3]

            // Determine if this is the HEAD branch
            let isHead: Bool
            if isRemote {
                isHead = false
            } else {
                isHead = (headBranch == name)
            }

            let branch = Branch(
                name: name,
                isHead: isHead,
                isRemote: isRemote,
                remoteName: remoteName,
                upstream: nil,
                commitSHA: commitSHA
            )
            branches.append(branch)
        }

        return branches
    }

    // MARK: - Tags

    /// Git tag format: `%(refname:short)|%(objectname)|%(contents:subject)`
    ///
    /// - Parameter output: Raw git tag output
    /// - Returns: Array of parsed tags
    static func parseTags(from output: String) throws -> [Tag] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let lines = trimmed.components(separatedBy: .newlines)
        var tags: [Tag] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let parts = trimmedLine.components(separatedBy: "|")
            guard parts.count >= 2 else {
                logger.warning("Skipping malformed tag line: \(trimmedLine)")
                continue
            }

            let name = parts[0]
            let commitSHA = parts[1]
            let message = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil

            let tag = Tag(
                name: name,
                commitSHA: commitSHA,
                message: message
            )
            tags.append(tag)
        }

        return tags
    }

    // MARK: - Changed Files

    /// Parses changed files from `git diff-tree --name-status` and `--numstat` outputs.
    ///
    /// - Parameters:
    ///   - statusOutput: Output from `git diff-tree --name-status`
    ///   - numstatOutput: Output from `git diff-tree --numstat`
    /// - Returns: Array of changed files with stats
    static func parseChangedFiles(statusOutput: String, numstatOutput: String) throws -> [ChangedFile] {
        let statusTrimmed = statusOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !statusTrimmed.isEmpty else {
            return []
        }

        // Parse numstat for additions/deletions
        var statsMap: [String: (additions: Int, deletions: Int)] = [:]
        let numstatLines = numstatOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)

        for line in numstatLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: additions<tab>deletions<tab>path
            // For renames: additions<tab>deletions<tab>oldPath => newPath
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }

            let additions = Int(parts[0]) ?? 0  // "-" for binary files becomes 0
            let deletions = Int(parts[1]) ?? 0
            var path = parts[2]

            // Handle rename format: "old => new" or "{old => new}/path"
            if path.contains(" => ") {
                // Extract the new path
                if let arrowRange = path.range(of: " => ") {
                    path = String(path[arrowRange.upperBound...])
                }
            }

            statsMap[path] = (additions, deletions)
        }

        // Parse status output
        let statusLines = statusTrimmed.components(separatedBy: .newlines)
        var files: [ChangedFile] = []

        for line in statusLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format: status<tab>path or status<tab>oldPath<tab>newPath (for renames)
            let parts = trimmed.components(separatedBy: "\t")
            guard !parts.isEmpty else { continue }

            let statusCode = parts[0]
            let status = parseChangeStatus(statusCode)

            let path: String
            let oldPath: String?

            if status == .renamed || status == .copied {
                // Rename/copy: status\toldPath\tnewPath
                guard parts.count >= 3 else { continue }
                oldPath = parts[1]
                path = parts[2]
            } else {
                guard parts.count >= 2 else { continue }
                path = parts[1]
                oldPath = nil
            }

            let stats = statsMap[path] ?? (0, 0)

            let file = ChangedFile(
                path: path,
                status: status,
                additions: stats.additions,
                deletions: stats.deletions,
                oldPath: oldPath
            )
            files.append(file)
        }

        return files
    }

    // MARK: - Helpers

    /// Splits a string by separator with a maximum number of parts.
    /// The last part contains the remainder of the string (may include separators).
    ///
    /// Example: `splitWithLimit("a|b|c|d", separator: "|", limit: 3)` returns `["a", "b", "c|d"]`
    private static func splitWithLimit(_ string: String, separator: Character, limit: Int) -> [String] {
        guard limit > 0 else { return [] }

        var result: [String] = []
        var remaining = string[...]

        for _ in 0..<(limit - 1) {
            if let index = remaining.firstIndex(of: separator) {
                result.append(String(remaining[..<index]))
                remaining = remaining[remaining.index(after: index)...]
            } else {
                result.append(String(remaining))
                return result
            }
        }

        // Add the remainder as the last part
        result.append(String(remaining))
        return result
    }

    /// Parses Git status code to ChangeStatus enum.
    /// Status codes may have numeric suffixes (e.g., R100 for 100% rename).
    private static func parseChangeStatus(_ code: String) -> ChangeStatus {
        // Handle status codes like "R100", "C050"
        let firstChar = code.first ?? "M"

        switch firstChar {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "?": return .untracked
        default: return .modified
        }
    }
}
