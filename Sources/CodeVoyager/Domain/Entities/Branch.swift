import Foundation

/// Represents a Git branch.
struct Branch: Identifiable, Hashable {
    /// Branch name (e.g., "main", "feature/login")
    let name: String

    /// Whether this is the currently checked out branch
    let isHead: Bool

    /// Whether this is a remote-tracking branch
    let isRemote: Bool

    /// Remote name (e.g., "origin") for remote branches
    let remoteName: String?

    /// Upstream branch name (for local branches with tracking)
    let upstream: String?

    /// SHA of the commit this branch points to
    let commitSHA: String

    /// Short display name (without remote prefix)
    var displayName: String {
        if isRemote, let remote = remoteName {
            return name.replacingOccurrences(of: "\(remote)/", with: "")
        }
        return name
    }

    var id: String { name }
}

/// Represents a Git tag.
struct Tag: Identifiable, Hashable {
    /// Tag name
    let name: String

    /// SHA of the commit this tag points to
    let commitSHA: String

    /// Tag message (for annotated tags)
    let message: String?

    /// Whether this is an annotated tag
    var isAnnotated: Bool {
        message != nil
    }

    var id: String { name }
}
