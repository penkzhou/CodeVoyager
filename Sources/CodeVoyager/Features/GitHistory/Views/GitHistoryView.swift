import SwiftUI

/// Main view for displaying Git commit history.
///
/// Uses a vertical split layout:
/// - Top: Scrollable commit list with lazy loading
/// - Bottom: Commit detail panel (when a commit is selected)
struct GitHistoryView: View {
    @Bindable var viewModel: GitHistoryViewModel

    /// Minimum height for the commit list area
    private let minListHeight: CGFloat = 200

    /// Default split position
    @State private var detailHeight: CGFloat = 250

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Commit list (top)
                commitListArea
                    .frame(minHeight: minListHeight)

                // Resizable divider
                if viewModel.selectedCommit != nil {
                    Divider()

                    // Detail panel (bottom)
                    detailArea
                        .frame(height: detailHeight)
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var commitListArea: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            loadingView

        case .loaded:
            commitList

        case .error(let message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading commits...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Failed to load history")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commitList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.commits) { commit in
                    CommitRowView(
                        commit: commit,
                        branches: viewModel.branches(for: commit.sha),
                        tags: viewModel.tags(for: commit.sha),
                        isSelected: viewModel.selectedCommit?.sha == commit.sha
                    )
                    .onTapGesture {
                        Task {
                            await viewModel.selectCommit(commit)
                        }
                    }

                    Divider()
                }

                // Load more trigger
                if viewModel.hasMoreCommits {
                    loadMoreTrigger
                }
            }
        }
    }

    private var loadMoreTrigger: some View {
        ProgressView()
            .frame(height: 50)
            .onAppear {
                Task {
                    await viewModel.loadMoreCommits()
                }
            }
    }

    @ViewBuilder
    private var detailArea: some View {
        if let commit = viewModel.selectedCommit {
            CommitDetailView(
                commit: commit,
                changedFiles: viewModel.selectedCommitFiles
            )
        }
    }
}

#Preview {
    // Note: This preview won't work without a real repository
    // Use the app for testing
    Text("GitHistoryView Preview")
        .frame(width: 400, height: 600)
}
