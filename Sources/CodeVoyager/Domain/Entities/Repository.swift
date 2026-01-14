import Foundation

/// Represents a Git repository.
struct Repository: Identifiable, Hashable {
    let id: UUID
    let url: URL

    /// Repository name (directory name)
    var name: String {
        url.lastPathComponent
    }

    /// Full path to the repository
    var path: String {
        url.path
    }

    /// Check if this is a valid Git repository
    var isGitRepository: Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
    }

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
    }
}

/// Represents a recently opened repository for persistence.
struct RecentRepository: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let lastOpened: Date

    /// Repository name (directory name)
    var name: String {
        url.lastPathComponent
    }

    /// Full path for display
    var path: String {
        url.path
    }

    /// Check if the repository still exists on disk
    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    init(id: UUID = UUID(), url: URL, lastOpened: Date = Date()) {
        self.id = id
        self.url = url
        self.lastOpened = lastOpened
    }
}
