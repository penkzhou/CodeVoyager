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
