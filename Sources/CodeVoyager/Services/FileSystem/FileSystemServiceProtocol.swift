import Foundation

/// Protocol defining file system operations.
protocol FileSystemServiceProtocol {
    // MARK: - Directory Operations

    /// Get the contents of a directory (files and subdirectories).
    /// Only returns immediate children, not recursive.
    func contents(of directory: URL) async throws -> [FileNode]

    /// Check if a path is a directory.
    func isDirectory(_ url: URL) -> Bool

    /// Check if a path exists.
    func exists(_ url: URL) -> Bool

    // MARK: - File Operations

    /// Read file content.
    /// - Returns: FileContent with content and metadata
    func readFile(at url: URL) async throws -> FileContent

    /// Get file size in bytes.
    func fileSize(at url: URL) throws -> Int64

    /// Check if a file is binary.
    func isBinary(at url: URL) async throws -> Bool

    // MARK: - Git Ignore

    /// Get list of gitignored paths in a repository.
    func gitIgnoredPaths(in repository: URL) async throws -> Set<String>

    /// Check if a specific path is gitignored.
    func isGitIgnored(_ path: String, in repository: URL) async throws -> Bool

    // MARK: - File Watching

    /// Start watching a directory for changes.
    /// - Parameters:
    ///   - url: Directory to watch
    ///   - handler: Callback when changes occur
    /// - Returns: A token to stop watching
    func startWatching(
        _ url: URL,
        handler: @escaping (FileSystemEvent) -> Void
    ) throws -> FileWatchToken

    /// Stop watching using the given token.
    func stopWatching(_ token: FileWatchToken)
}

/// Represents a file system event.
struct FileSystemEvent {
    let url: URL
    let type: FileSystemEventType
}

/// Types of file system events.
enum FileSystemEventType {
    case created
    case modified
    case deleted
    case renamed
}

/// Token for stopping file watching.
protocol FileWatchToken {
    func invalidate()
}

/// Errors that can occur during file system operations.
enum FileSystemError: Error, LocalizedError {
    case fileNotFound(URL)
    case directoryNotFound(URL)
    case readError(URL, Error)
    case permissionDenied(URL)
    case fileTooLarge(URL, Int64)
    case binaryFile(URL)
    case encodingError(URL)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .directoryNotFound(let url):
            return "Directory not found: \(url.path)"
        case .readError(let url, let error):
            return "Failed to read \(url.path): \(error.localizedDescription)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.path)"
        case .fileTooLarge(let url, let size):
            let sizeInMB = Double(size) / (1024 * 1024)
            return "File too large: \(url.lastPathComponent) (\(String(format: "%.1f", sizeInMB)) MB)"
        case .binaryFile(let url):
            return "Binary file cannot be displayed: \(url.lastPathComponent)"
        case .encodingError(let url):
            return "Failed to decode file: \(url.lastPathComponent)"
        }
    }
}
