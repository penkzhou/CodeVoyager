import SwiftUI

/// A single row displaying commit information in the history list.
///
/// Layout: `[Merge Icon] SHA [Branch Badges] [Tag Badges] Message    Author    Time`
struct CommitRowView: View {
    let commit: Commit
    let branches: [Branch]
    let tags: [CodeVoyager.Tag]
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Merge indicator
            if commit.isMerge {
                Image(systemName: "arrow.triangle.merge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Short SHA
            Text(commit.shortSHA)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            // Branch badges
            ForEach(branches, id: \.name) { branch in
                BranchBadge(branch: branch)
            }

            // Tag badges
            ForEach(tags, id: \.name) { tag in
                TagBadge(tag: tag)
            }

            // Commit message (truncated)
            Text(commit.summary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Author name
            Text(commit.authorName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Relative time
            Text(commit.date.relativeDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// Badge for displaying branch name.
struct BranchBadge: View {
    let branch: Branch

    var body: some View {
        Text(branch.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        if branch.isHead {
            return .green
        } else if branch.isRemote {
            return .orange
        } else {
            return .blue
        }
    }
}

/// Badge for displaying tag name.
struct TagBadge: View {
    let tag: CodeVoyager.Tag

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tag.fill")
                .font(.system(size: 8))
            Text(tag.name)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.yellow.opacity(0.8))
        .foregroundStyle(.black)
        .clipShape(Capsule())
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns a human-readable relative time description.
    ///
    /// Examples: "2h ago", "3d ago", "1w ago", "2mo ago"
    var relativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        } else if interval < 31536000 {
            let months = Int(interval / 2592000)
            return "\(months)mo ago"
        } else {
            let years = Int(interval / 31536000)
            return "\(years)y ago"
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        CommitRowView(
            commit: Commit(
                sha: "abc123def456789",
                message: "Fix login button not responding to clicks",
                fullMessage: "Fix login button not responding to clicks\n\nThis was caused by...",
                authorName: "John Doe",
                authorEmail: "john@example.com",
                date: Date().addingTimeInterval(-7200),
                parents: [],
                changedFiles: []
            ),
            branches: [
                Branch(name: "main", isHead: true, isRemote: false, remoteName: nil, upstream: nil, commitSHA: "abc123")
            ],
            tags: [
                CodeVoyager.Tag(name: "v1.0.0", commitSHA: "abc123", message: nil)
            ],
            isSelected: false
        )

        CommitRowView(
            commit: Commit(
                sha: "def456789abc123",
                message: "Merge branch 'feature/auth' into main",
                fullMessage: "Merge branch 'feature/auth' into main",
                authorName: "Jane Smith",
                authorEmail: "jane@example.com",
                date: Date().addingTimeInterval(-86400),
                parents: ["abc123", "xyz789"],
                changedFiles: []
            ),
            branches: [],
            tags: [],
            isSelected: true
        )
    }
    .frame(width: 600)
}
