import Foundation
import os.log

/// Concrete implementation of FileSystemServiceProtocol.
/// Handles all file system operations including directory traversal and file reading.
final class FileSystemService: FileSystemServiceProtocol {
    // MARK: - Properties

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.codevoyager", category: "FileSystemService")

    /// Maximum file size before warning (50MB as per PRD)
    private let maxFileSize: Int64 = 50 * 1024 * 1024

    /// Sample size for binary detection
    private let binarySampleSize = 8192

    // MARK: - Directory Operations

    func contents(of directory: URL) async throws -> [FileNode] {
        guard isDirectory(directory) else {
            throw FileSystemError.directoryNotFound(directory)
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            )

            let nodes = contents.compactMap { url -> FileNode? in
                createFileNode(from: url)
            }

            // Sort: directories first, then alphabetically
            return nodes.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        } catch {
            logger.error("Failed to read directory contents: \(error.localizedDescription)")
            throw FileSystemError.readError(directory, error)
        }
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    // MARK: - File Operations

    func readFile(at url: URL) async throws -> FileContent {
        guard exists(url) else {
            throw FileSystemError.fileNotFound(url)
        }

        // Check file size
        let size = try fileSize(at: url)
        if size > maxFileSize {
            throw FileSystemError.fileTooLarge(url, size)
        }

        // Check if binary
        if try await isBinary(at: url) {
            throw FileSystemError.binaryFile(url)
        }

        do {
            let data = try Data(contentsOf: url)

            // Try to decode as UTF-8 first, then other encodings
            guard let content = decodeContent(data) else {
                throw FileSystemError.encodingError(url)
            }

            let lineEnding = detectLineEnding(in: content)

            return FileContent(
                path: url.path,
                content: content,
                encoding: .utf8,
                lineEnding: lineEnding,
                fileSize: size
            )
        } catch let error as FileSystemError {
            throw error
        } catch {
            logger.error("Failed to read file: \(error.localizedDescription)")
            throw FileSystemError.readError(url, error)
        }
    }

    func fileSize(at url: URL) throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int64 else {
                logger.warning("Unable to read file size for '\(url.path)', defaulting to 0")
                return 0
            }
            return size
        } catch {
            throw FileSystemError.readError(url, error)
        }
    }

    func isBinary(at url: URL) async throws -> Bool {
        guard exists(url) else {
            throw FileSystemError.fileNotFound(url)
        }

        // Read first N bytes to check for binary content
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            throw FileSystemError.readError(url, NSError(domain: "FileSystemService", code: -1))
        }

        defer { try? fileHandle.close() }

        let data = fileHandle.readData(ofLength: binarySampleSize)

        // Check for null bytes (common indicator of binary files)
        return data.contains(0)
    }

    // MARK: - Git Ignore

    func gitIgnoredPaths(in repository: URL) async -> Set<String> {
        let gitDir = repository.appendingPathComponent(".git")
        guard exists(gitDir) else {
            logger.debug("Not a Git repository, skipping gitignore parsing: \(repository.path)")
            return []
        }

        // Use git CLI to get ignored files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repository.path, "status", "--ignored", "--porcelain"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                logger.warning("Failed to decode git status output for gitignore parsing in \(repository.path)")
                return []
            }

            // Parse git status output for ignored files (lines starting with "!!")
            var ignored = Set<String>()
            for line in output.components(separatedBy: .newlines) {
                if line.hasPrefix("!! ") {
                    let path = String(line.dropFirst(3))
                    ignored.insert(path)
                }
            }
            return ignored
        } catch {
            // Log warning so users can see in console if needed, but don't block file tree loading
            logger.warning("Failed to parse gitignore (file tree will show all files): \(error.localizedDescription)")
            return []
        }
    }

    func isGitIgnored(_ path: String, in repository: URL) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repository.path, "check-ignore", "-q", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            // Exit code 0 means the file is ignored
            return process.terminationStatus == 0
        } catch {
            logger.warning("Failed to check git ignore status for '\(path)': \(error.localizedDescription)")
            // Return false as fallback - file will be treated as not ignored
            return false
        }
    }

    // MARK: - File Watching

    func startWatching(
        _ url: URL,
        handler: @escaping (FileSystemEvent) -> Void
    ) throws -> FileWatchToken {
        FSEventsWatcher(url: url, handler: handler)
    }

    func stopWatching(_ token: FileWatchToken) {
        token.invalidate()
    }

    // MARK: - Private Helpers

    private func createFileNode(from url: URL) -> FileNode? {
        let isDir = isDirectory(url)

        return FileNode(
            url: url,
            children: isDir ? [] : nil,
            isGitIgnored: false
        )
    }

    private func decodeContent(_ data: Data) -> String? {
        // Try UTF-8 first (most common)
        if let content = String(data: data, encoding: .utf8) {
            return content
        }

        // Try other common encodings
        let encodings: [String.Encoding] = [
            .isoLatin1,
            .windowsCP1252,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
        ]

        for encoding in encodings {
            if let content = String(data: data, encoding: encoding) {
                return content
            }
        }

        return nil
    }

    private func detectLineEnding(in content: String) -> LineEnding {
        let hasCRLF = content.contains("\r\n")

        // Remove all CRLF first, then check for remaining LF or CR
        let withoutCRLF = content.replacingOccurrences(of: "\r\n", with: "")
        let hasStandaloneLF = withoutCRLF.contains("\n")
        let hasStandaloneCR = withoutCRLF.contains("\r")

        if hasCRLF && (hasStandaloneLF || hasStandaloneCR) {
            return .mixed
        } else if hasCRLF {
            return .crlf
        } else if hasStandaloneLF {
            return .lf
        } else if hasStandaloneCR {
            return .lf  // Old Mac format, treat as LF
        } else {
            return .lf  // No line endings
        }
    }
}

// MARK: - FSEvents Watcher

/// File watcher using FSEvents API.
/// 使用 retain/release 回调确保内存安全，避免悬空指针
final class FSEventsWatcher: FileWatchToken {
    private var stream: FSEventStreamRef?
    private let handler: (FileSystemEvent) -> Void
    private let url: URL

    init(url: URL, handler: @escaping (FileSystemEvent) -> Void) {
        self.url = url
        self.handler = handler
        setupStream()
    }

    private func setupStream() {
        let pathToWatch = url.path as CFString
        let pathsToWatch = [pathToWatch] as CFArray

        // 问题 8 修复: 使用 retain/release 回调让 FSEvents 管理引用计数
        // 这确保即使 FSEventsWatcher 在回调执行前被释放，也不会有悬空指针
        let retainCallback: CFAllocatorRetainCallBack = { info in
            guard let info = info else { return nil }
            _ = Unmanaged<FSEventsWatcher>.fromOpaque(info).retain()
            return UnsafeRawPointer(info)
        }
        
        let releaseCallback: CFAllocatorReleaseCallBack = { info in
            guard let info = info else { return }
            Unmanaged<FSEventsWatcher>.fromOpaque(info).release()
        }
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: retainCallback,
            release: releaseCallback,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
            guard let info = info else { return }
            // Safe: FSEvents framework holds a retain via our retain callback
            let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()

            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

            for i in 0 ..< numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                let eventType = watcher.mapFlags(flags)
                let event = FileSystemEvent(
                    url: URL(fileURLWithPath: path),
                    type: eventType
                )
                watcher.handler(event)
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    private func mapFlags(_ flags: FSEventStreamEventFlags) -> FileSystemEventType {
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            return .created
        } else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            return .deleted
        } else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            return .renamed
        } else {
            return .modified
        }
    }

    func invalidate() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            // FSEventStreamRelease will call our release callback, balancing the initial passRetained
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    deinit {
        invalidate()
    }
}
