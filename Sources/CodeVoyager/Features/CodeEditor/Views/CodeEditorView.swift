import AppKit
import SwiftUI
import STTextViewUI

/// Code editor view for displaying file contents with syntax highlighting.
/// Uses STTextView (TextKit 2) for high-performance text rendering.
///
/// Supports scroll position management:
/// - New files automatically scroll to top
/// - When switching tabs, scroll position is preserved and restored
struct CodeEditorView: View {
    let content: FileContent
    let fileName: String

    /// Binding to the scroll offset, managed by the parent view.
    @Binding var scrollOffset: CGFloat

    /// Whether this is a newly opened file (should scroll to top).
    let isNewFile: Bool

    @State private var text: AttributedString = AttributedString()

    /// Internal scroll offset state for the text view.
    /// This is synced with the binding.
    @State private var internalScrollOffset: CGFloat = 0

    init(
        content: FileContent,
        fileName: String,
        scrollOffset: Binding<CGFloat> = .constant(0),
        isNewFile: Bool = true
    ) {
        self.content = content
        self.fileName = fileName
        self._scrollOffset = scrollOffset
        self.isNewFile = isNewFile
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            // Text view with scroll position management
            textView
        }
    }

    private var statusBar: some View {
        HStack {
            // Line ending indicator
            Text(content.lineEnding.rawValue)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(lineEndingBackground)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Line count
            Text("\(content.lineCount) lines")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            // File size
            Text(FormatUtilities.formatFileSize(content.fileSize))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var lineEndingBackground: Color {
        switch content.lineEnding {
        case .lf: Color.clear
        case .crlf: Color.orange.opacity(0.2)
        case .mixed: Color.red.opacity(0.2)
        }
    }

    private var textView: some View {
        ScrollableTextView(
            text: $text,
            scrollOffset: $internalScrollOffset,
            scrollToTopOnContentChange: isNewFile
        )
        .onAppear {
            text = createAttributedString(from: content.content)
            // Initialize internal scroll offset from binding
            if !isNewFile {
                internalScrollOffset = scrollOffset
            }
        }
        .onChange(of: content.id) { _, _ in
            // Update text when content changes
            text = createAttributedString(from: content.content)
        }
        .onChange(of: internalScrollOffset) { _, newValue in
            // Sync internal scroll offset to binding
            scrollOffset = newValue
        }
        .onChange(of: scrollOffset) { _, newValue in
            // Sync binding to internal scroll offset (for restoration)
            if internalScrollOffset != newValue {
                internalScrollOffset = newValue
            }
        }
    }

    /// Create an AttributedString with monospace font for code display.
    private func createAttributedString(from text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        attributedString.foregroundColor = NSColor.textColor
        return attributedString
    }
}

// MARK: - Binary File Placeholder

/// View shown for binary files that cannot be displayed.
struct BinaryFilePlaceholder: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Binary file cannot be displayed")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Large File Warning

/// View shown for files exceeding the size threshold.
struct LargeFileWarning: View {
    let fileName: String
    let fileSize: Int64
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Large File Warning")
                .font(.headline)

            Text("\(fileName) is \(FormatUtilities.formatFileSize(fileSize))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Opening large files may affect performance.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Open Anyway") {
                onConfirm()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Preview

#Preview("Code Editor") {
    let content = FileContent(
        path: "/test/main.swift",
        content: """
        import Foundation

        struct App {
            let name: String

            func run() {
                print("Hello, \\(name)!")
            }
        }

        let app = App(name: "World")
        app.run()
        """,
        lineEnding: .lf,
        fileSize: 200
    )

    CodeEditorView(content: content, fileName: "main.swift")
        .frame(width: 600, height: 400)
}

#Preview("Binary File") {
    BinaryFilePlaceholder(fileName: "image.png")
        .frame(width: 400, height: 300)
}

#Preview("Large File Warning") {
    LargeFileWarning(
        fileName: "huge.json",
        fileSize: 75 * 1024 * 1024, // 75 MB
        onConfirm: {}
    )
    .frame(width: 400, height: 300)
}
