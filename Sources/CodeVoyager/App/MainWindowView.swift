import SwiftUI

/// Main window view with three-column layout.
/// - Sidebar: File tree
/// - Content: Code editor with tabs
/// - Detail: Git history (optional)
struct MainWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let repository = appState.currentRepository {
                RepositoryView(repository: repository)
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

/// Welcome view shown when no repository is open.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Welcome to CodeVoyager")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Open a repository to get started")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(action: { appState.showOpenRepositoryPanel() }) {
                Label("Open Repository", systemImage: "folder")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !appState.recentRepositories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Repositories")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(appState.recentRepositories.prefix(5)) { repo in
                        RecentRepositoryRow(repository: repo)
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(48)
    }
}

/// Row view for a recent repository.
struct RecentRepositoryRow: View {
    @Environment(AppState.self) private var appState
    let repository: RecentRepository

    var body: some View {
        Button(action: { appState.openRepository(at: repository.url) }) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(repository.name)
                        .fontWeight(.medium)
                    Text(repository.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if !repository.exists {
                    Text("Not Found")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Placeholder for Settings view.
struct SettingsView: View {
    var body: some View {
        Text("Settings (Coming Soon)")
            .frame(width: 400, height: 200)
    }
}

#Preview("Welcome") {
    WelcomeView()
        .environment(AppState())
}
