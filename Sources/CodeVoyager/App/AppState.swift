import SwiftUI
import os.log

/// Application-level state management.
/// Handles global state like recent repositories and open repository panel.
@MainActor
@Observable
final class AppState {
    /// List of recently opened repositories (max 10 as per PRD)
    private(set) var recentRepositories: [RecentRepository] = []

    /// Currently active repository
    var currentRepository: Repository?

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.codevoyager", category: "AppState")

    init() {
        loadRecentRepositories()
    }

    /// Show the open repository panel (Cmd+O)
    func showOpenRepositoryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a repository folder"

        if panel.runModal() == .OK, let url = panel.url {
            openRepository(at: url)
        }
    }

    /// Open a repository at the given URL
    func openRepository(at url: URL) {
        logger.info("Opening repository at: \(url.path)")

        // Validate that the path exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("Repository path does not exist: \(url.path)")
            return
        }

        // Create repository and update current
        let repository = Repository(url: url)
        currentRepository = repository

        // Update recent repositories
        addToRecentRepositories(url: url)
    }

    /// Add a repository to the recent list
    private func addToRecentRepositories(url: URL) {
        let newRecent = RecentRepository(url: url)

        // Remove if already exists
        recentRepositories.removeAll { $0.url == url }

        // Add to the front
        recentRepositories.insert(newRecent, at: 0)

        // Keep only 10 (as per PRD)
        if recentRepositories.count > 10 {
            recentRepositories = Array(recentRepositories.prefix(10))
        }

        saveRecentRepositories()
    }

    /// Load recent repositories from UserDefaults
    private func loadRecentRepositories() {
        guard let data = UserDefaults.standard.data(forKey: "recentRepositories") else {
            logger.debug("No recent repositories data found in UserDefaults")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([RecentRepository].self, from: data)
            recentRepositories = decoded
            logger.debug("Loaded \(decoded.count) recent repositories")
        } catch {
            logger.error("Failed to decode recent repositories: \(error.localizedDescription)")
            // Clear corrupted data to prevent repeated failures
            UserDefaults.standard.removeObject(forKey: "recentRepositories")
        }
    }

    /// Save recent repositories to UserDefaults
    private func saveRecentRepositories() {
        do {
            let encoded = try JSONEncoder().encode(recentRepositories)
            UserDefaults.standard.set(encoded, forKey: "recentRepositories")
            logger.debug("Saved \(self.recentRepositories.count) recent repositories")
        } catch {
            logger.error("Failed to encode recent repositories: \(error.localizedDescription)")
        }
    }
}
