# 类型设计最佳实践

本文档描述如何设计类型以保证类型安全、可维护性，以及如何文档化设计决策。

## 可变性与语义一致性

### 问题：var 属性改变类型语义

当可变属性影响类型的核心语义时，需要特别注意：

❌ **潜在问题**：

```swift
struct FileNode {
    let url: URL
    
    /// children 为 nil 表示文件，非 nil 表示目录
    var children: [FileNode]?
    
    var isDirectory: Bool {
        children != nil  // 语义由可变属性决定
    }
}

// 问题：理论上可以把文件变成目录
var file = FileNode(url: fileURL, children: nil)
file.children = []  // 现在它变成了"目录"！
```

### 解决方案

#### 方案 1：文档化约束（当前方案）

当重构成本较高时，通过文档明确约束：

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
    let id: UUID
    let url: URL

    /// Children nodes (nil for files, empty array for empty/unloaded directories)
    /// - `nil`: This is a file
    /// - `[]` (empty array): This is a directory (may be empty or not yet loaded)
    /// - Non-empty array: This is a directory with loaded children
    var children: [FileNode]?
}
```

#### 方案 2：分离不可变标识（推荐重构方向）

```swift
struct FileNode: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let isDirectory: Bool  // ← 不可变，在初始化时确定
    
    /// 只有目录才有 children，文件此属性无意义
    var children: [FileNode]? {
        didSet {
            assert(isDirectory, "Cannot set children on a file node")
        }
    }
}
```

#### 方案 3：使用枚举区分（类型安全最佳）

```swift
enum FileNodeType {
    case file
    case directory(children: [FileNode], isLoaded: Bool)
}

struct FileNode: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let type: FileNodeType  // 编译时保证文件不会变成目录
    
    var isDirectory: Bool {
        if case .directory = type { return true }
        return false
    }
}
```

## 延迟加载状态设计

### 问题：如何表示"未加载"状态

❌ **混淆的设计**：

```swift
struct Directory {
    var children: [FileNode]?  // nil = 未加载？还是没有子项？
}
```

✅ **清晰的设计**：

```swift
// 方案 A：分离状态标志
struct FileNode {
    var children: [FileNode]?  // nil = 文件，[] = 目录
    var isLoaded: Bool = false  // 明确表示是否已加载
}

// 方案 B：使用枚举
enum LoadState<T> {
    case notLoaded
    case loading
    case loaded(T)
    case failed(Error)
}

struct Directory {
    var childrenState: LoadState<[FileNode]> = .notLoaded
}
```

## ID 设计：UUID vs 路径

### 场景分析

| 场景 | UUID | 路径 |
|------|------|------|
| 内存中唯一标识 | ✅ 推荐 | ⚠️ 可能重复 |
| 跨会话持久化 | ❌ 每次不同 | ✅ 稳定 |
| 文件重命名后 | ✅ 保持不变 | ❌ 失效 |
| 外部文件变化后 | ⚠️ 需要刷新 | ✅ 自动关联 |

### 混合方案（推荐）

```swift
struct FileNode {
    let id: UUID           // 内存中唯一标识，用于 SwiftUI
    let url: URL           // 文件系统路径，用于持久化
    let relativePath: String  // 相对于仓库根的路径，用于跨会话状态
}

// ViewModel 中使用路径追踪展开状态
class FileTreeViewModel {
    // 内存中使用 UUID（性能好）
    private(set) var expandedIDs: Set<UUID> = []
    
    // 持久化使用路径（跨会话稳定）
    private var expandedPaths: Set<String> = []
    
    func saveExpansionState() {
        // 将 UUID 转换为路径后存储
    }
    
    func loadExpansionState() {
        // 加载路径后，在树构建时转换为 UUID
    }
}
```

## 检查清单

设计新类型时检查：

- [ ] 可变属性是否会改变类型的核心语义？
- [ ] 如果是，是否有文档说明约束？
- [ ] 延迟加载状态是否清晰？
- [ ] ID 设计是否满足持久化需求？
- [ ] 是否有更类型安全的替代设计？
- [ ] 是否记录了"为什么这样设计"而不仅是"是什么"？

## 重构时机

当以下情况发生时，考虑重构：

1. **语义违规频繁发生** - 说明文档约束不够
2. **新功能需要区分状态** - 如区分"未加载目录"和"空目录"
3. **Bug 源于状态混淆** - 如误将文件当目录处理
4. **测试难以覆盖边界** - 类型系统能帮助排除无效状态
