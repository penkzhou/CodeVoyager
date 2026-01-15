import AppKit
import SwiftUI
import STTextViewUI

/// Code editor view for displaying file contents with syntax highlighting.
/// Uses STTextView (TextKit 2) for high-performance text rendering.
///
/// Supports:
/// - Syntax highlighting based on file extension
/// - Scroll position persistence
/// - Language detection and display
struct CodeEditorView: View {
    let content: FileContent
    let fileName: String

    /// Binding to the scroll offset, managed by the parent view.
    @Binding var scrollOffset: CGFloat

    /// Whether this is a newly opened file (should scroll to top).
    let isNewFile: Bool

    /// Language registry for syntax highlighting
    let languageRegistry: LanguageRegistryProtocol

    /// Internal scroll offset state for the text view.
    /// This is synced with the binding.
    @State private var internalScrollOffset: CGFloat = 0

    /// Detected language for the file
    @State private var detectedLanguage: SupportedLanguage?

    init(
        content: FileContent,
        fileName: String,
        scrollOffset: Binding<CGFloat> = .constant(0),
        isNewFile: Bool = true,
        languageRegistry: LanguageRegistryProtocol = LanguageRegistry.shared
    ) {
        self.content = content
        self.fileName = fileName
        self._scrollOffset = scrollOffset
        self.isNewFile = isNewFile
        self.languageRegistry = languageRegistry
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            // Text view with syntax highlighting
            textView
        }
        .onAppear {
            detectLanguage()
            if !isNewFile {
                internalScrollOffset = scrollOffset
            }
        }
        .onChange(of: content.id) { _, _ in
            detectLanguage()
        }
        .onChange(of: internalScrollOffset) { _, newValue in
            scrollOffset = newValue
        }
        .onChange(of: scrollOffset) { _, newValue in
            if internalScrollOffset != newValue {
                internalScrollOffset = newValue
            }
        }
    }

    // MARK: - Status Bar

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

            // Language indicator
            if let language = detectedLanguage {
                HStack(spacing: 4) {
                    Image(systemName: language.iconName)
                        .font(.caption2)
                    Text(language.displayName)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            } else {
                Text("Plain Text")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // File size
            Text(FormatUtilities.formatFileSize(content.fileSize))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
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

    // MARK: - Text View

    private var textView: some View {
        SyntaxHighlightedTextView(
            content: content.content,
            fileURL: URL(fileURLWithPath: content.path),
            scrollOffset: $internalScrollOffset,
            scrollToTopOnContentChange: isNewFile,
            languageRegistry: languageRegistry
        )
    }

    // MARK: - Private Helpers

    private func detectLanguage() {
        let fileURL = URL(fileURLWithPath: content.path)
        detectedLanguage = languageRegistry.detectLanguage(for: fileURL)
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

#Preview("Code Editor - Swift") {
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

#Preview("Code Editor - Python") {
    let content = FileContent(
        path: "/test/main.py",
        content: """
        def greet(name):
            \"\"\"Greet someone.\"\"\"
            print(f"Hello, {name}!")

        # Main entry
        if __name__ == "__main__":
            greet("World")
        """,
        lineEnding: .lf,
        fileSize: 150
    )

    CodeEditorView(content: content, fileName: "main.py")
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
