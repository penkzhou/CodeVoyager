import AppKit
import SwiftUI
import STTextView
import STTextViewSwiftUI
import Neon

/// Callback type for when the text view is created.
/// Used to set up syntax highlighting after the view is available.
typealias TextViewCreatedCallback = (STTextView) -> Void

/// A text view wrapper that supports scroll position persistence and syntax highlighting.
/// Wraps STTextView with additional scroll position management capabilities.
struct ScrollableTextView: NSViewRepresentable {
    @Binding var text: AttributedString
    @Binding var scrollOffset: CGFloat

    /// Whether to scroll to top when content changes.
    /// Set to true when loading a new file, false when restoring a saved position.
    let scrollToTopOnContentChange: Bool

    /// Font to use for the text view.
    let font: NSFont

    /// Optional callback when the text view is created.
    /// Used for syntax highlighting setup.
    let onTextViewCreated: TextViewCreatedCallback?

    /// Optional callback when visible content changes (scroll).
    let onVisibleContentChanged: (() -> Void)?

    init(
        text: Binding<AttributedString>,
        scrollOffset: Binding<CGFloat>,
        scrollToTopOnContentChange: Bool = true,
        font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular),
        onTextViewCreated: TextViewCreatedCallback? = nil,
        onVisibleContentChanged: (() -> Void)? = nil
    ) {
        self._text = text
        self._scrollOffset = scrollOffset
        self.scrollToTopOnContentChange = scrollToTopOnContentChange
        self.font = font
        self.onTextViewCreated = onTextViewCreated
        self.onVisibleContentChanged = onVisibleContentChanged
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        let textView = scrollView.documentView as! STTextView

        // Store reference in coordinator for callbacks
        context.coordinator.textView = textView

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = false  // Renamed from widthTracksTextView
        textView.highlightSelectedLine = false
        textView.font = font

        // Set initial text
        context.coordinator.isUpdating = true
        textView.attributedText = NSAttributedString(text)
        context.coordinator.isUpdating = false

        // Set selection to beginning to prevent STTextView from scrolling to end
        textView.selectAndShow(NSRange(location: 0, length: 0))

        // Scroll to top initially
        scrollToTop(scrollView, textView: textView)

        // Observe scroll position changes
        context.coordinator.observeScroll(scrollView: scrollView)

        // Notify callback that text view is created
        onTextViewCreated?(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! STTextView

        // Check if text content changed by comparing string content (not AttributedString attributes)
        let currentTextString = textView.attributedString().string
        let newTextString = String(text.characters)

        if currentTextString != newTextString {
            context.coordinator.isUpdating = true
            textView.attributedText = NSAttributedString(text)
            context.coordinator.isUpdating = false

            // Set selection to beginning to prevent STTextView from scrolling to end
            textView.selectAndShow(NSRange(location: 0, length: 0))

            if scrollToTopOnContentChange {
                // Scroll to top when content changes (new file opened)
                scrollToTop(scrollView, textView: textView)
            } else {
                // Restore saved scroll position
                restoreScrollPosition(scrollView, offset: scrollOffset)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Scroll Helpers

    private func scrollToTop(_ scrollView: NSScrollView, textView: STTextView) {
        // Use asyncAfter to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Use STTextView's scrollRangeToVisible to scroll to beginning
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))

            // Also set the scroll view position directly
            let clipView = scrollView.contentView
            clipView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    private func restoreScrollPosition(_ scrollView: NSScrollView, offset: CGFloat) {
        // Use asyncAfter to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let clipView = scrollView.contentView
            let point = NSPoint(x: 0, y: offset)
            clipView.scroll(to: point)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: ScrollableTextView
        var isUpdating = false
        weak var textView: STTextView?
        private weak var observedContentView: NSClipView?

        init(parent: ScrollableTextView) {
            self.parent = parent
            super.init()
        }

        deinit {
            if let observedContentView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedContentView
                )
            }
        }

        @MainActor
        func observeScroll(scrollView: NSScrollView) {
            // Remove any existing observer
            if let observedContentView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedContentView
                )
            }

            // Observe bounds changes of the clip view (scroll events)
            let contentView = scrollView.contentView
            observedContentView = contentView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: contentView
            )

            // Enable bounds change notifications
            contentView.postsBoundsChangedNotifications = true
        }

        @MainActor
        @objc private func handleBoundsDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let clipView = notification.object as? NSClipView else { return }

            // Update the scroll offset binding
            let newOffset = clipView.bounds.origin.y
            if parent.scrollOffset != newOffset {
                parent.scrollOffset = newOffset
            }

            // Notify of visible content change
            parent.onVisibleContentChanged?()
        }
    }
}

// MARK: - Preview

#Preview("ScrollableTextView") {
    struct PreviewWrapper: View {
        @State private var text = AttributedString("Hello, World!\n\n" + String(repeating: "Line of text\n", count: 100))
        @State private var scrollOffset: CGFloat = 0

        var body: some View {
            VStack {
                Text("Scroll offset: \(Int(scrollOffset))")
                    .padding()

                ScrollableTextView(
                    text: $text,
                    scrollOffset: $scrollOffset
                )
            }
            .frame(width: 400, height: 300)
        }
    }
    return PreviewWrapper()
}
