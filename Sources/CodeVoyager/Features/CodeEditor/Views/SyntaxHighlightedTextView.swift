import AppKit
import SwiftUI
import STTextView
import STTextViewUI
import Neon
import TreeSitterClient
import os.log

/// A text view with integrated syntax highlighting.
///
/// This view combines STTextView with Neon-based syntax highlighting.
/// It automatically detects the language based on file extension and applies
/// appropriate syntax highlighting using the current theme.
///
/// ## Usage
/// ```swift
/// SyntaxHighlightedTextView(
///     content: fileContent,
///     fileURL: fileURL,
///     scrollOffset: $scrollOffset
/// )
/// ```
struct SyntaxHighlightedTextView: NSViewRepresentable {
    private static let logger = Logger(subsystem: "CodeVoyager", category: "SyntaxHighlightedTextView")

    /// The text content to display
    let content: String

    /// The file URL (used for language detection)
    let fileURL: URL

    /// Binding to the scroll offset
    @Binding var scrollOffset: CGFloat

    /// Whether to scroll to top when content changes
    let scrollToTopOnContentChange: Bool

    /// Font to use for the text view
    let font: NSFont

    /// Language registry for language detection
    let languageRegistry: LanguageRegistryProtocol

    /// Theme manager for styling
    let themeManager: ThemeManagerProtocol

    init(
        content: String,
        fileURL: URL,
        scrollOffset: Binding<CGFloat>,
        scrollToTopOnContentChange: Bool = true,
        font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular),
        languageRegistry: LanguageRegistryProtocol = LanguageRegistry.shared,
        themeManager: ThemeManagerProtocol = ThemeManager.shared
    ) {
        self.content = content
        self.fileURL = fileURL
        self._scrollOffset = scrollOffset
        self.scrollToTopOnContentChange = scrollToTopOnContentChange
        self.font = font
        self.languageRegistry = languageRegistry
        self.themeManager = themeManager
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        let textView = scrollView.documentView as! STTextView

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.widthTracksTextView = true
        textView.highlightSelectedLine = false
        textView.font = font

        // Apply theme background color
        let theme = themeManager.currentTheme
        textView.backgroundColor = theme.backgroundColor

        // Set initial text
        context.coordinator.isUpdating = true
        let attributedString = createAttributedString(from: content, theme: theme)
        textView.setAttributedString(attributedString)
        context.coordinator.isUpdating = false

        // Set selection to beginning
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Store reference for highlighting
        context.coordinator.textView = textView
        context.coordinator.currentContent = content
        context.coordinator.currentFileURL = fileURL

        // Setup syntax highlighting
        context.coordinator.setupHighlighting(
            content: content,
            fileURL: fileURL,
            languageRegistry: languageRegistry,
            themeManager: themeManager,
            font: font
        )

        // Scroll to top initially
        scrollToTop(scrollView, textView: textView)

        // Observe scroll position changes
        context.coordinator.observeScroll(scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! STTextView

        // Check if content changed
        let contentChanged = context.coordinator.currentContent != content

        // Check if file changed
        let fileChanged = context.coordinator.currentFileURL != fileURL

        if contentChanged || fileChanged {
            context.coordinator.isUpdating = true

            // Update theme
            let theme = themeManager.currentTheme
            textView.backgroundColor = theme.backgroundColor

            // Update text
            let attributedString = createAttributedString(from: content, theme: theme)
            textView.setAttributedString(attributedString)

            context.coordinator.isUpdating = false

            // Set selection to beginning
            textView.setSelectedRange(NSRange(location: 0, length: 0))

            // Update stored state
            context.coordinator.currentContent = content
            context.coordinator.currentFileURL = fileURL

            // Re-setup highlighting if file changed
            if fileChanged {
                context.coordinator.setupHighlighting(
                    content: content,
                    fileURL: fileURL,
                    languageRegistry: languageRegistry,
                    themeManager: themeManager,
                    font: font
                )
            } else if contentChanged {
                // Just invalidate if only content changed
                context.coordinator.invalidateHighlighting()
            }

            if scrollToTopOnContentChange {
                scrollToTop(scrollView, textView: textView)
            } else {
                restoreScrollPosition(scrollView, offset: scrollOffset)
            }
        }

        // Update theme if changed
        let currentTheme = themeManager.currentTheme
        if textView.backgroundColor != currentTheme.backgroundColor {
            textView.backgroundColor = currentTheme.backgroundColor
            context.coordinator.invalidateHighlighting()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Private Helpers

    private func createAttributedString(from text: String, theme: SyntaxTheme) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.defaultStyle.color
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private func scrollToTop(_ scrollView: NSScrollView, textView: STTextView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            let clipView = scrollView.contentView
            clipView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    private func restoreScrollPosition(_ scrollView: NSScrollView, offset: CGFloat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let clipView = scrollView.contentView
            let point = NSPoint(x: 0, y: offset)
            clipView.scroll(to: point)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        private static let logger = Logger(subsystem: "CodeVoyager", category: "SyntaxHighlightedTextView.Coordinator")

        var parent: SyntaxHighlightedTextView
        var isUpdating = false
        weak var textView: STTextView?
        var currentContent: String = ""
        var currentFileURL: URL?

        private var scrollObserver: NSObjectProtocol?
        private var highlighter: Highlighter?
        private var treeSitterClient: TreeSitterClient?
        private var currentLanguage: SupportedLanguage?

        init(parent: SyntaxHighlightedTextView) {
            self.parent = parent
            super.init()
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func observeScroll(scrollView: NSScrollView) {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      !self.isUpdating,
                      let clipView = notification.object as? NSClipView else { return }

                let newOffset = clipView.bounds.origin.y
                if self.parent.scrollOffset != newOffset {
                    self.parent.scrollOffset = newOffset
                }

                // Notify highlighter of visible content change
                self.highlighter?.visibleContentDidChange()
            }

            scrollView.contentView.postsBoundsChangedNotifications = true
        }

        @MainActor
        func setupHighlighting(
            content: String,
            fileURL: URL,
            languageRegistry: LanguageRegistryProtocol,
            themeManager: ThemeManagerProtocol,
            font: NSFont
        ) {
            guard let textView = textView else {
                Self.logger.warning("Cannot setup highlighting: textView is nil")
                return
            }

            // Detect language
            guard let language = languageRegistry.detectLanguage(for: fileURL) else {
                Self.logger.debug("No supported language detected for \(fileURL.lastPathComponent)")
                currentLanguage = nil
                highlighter = nil
                treeSitterClient = nil
                return
            }

            // Get or create TreeSitterClient
            do {
                let config = try languageRegistry.configuration(for: language)

                // Create new client if language changed
                if currentLanguage != language {
                    treeSitterClient = try TreeSitterClient(language: config.tsLanguage)
                    currentLanguage = language
                    Self.logger.debug("Created TreeSitterClient for \(language.displayName)")
                }

                guard let client = treeSitterClient,
                      let query = config.highlightsQuery else {
                    Self.logger.warning("Missing client or query for \(language.displayName)")
                    return
                }

                // Set initial content
                client.didChangeContent(
                    to: content,
                    in: NSRange(location: 0, length: 0),
                    delta: content.utf16.count,
                    limit: content.utf16.count
                )

                // Capture current theme for the closure
                // Note: Theme changes during highlighting session will use the captured theme
                let currentTheme = themeManager.currentTheme

                // Create text system interface
                let textInterface = STTextViewSystemInterface(
                    textView: textView,
                    attributeProvider: { token in
                        let style = currentTheme.style(for: token.name)
                        return style.attributes(baseFont: font)
                    }
                )

                // Create token provider
                let tokenProvider = client.tokenProvider(
                    with: query,
                    executionMode: .asynchronous(prefetch: true)
                )

                // Create highlighter
                highlighter = Highlighter(
                    textInterface: textInterface,
                    tokenProvider: tokenProvider
                )

                // Setup invalidation handler
                client.invalidationHandler = { [weak self] ranges in
                    self?.highlighter?.invalidate(.set(ranges))
                }

                // Trigger initial highlighting
                highlighter?.invalidate(.all)

                Self.logger.debug("Syntax highlighting setup complete for \(fileURL.lastPathComponent)")

            } catch {
                Self.logger.error("Failed to setup highlighting: \(error.localizedDescription)")
            }
        }

        func invalidateHighlighting() {
            highlighter?.invalidate(.all)
        }
    }
}

// MARK: - Preview

#Preview("SyntaxHighlightedTextView - Swift") {
    struct PreviewWrapper: View {
        @State private var scrollOffset: CGFloat = 0

        let swiftCode = """
        import Foundation

        struct App {
            let name: String

            func run() {
                print("Hello, \\(name)!")
            }
        }

        let app = App(name: "World")
        app.run()
        """

        var body: some View {
            SyntaxHighlightedTextView(
                content: swiftCode,
                fileURL: URL(fileURLWithPath: "/test/main.swift"),
                scrollOffset: $scrollOffset
            )
            .frame(width: 500, height: 300)
        }
    }
    return PreviewWrapper()
}

#Preview("SyntaxHighlightedTextView - Python") {
    struct PreviewWrapper: View {
        @State private var scrollOffset: CGFloat = 0

        let pythonCode = """
        def greet(name):
            \"\"\"Greet someone.\"\"\"
            print(f"Hello, {name}!")

        # Main entry
        if __name__ == "__main__":
            greet("World")
        """

        var body: some View {
            SyntaxHighlightedTextView(
                content: pythonCode,
                fileURL: URL(fileURLWithPath: "/test/main.py"),
                scrollOffset: $scrollOffset
            )
            .frame(width: 500, height: 300)
        }
    }
    return PreviewWrapper()
}
