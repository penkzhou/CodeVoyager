import Foundation

/// Represents the diff result for a file.
struct DiffResult: Identifiable, Hashable {
    let id: UUID
    let filePath: String
    let oldPath: String?
    let hunks: [DiffHunk]
    let status: ChangeStatus

    /// File name without directory
    var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    /// Total lines added
    var totalAdditions: Int {
        hunks.reduce(0) { $0 + $1.additions }
    }

    /// Total lines deleted
    var totalDeletions: Int {
        hunks.reduce(0) { $0 + $1.deletions }
    }

    init(
        id: UUID = UUID(),
        filePath: String,
        oldPath: String? = nil,
        hunks: [DiffHunk] = [],
        status: ChangeStatus = .modified
    ) {
        self.id = id
        self.filePath = filePath
        self.oldPath = oldPath
        self.hunks = hunks
        self.status = status
    }
}

/// Represents a hunk (section) of a diff.
struct DiffHunk: Identifiable, Hashable {
    let id: UUID
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let header: String
    let lines: [DiffLine]

    /// Number of lines added in this hunk
    var additions: Int {
        lines.filter { $0.type == .addition }.count
    }

    /// Number of lines deleted in this hunk
    var deletions: Int {
        lines.filter { $0.type == .deletion }.count
    }

    init(
        id: UUID = UUID(),
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        header: String = "",
        lines: [DiffLine] = []
    ) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.header = header
        self.lines = lines
    }
}

/// Represents a single line in a diff.
struct DiffLine: Identifiable, Hashable {
    let id: UUID
    let content: String
    let type: DiffLineType
    let oldLineNumber: Int?
    let newLineNumber: Int?

    /// Character-level changes within this line (for highlighting)
    var inlineChanges: [InlineChange] = []

    init(
        id: UUID = UUID(),
        content: String,
        type: DiffLineType,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil,
        inlineChanges: [InlineChange] = []
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.inlineChanges = inlineChanges
    }
}

/// Type of diff line.
enum DiffLineType: Hashable {
    case context
    case addition
    case deletion
    case hunkHeader
}

/// Represents a character-level change within a line.
struct InlineChange: Identifiable, Hashable {
    let id: UUID
    let range: Range<String.Index>
    let type: InlineChangeType

    init(id: UUID = UUID(), range: Range<String.Index>, type: InlineChangeType) {
        self.id = id
        self.range = range
        self.type = type
    }

    // Custom Hashable implementation since Range<String.Index> isn't directly Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InlineChange, rhs: InlineChange) -> Bool {
        lhs.id == rhs.id
    }
}

/// Type of inline change.
enum InlineChangeType: Hashable {
    case added
    case deleted
}

/// Display mode for diff view.
enum DiffDisplayMode: String, CaseIterable {
    case sideBySide = "Side by Side"
    case unified = "Unified"

    var icon: String {
        switch self {
        case .sideBySide: return "rectangle.split.2x1"
        case .unified: return "rectangle"
        }
    }
}
