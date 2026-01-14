import Foundation

/// Shared formatting utilities.
enum FormatUtilities {
    /// Format file size in bytes to human-readable string.
    /// Uses ByteCountFormatter with file count style.
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
