# Swift/SwiftUI 最佳实践

本目录包含 CodeVoyager 项目的编码最佳实践指南。

## 目录

| 文件 | 主题 | 描述 |
|------|------|------|
| [error-handling.md](error-handling.md) | 错误处理 | 避免静默失败，提供用户友好的错误消息 |
| [error-logging-patterns.md](error-logging-patterns.md) | 错误日志模式 | 降级行为日志、回退策略记录、日志级别选择 |
| [graceful-degradation-docs.md](graceful-degradation-docs.md) | 降级行为文档 | API 降级场景说明、检测方法、文档模板 |
| [hashable-design.md](hashable-design.md) | Hashable 设计 | 可变属性与 Hashable 协议的正确实现 |
| [input-validation.md](input-validation.md) | 输入验证 | precondition vs assert vs guard 的选择策略 |
| [view-viewmodel-consistency.md](view-viewmodel-consistency.md) | View/ViewModel 一致性 | 保持 View 与 ViewModel 逻辑同步 |
| [thread-safety.md](thread-safety.md) | 线程安全 | MainActor 与 AppKit 集成 |
| [naming-conventions.md](naming-conventions.md) | 命名规范 | 避免与系统类型冲突 |
| [testing-guidelines.md](testing-guidelines.md) | 测试指南 | 确保充分的测试覆盖 |
| [protocol-mock-examples.md](protocol-mock-examples.md) | Mock 示例规范 | 协议文档中 Mock 示例的完整性要求 |
| [string-handling.md](string-handling.md) | 字符串处理 | 行数计算、前缀提取等边界情况 |
| [c-api-memory-safety.md](c-api-memory-safety.md) | C API 内存安全 | Unmanaged、FSEvents 回调的正确模式 |
| [code-deduplication.md](code-deduplication.md) | 代码重复消除 | 工具函数提取、UI状态分离、View复用ViewModel方法 |
| [code-simplification.md](code-simplification.md) | 代码简化 | switch-case 简化、nil 合并、静态 Logger |
| [documentation-comments.md](documentation-comments.md) | 文档注释 | 协议实现说明、Design Note、TODO格式 |
| [type-design.md](type-design.md) | 类型设计 | 可变性语义、延迟加载状态、ID设计策略 |
| [swiftpm-resources.md](swiftpm-resources.md) | SwiftPM 资源管理 | Bundle 命名、SF Symbol 验证、@MainActor 测试 |

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

### 日志记录
```swift
// ❌ 空 catch 块
} catch {
    return nil
}

// ✅ 记录错误和降级行为
} catch {
    // 降级行为：返回 nil，语法高亮将不可用
    logger.warning("Failed to load query: \(error.localizedDescription). Syntax highlighting disabled.")
    return nil
}

// ✅ 回退策略用 debug 级别
logger.debug("Bundle '\(name)' not found, falling back to main bundle")
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

### 输入验证
```swift
// ❌ 无验证，接受空字符串
public init(id: String, name: String) {
    self.id = id
    self.name = name
}

// ✅ 使用 precondition 验证 API 契约
public init(id: String, name: String) {
    precondition(!id.trimmingCharacters(in: .whitespaces).isEmpty, 
                 "Theme id cannot be empty")
    precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty, 
                 "Theme name cannot be empty")
    self.id = id
    self.name = name
}
```

### Mock 示例
```swift
// ❌ 不完整的 Mock 示例
/// class MockRegistry: RegistryProtocol {
///     func get(for id: String) -> Item? { ... }
///     // ... 其他方法实现  ← 模糊！
/// }

// ✅ 完整展示所有必需方法
/// class MockRegistry: RegistryProtocol {
///     var itemToReturn: Item?
///     func get(for id: String) -> Item? { itemToReturn }
///     func getAll() -> [Item] { itemToReturn.map { [$0] } ?? [] }
///     // 以下方法有默认实现，可选覆盖：
///     // - count, isEmpty
/// }
```

### 降级行为文档
```swift
// ❌ 降级行为只在方法内部注释
func loadQuery() -> Query? {
    // 加载失败返回 nil，语法高亮将不可用
}

// ✅ 在类型顶层文档中说明
/// ## 降级行为
/// 当 Query 加载失败时，`highlightsQuery` 为 nil，
/// 语法高亮不可用，但代码浏览功能正常。
/// 
/// | 场景 | 行为 | 检测方式 |
/// |------|------|---------|
/// | Query 文件缺失 | highlightsQuery = nil | 检查属性是否为 nil |
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

### 代码简化
```swift
// ❌ 冗余的 switch-case（与 rawValue 相同）
var identifier: String {
    switch self {
    case .swift: return "swift"
    case .python: return "python"
    }
}

// ✅ 直接返回 rawValue
var identifier: String { rawValue }

// ❌ 冗余的 if-let
if let style = styles[key] { return style }
return defaultStyle

// ✅ nil 合并运算符
styles[key] ?? defaultStyle

// ❌ 每次调用创建 Logger
func process() {
    let logger = Logger(...)  // 热路径中重复创建
}

// ✅ 静态 Logger
private static let logger = Logger(...)
```
