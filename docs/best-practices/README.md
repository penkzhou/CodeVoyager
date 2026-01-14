# Swift/SwiftUI 最佳实践

本目录包含 CodeVoyager 项目的编码最佳实践指南。

## 目录

| 文件 | 主题 | 描述 |
|------|------|------|
| [error-handling.md](error-handling.md) | 错误处理 | 避免静默失败，提供用户友好的错误消息 |
| [hashable-design.md](hashable-design.md) | Hashable 设计 | 可变属性与 Hashable 协议的正确实现 |
| [view-viewmodel-consistency.md](view-viewmodel-consistency.md) | View/ViewModel 一致性 | 保持 View 与 ViewModel 逻辑同步 |
| [thread-safety.md](thread-safety.md) | 线程安全 | MainActor 与 AppKit 集成 |
| [naming-conventions.md](naming-conventions.md) | 命名规范 | 避免与系统类型冲突 |
| [testing-guidelines.md](testing-guidelines.md) | 测试指南 | 确保充分的测试覆盖 |
| [string-handling.md](string-handling.md) | 字符串处理 | 行数计算、前缀提取等边界情况 |
| [c-api-memory-safety.md](c-api-memory-safety.md) | C API 内存安全 | Unmanaged、FSEvents 回调的正确模式 |
| [code-deduplication.md](code-deduplication.md) | 代码重复消除 | 工具函数提取、UI状态分离、View复用ViewModel方法 |
| [documentation-comments.md](documentation-comments.md) | 文档注释 | 协议实现说明、Design Note、TODO格式 |
| [type-design.md](type-design.md) | 类型设计 | 可变性语义、延迟加载状态、ID设计策略 |

## 快速参考

### 错误处理
```swift
// ❌ 禁止
let data = try? decoder.decode(...)

// ✅ 推荐
do {
    let data = try decoder.decode(...)
} catch {
    logger.error("Decode failed: \(error)")
}
```

### 主线程安全
```swift
// 使用 AppKit 组件的类
@MainActor
@Observable
final class AppState { ... }
```

### Hashable
```swift
// 包含可变属性时，自定义实现
func hash(into hasher: inout Hasher) {
    hasher.combine(id)  // 只用不可变属性
}
```

### 代码复用
```swift
// ❌ 重复定义
struct ViewA { func formatSize(...) { ... } }
struct ViewB { func formatSize(...) { ... } }

// ✅ 提取到共享模块
enum FormatUtilities {
    static func formatFileSize(_ bytes: Int64) -> String { ... }
}

// ❌ View 重复实现 ViewModel 已有方法
struct FileTreeView {
    private func findNodeRecursively(...) { ... }  // 重复！
}

// ✅ View 复用 ViewModel 方法
private func findNode(by id: UUID?) -> FileNode? {
    return viewModel.findNode(by: id)
}
```

### UI 状态分离
```swift
// ❌ UI状态存储在实体中
struct FileNode { var isExpanded: Bool }

// ✅ ViewModel 管理，实体通过参数获取
func iconName(isExpanded: Bool) -> String
```

### 文档注释
```swift
// ❌ 不完整的协议实现注释
/// Note: mutable state (scrollOffset) excluded from Hashable
var hasBeenViewed: Bool  // ← 遗漏！

// ✅ 完整列出所有被排除属性
/// Note: mutable state (scrollOffset, selectionRange, hasBeenViewed) excluded
```

### 类型设计
```swift
// ❌ var 属性改变语义，无文档说明
var children: [FileNode]?  // nil=文件？未加载？

// ✅ 文档化设计决策
/// - `nil`: This is a file
/// - `[]`: This is a directory (may be empty or not yet loaded)
/// ## Design Note: var 用于支持延迟加载...
var children: [FileNode]?
```
