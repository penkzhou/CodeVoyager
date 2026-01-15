import SwiftUI

/// Main application entry point for CodeVoyager.
/// A native macOS code reading and Git viewing application.
@main
struct CodeVoyagerApp: App {
    @State private var appState = AppState()

    init() {
        // 预加载语法高亮语言配置，避免首次使用时的延迟
        Task.detached(priority: .background) {
            LanguageRegistry.shared.preloadAllConfigurations()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Repository...") {
                    appState.showOpenRepositoryPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()
                Menu("Recent Repositories") {
                    ForEach(appState.recentRepositories) { repo in
                        Button(repo.name) {
                            appState.openRepository(at: repo.url)
                        }
                    }
                    if appState.recentRepositories.isEmpty {
                        Text("No Recent Repositories")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
