import SwiftUI

/// Detail panel showing commit information and changed files.
struct CommitDetailView: View {
    let commit: Commit
    let changedFiles: [ChangedFile]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                commitHeader

                Divider()

                // Full message
                if !commit.fullMessage.isEmpty {
                    messageSection
                }

                Divider()

                // Changed files
                changedFilesSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var commitHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // SHA
            HStack {
                Text("Commit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(commit.sha)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)

                Button {
                    copyToClipboard(commit.sha)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy SHA")
            }

            // Author
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(commit.authorName)
                    .fontWeight(.medium)
                Text("<\(commit.authorEmail)>")
                    .foregroundStyle(.secondary)
            }

            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(commit.date.formatted(date: .long, time: .shortened))
            }

            // Parents
            if !commit.parents.isEmpty {
                HStack {
                    Image(systemName: commit.isMerge ? "arrow.triangle.merge" : "arrow.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(commit.isMerge ? "Parents:" : "Parent:")
                        .foregroundStyle(.secondary)
                    ForEach(commit.parents, id: \.self) { parent in
                        Text(String(parent.prefix(7)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Message")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(commit.fullMessage)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private var changedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with count
            HStack {
                Text("Changed Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("(\(changedFiles.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                // Summary stats
                Text("+\(totalAdditions)")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("-\(totalDeletions)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // File list
            if changedFiles.isEmpty {
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(changedFiles) { file in
                        ChangedFileRow(file: file)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var totalAdditions: Int {
        changedFiles.reduce(0) { $0 + $1.additions }
    }

    private var totalDeletions: Int {
        changedFiles.reduce(0) { $0 + $1.deletions }
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Row displaying a changed file with status and stats.
struct ChangedFileRow: View {
    let file: ChangedFile

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(file.status.symbol)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(statusColor)
                .frame(width: 16)

            // File path
            Text(file.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Stats
            if file.additions > 0 {
                Text("+\(file.additions)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            if file.deletions > 0 {
                Text("-\(file.deletions)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusColor: Color {
        switch file.status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .purple
        case .untracked: return .gray
        }
    }
}

#Preview {
    CommitDetailView(
        commit: Commit(
            sha: "abc123def456789012345678901234567890abcd",
            message: "Fix critical security vulnerability in authentication",
            fullMessage: """
                Fix critical security vulnerability in authentication

                The previous implementation allowed session tokens to be reused
                after logout. This patch ensures tokens are properly invalidated.

                - Add token invalidation on logout
                - Clear session storage
                - Add tests for edge cases
                """,
            authorName: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-3600),
            parents: ["parent123abc"],
            changedFiles: []
        ),
        changedFiles: [
            ChangedFile(path: "src/auth/session.swift", status: .modified, additions: 25, deletions: 10, oldPath: nil),
            ChangedFile(path: "src/auth/token.swift", status: .added, additions: 50, deletions: 0, oldPath: nil),
            ChangedFile(path: "tests/auth_tests.swift", status: .modified, additions: 30, deletions: 5, oldPath: nil),
            ChangedFile(path: "src/legacy/old_auth.swift", status: .deleted, additions: 0, deletions: 100, oldPath: nil)
        ]
    )
    .frame(width: 400, height: 500)
}
