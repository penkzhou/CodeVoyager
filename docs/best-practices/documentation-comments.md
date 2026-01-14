# 文档注释最佳实践

本文档描述如何编写清晰、完整的代码注释，帮助团队成员理解设计决策和使用方式。

## 类型级注释

### 自定义协议实现说明

当类型有自定义的 `Hashable`、`Equatable`、`Codable` 实现时，注释中应列出所有被排除的属性：

❌ **不完整的注释**：

```swift
/// Represents a tab in the editor.
/// Note: Hashable is implemented manually to only include immutable properties,
/// preventing issues when mutable state (selectionRange, scrollOffset) changes.
struct TabItem: Identifiable, Hashable {
    var selectionRange: Range<String.Index>?
    var scrollOffset: CGFloat = 0
    var hasBeenViewed: Bool = false  // ← 遗漏！
}
```

✅ **完整的注释**：

```swift
/// Represents a tab in the editor.
/// Note: Hashable is implemented manually to only include immutable properties,
/// preventing issues when mutable state (selectionRange, scrollOffset, hasBeenViewed) changes.
struct TabItem: Identifiable, Hashable {
    var selectionRange: Range<String.Index>?
    var scrollOffset: CGFloat = 0
    var hasBeenViewed: Bool = false
}
```

### 属性级注释

对于被排除在协议实现外的属性，应在属性注释中说明：

```swift
struct TabItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    
    /// Selection state for this tab (preserved when switching tabs)
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var selectionRange: Range<String.Index>?

    /// Scroll position (preserved when switching tabs)
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var scrollOffset: CGFloat = 0

    /// Whether this tab has been viewed at least once.
    /// Used to determine scroll behavior: new tabs scroll to top, viewed tabs restore position.
    /// Not included in Hashable to prevent hash invalidation when state changes.
    var hasBeenViewed: Bool = false
}
```

## 未实现功能的注释

### TODO 注释格式

空方法或占位实现应使用明确的 TODO 标记，说明：
1. 当前状态
2. 为什么没有实现
3. 未来实现方向

❌ **模糊的注释**：

```swift
private func loadExpansionState() {
    // TODO: implement later
}
```

✅ **清晰的注释**：

```swift
/// Load expansion state from persistent storage.
/// - Note: Currently not implemented. We can't persist UUID-based expansion across sessions
///   because nodes get new UUIDs when reloaded. A future improvement would be to use
///   path-based expansion tracking instead of UUID-based.
private func loadExpansionState() {
    // TODO: Implement path-based expansion state persistence
}
```

## 保留代码的说明

### 未使用但有意保留的类型

当类型暂时未被使用但有保留价值时，应说明原因：

```swift
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
    var offset: CGFloat = 0
}
```

## 设计决策文档化

### Design Note 格式

对于非直观的设计选择，使用 `## Design Note` 节标记：

```swift
/// Represents a node in the file tree (file or directory).
///
/// ## Design Note on `children` Property
/// The `children` property is `var` to support lazy loading: directories start with
/// `children = []` (empty array) and are populated when expanded. While this theoretically
/// allows changing a file (nil) to a directory (non-nil), this is prevented by:
/// 1. The initializer sets `children` based on file system type at creation
/// 2. Only `updateNodeRecursively` in ViewModel modifies children, and only for existing directories
///
/// Future improvement: Consider using a separate `let isDirectory: Bool` property or an enum
/// to make the file/directory distinction immutable at the type level.
struct FileNode: Identifiable, Hashable {
    // ...
}
```

## 检查清单

在编写文档注释时检查：

- [ ] 自定义协议实现是否列出了所有被排除的属性？
- [ ] 被排除的属性是否有单独的注释说明原因？
- [ ] 空方法是否有清晰的 TODO 和实现说明？
- [ ] 保留但未使用的类型是否说明了保留原因？
- [ ] 非直观的设计是否有 Design Note 说明？
- [ ] 注释是否随代码更新保持同步？

## 维护注释

### 添加新属性时

当添加新的可变属性到有自定义 Hashable 的类型时：

1. 确定是否需要包含在 hash 中
2. 如果不包含，更新类型级注释
3. 添加属性级注释说明原因

### 代码审查时

检查新增或修改的属性是否：
- 被正确记录在类型级注释中
- 有适当的属性级注释
