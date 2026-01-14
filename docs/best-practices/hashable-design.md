# Hashable 设计最佳实践

## 问题背景

当 struct 同时满足以下条件时会出问题：
1. 遵循 `Hashable` 协议
2. 包含可变属性（`var`）
3. 被用作 `Set` 元素或 `Dictionary` 键

Swift 自动合成的 `Hashable` 会包含所有属性，当可变属性改变时，hash 值也会改变，导致在集合中"丢失"该元素。

## 反模式

### ❌ 不推荐

```swift
struct TabItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    
    // 可变属性 - 会参与自动合成的 hash
    var scrollPosition: CGFloat = 0
    var selectionRange: Range<String.Index>?
}

// 使用时的问题
var openTabs: Set<TabItem> = []
var tab = TabItem(id: UUID(), title: "main.swift")
openTabs.insert(tab)

tab.scrollPosition = 100  // hash 值改变！
openTabs.contains(tab)    // 可能返回 false！
```

## 正确做法

### ✅ 推荐：自定义 Hashable 实现

```swift
struct TabItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    
    /// 滚动位置 - 不参与 hash 计算
    var scrollPosition: CGFloat = 0
    
    /// 选择范围 - 不参与 hash 计算
    var selectionRange: Range<String.Index>?
    
    // MARK: - Hashable（只使用不可变属性）
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        // 注意：不包含 scrollPosition 和 selectionRange
    }
    
    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }
}
```

### ✅ 备选方案：分离状态

```swift
// 不可变的标识数据
struct TabIdentifier: Hashable {
    let id: UUID
    let title: String
}

// 可变的状态数据
struct TabState {
    var scrollPosition: CGFloat = 0
    var selectionRange: Range<String.Index>?
}

// 组合使用
class TabManager {
    var states: [TabIdentifier: TabState] = [:]
}
```

## 文档化决策

在自定义 Hashable 实现时，添加注释说明原因：

```swift
/// Tab 项目。
/// 
/// Note: 自定义 Hashable 实现只包含不可变属性（id, title），
/// 可变的 UI 状态（scrollPosition, selectionRange）不参与 hash 计算，
/// 以防止在 Set/Dictionary 中出现一致性问题。
struct TabItem: Identifiable, Hashable {
    // ...
}
```

## 实际案例：FileNode

项目中的 `FileNode` 是一个典型例子：

```swift
/// 文件树节点。
/// Note: Hashable 只包含不可变属性 (id, url)，
/// 可变状态 (children, isGitIgnored, isLoaded) 不参与 hash 计算。
/// 注意：展开状态 (isExpanded) 由 FileTreeViewModel 的 expandedIDs 管理，不在节点本身。
struct FileNode: Identifiable, Hashable {
    let id: UUID
    let url: URL
    
    /// 子节点 - 不参与 hash
    var children: [FileNode]?
    
    /// 是否被 gitignore - 不参与 hash
    var isGitIgnored: Bool = false
    
    /// 是否已加载 - 不参与 hash
    var isLoaded: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }
    
    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
```

## 检查清单

在为 struct 添加 `Hashable` 时，检查：

- [ ] 是否有 `var` 属性？
- [ ] 这些 `var` 属性在生命周期中会改变吗？
- [ ] 该类型会被用作 `Set` 元素或 `Dictionary` 键吗？
- [ ] 该类型会被用于 SwiftUI 的 `ForEach` 或 `List` 吗？

如果以上任一为"是"，请自定义 `hash(into:)` 和 `==` 实现。
