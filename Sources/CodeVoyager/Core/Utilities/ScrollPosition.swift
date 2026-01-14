import Foundation

/// Represents a scroll position in a text view.
/// Used to save and restore scroll positions when switching between tabs.
///
/// ## Usage Note
/// Currently, `RepositoryViewModel.TabItem` uses `scrollOffset: CGFloat` directly
/// for simplicity. This type is retained for:
/// - Type safety and semantic clarity
/// - Future extensions (e.g., horizontal scroll, zoom level)
/// - Testing purposes
///
/// Consider migrating `TabItem.scrollOffset` to use this type when additional
/// scroll-related state is needed.
struct ScrollPosition: Equatable {
    /// Vertical scroll offset from the top of the content.
    var offset: CGFloat = 0

    /// Creates a scroll position with the specified offset.
    /// - Parameter offset: The vertical scroll offset. Defaults to 0 (top).
    init(offset: CGFloat = 0) {
        self.offset = offset
    }
}
