import Foundation

/// Represents a node in the file tree (file or directory).
struct FileNode: Identifiable, Hashable {
    let id: UUID
    let url: URL

    /// Children nodes (nil for files, empty array for empty directories)
    var children: [FileNode]?

    /// Whether this node is a directory
    var isDirectory: Bool {
        children != nil
    }

    /// File/directory name
    var name: String {
        url.lastPathComponent
    }

    /// Full path
    var path: String {
        url.path
    }

    /// File extension (empty for directories)
    var fileExtension: String {
        isDirectory ? "" : url.pathExtension.lowercased()
    }

    /// Whether this is a gitignored file (for gray display)
    var isGitIgnored: Bool = false

    /// Whether this node is currently expanded (for directories)
    var isExpanded: Bool = false

    /// Whether children have been loaded (for lazy loading)
    var isLoaded: Bool = false

    init(
        id: UUID = UUID(),
        url: URL,
        children: [FileNode]? = nil,
        isGitIgnored: Bool = false
    ) {
        self.id = id
        self.url = url
        self.children = children
        self.isGitIgnored = isGitIgnored
    }

    /// Get the appropriate SF Symbol for this file type.
    var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }

        if isGitRelatedFile {
            return "arrow.triangle.branch"
        }

        return Self.extensionIcons[fileExtension] ?? "doc"
    }

    private var isGitRelatedFile: Bool {
        let fileName = name.lowercased()
        return fileName.hasPrefix(".git") || fileName == ".gitignore" || fileName == ".gitattributes"
    }

    /// Maps file extensions to SF Symbol names.
    private static let extensionIcons: [String: String] = [
        "swift": "swift",
        "js": "curlybraces",
        "jsx": "curlybraces",
        "ts": "curlybraces",
        "tsx": "curlybraces",
        "py": "chevron.left.forwardslash.chevron.right",
        "html": "globe",
        "htm": "globe",
        "css": "paintbrush",
        "scss": "paintbrush",
        "sass": "paintbrush",
        "json": "doc.text",
        "yaml": "doc.text",
        "yml": "doc.text",
        "toml": "doc.text",
        "md": "doc.richtext",
        "markdown": "doc.richtext",
        "png": "photo",
        "jpg": "photo",
        "jpeg": "photo",
        "gif": "photo",
        "svg": "photo",
        "ico": "photo",
        "pdf": "doc.fill",
        "zip": "doc.zipper",
        "tar": "doc.zipper",
        "gz": "doc.zipper",
        "rar": "doc.zipper",
        "sh": "terminal",
        "bash": "terminal",
        "zsh": "terminal",
    ]
}

/// Represents the line ending type of a file.
enum LineEnding: String {
    case lf = "LF"
    case crlf = "CRLF"
    case mixed = "Mixed"

    var displaySymbol: String {
        switch self {
        case .lf: return "↵"
        case .crlf: return "↵↵"
        case .mixed: return "⚠️"
        }
    }
}

/// File content with metadata.
struct FileContent: Identifiable, Hashable {
    let id: UUID
    let path: String
    let content: String
    let encoding: String.Encoding
    let lineEnding: LineEnding
    let lineCount: Int
    let isBinary: Bool
    let fileSize: Int64

    /// Check if file is too large (> 50MB as per PRD)
    var isTooLarge: Bool {
        fileSize > 50 * 1024 * 1024
    }

    init(
        id: UUID = UUID(),
        path: String,
        content: String = "",
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding = .lf,
        isBinary: Bool = false,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.path = path
        self.content = content
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.lineCount = Self.calculateLineCount(content)
        self.isBinary = isBinary
        self.fileSize = fileSize
    }

    /// Calculate the number of lines in content.
    /// - Empty content returns 0
    /// - Content without newlines returns 1
    /// - Trailing newline does not add an extra line
    private static func calculateLineCount(_ content: String) -> Int {
        if content.isEmpty { return 0 }

        let components = content.components(separatedBy: .newlines)
        let count = components.count

        // If content ends with a newline, the last component is empty
        // We should not count this empty trailing component as a line
        if let last = components.last, last.isEmpty {
            return max(0, count - 1)
        }

        return count
    }
}
