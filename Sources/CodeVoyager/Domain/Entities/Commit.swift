import Foundation

/// Represents a Git commit.
struct Commit: Identifiable, Hashable {
    /// Full SHA hash
    let sha: String

    /// Shortened SHA (first 7 characters)
    var shortSHA: String {
        String(sha.prefix(7))
    }

    /// Commit message (may contain multiple lines in some cases)
    let message: String

    /// Complete commit message including subject and body
    let fullMessage: String

    /// Author name
    let authorName: String

    /// Author email
    let authorEmail: String

    /// Commit timestamp
    let date: Date

    /// Parent commit SHAs
    let parents: [String]

    /// Files changed in this commit
    let changedFiles: [ChangedFile]

    /// Branch names pointing to this commit (if any)
    var branches: [String] = []

    /// Tag names pointing to this commit (if any)
    var tags: [String] = []

    var id: String { sha }

    /// Check if this is a merge commit
    var isMerge: Bool {
        parents.count > 1
    }

    /// Summary line - extracts the first line of the commit message.
    /// Use this when displaying a single-line commit description.
    var summary: String {
        message.components(separatedBy: .newlines).first ?? message
    }
}

/// Represents a file changed in a commit.
struct ChangedFile: Identifiable, Hashable {
    /// File path relative to repository root
    let path: String

    /// Type of change
    let status: ChangeStatus

    /// Number of lines added
    let additions: Int

    /// Number of lines deleted
    let deletions: Int

    /// Old path (for renames)
    let oldPath: String?

    var id: String { path }

    /// File name without directory
    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

/// Type of change for a file.
enum ChangeStatus: String, Codable, Hashable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        }
    }

    var symbol: String {
        switch self {
        case .added: return "+"
        case .modified: return "~"
        case .deleted: return "-"
        case .renamed: return "→"
        case .copied: return "⧉"
        case .untracked: return "?"
        }
    }
}
