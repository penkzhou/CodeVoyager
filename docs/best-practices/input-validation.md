# Swift 输入验证策略

## 问题

Swift 提供多种输入验证机制，选择不当会导致：
1. 运行时崩溃（生产环境）
2. 静默接受无效数据
3. 错误发现时机过晚

## 验证工具对比

| 机制 | Debug 行为 | Release 行为 | 适用场景 |
|------|-----------|-------------|---------|
| `precondition` | 崩溃 | 崩溃 | 编程错误，必须修复 |
| `assert` | 崩溃 | 忽略 | 开发期检查 |
| `guard` + throw | 抛出错误 | 抛出错误 | 可恢复的业务错误 |
| `guard` + return | 提前返回 | 提前返回 | 可选值/降级处理 |
| `fatalError` | 崩溃 | 崩溃 | 不可能到达的代码路径 |

## 最佳实践

### 1. 使用 `precondition` 验证 API 契约

对于公开 API 的关键参数，使用 `precondition`：

```swift
// ✅ 推荐：id/name 为空是编程错误
public init(id: String, name: String, ...) {
    precondition(!id.trimmingCharacters(in: .whitespaces).isEmpty, 
                 "Theme id cannot be empty")
    precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty, 
                 "Theme name cannot be empty")
    
    self.id = id
    self.name = name
}
```

适用场景：
- 标识符（id、name）不能为空
- 数组索引必须在范围内
- 枚举 rawValue 必须有效
- 协议实现的前置条件

### 2. 使用 `assert` 进行开发期检查

对于仅在开发期需要验证的条件：

```swift
// ✅ 开发期检查内部状态一致性
func processItems(_ items: [Item]) {
    assert(Thread.isMainThread, "Must be called on main thread")
    assert(!isProcessing, "Reentrant call detected")
    // ...
}
```

适用场景：
- 线程检查（有 MainActor 时通常不需要）
- 内部状态一致性
- 性能敏感路径的额外检查

### 3. 使用 `guard` + `throw` 处理业务错误

对于可恢复的错误情况：

```swift
// ✅ 业务错误，调用者需要处理
public func loadConfiguration(for language: SupportedLanguage) throws -> Config {
    guard let config = cache[language] else {
        throw ConfigurationError.notFound(language)
    }
    return config
}
```

适用场景：
- 文件不存在
- 网络请求失败
- 数据解析错误
- 权限不足

### 4. 使用 `guard` + `return` 进行降级处理

对于可选操作或降级场景：

```swift
// ✅ 降级处理，返回默认值
func style(for captureName: String) -> TokenStyle {
    guard let style = tokenStyles[captureName] else {
        // 未找到，返回默认样式（降级）
        return defaultStyle
    }
    return style
}

// ✅ 可选操作，静默跳过
func updateScrollOffset(for tabId: UUID, offset: CGFloat) {
    guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
        return  // Tab 不存在，静默返回
    }
    tabs[index].scrollOffset = offset
}
```

### 5. 使用 `fatalError` 标记不可能路径

```swift
// ✅ 逻辑上不可能到达
switch enumValue {
case .a: return handleA()
case .b: return handleB()
@unknown default:
    fatalError("Unknown enum case: \(enumValue)")
}
```

## 决策流程图

```
输入无效时应该怎么办？
│
├─ 是编程错误吗？（调用者的 bug）
│   ├─ 是 → 使用 precondition
│   └─ 否 ↓
│
├─ 调用者需要知道失败吗？
│   ├─ 是 → 使用 guard + throw
│   └─ 否 ↓
│
├─ 有合理的默认值/降级行为吗？
│   ├─ 是 → 使用 guard + return（记录日志）
│   └─ 否 → 重新考虑 API 设计
```

## 常见模式

### 标识符验证

```swift
public struct Entity: Identifiable {
    public let id: String
    
    public init(id: String) {
        precondition(!id.isEmpty, "Entity id cannot be empty")
        self.id = id
    }
}
```

### 范围验证

```swift
public func setProgress(_ value: Double) {
    precondition(value >= 0 && value <= 1, 
                 "Progress must be between 0 and 1, got \(value)")
    self.progress = value
}
```

### 集合非空验证

```swift
public init(themes: [Theme]) {
    precondition(!themes.isEmpty, "At least one theme is required")
    self.themes = themes
}
```

## 相关文档

- [error-handling.md](error-handling.md) - 错误处理
- [error-logging-patterns.md](error-logging-patterns.md) - 错误日志模式
