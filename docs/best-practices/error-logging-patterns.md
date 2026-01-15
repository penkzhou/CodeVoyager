# 错误日志记录模式

本文档描述项目中错误日志记录的最佳实践，确保错误可追踪且降级行为清晰。

## 核心原则

1. **无静默失败**：所有错误必须被记录，即使选择优雅降级
2. **上下文丰富**：日志包含足够信息定位问题
3. **降级透明**：明确说明采取了什么替代策略

## 1. 可恢复错误的日志记录

当错误可以通过降级处理时，使用 `warning` 级别记录。

```swift
// ❌ 不好：静默吞掉错误
func loadQuery() -> Query? {
    guard let url = getQueryURL() else { return nil }
    return try? language.query(contentsOf: url)
}

// ✅ 好：记录错误并说明降级行为
func loadQuery() -> Query? {
    guard let url = getQueryURL() else {
        logger.warning("Query URL not found for \(language.displayName). Syntax highlighting will be disabled.")
        return nil
    }
    
    do {
        return try language.query(contentsOf: url)
    } catch {
        // 降级行为：返回 nil，功能正常但无高亮
        logger.warning("Failed to load query for \(language.displayName): \(error.localizedDescription). Syntax highlighting will be disabled.")
        return nil
    }
}
```

## 2. 回退策略的日志记录

当存在多个查找路径或策略时，使用 `debug` 级别记录回退。

```swift
// ✅ 记录回退行为（debug 级别）
guard let primaryBundle = Bundle.main.url(forResource: name, withExtension: "bundle"),
      let bundle = Bundle(url: primaryBundle) else {
    logger.debug("Bundle '\(name)' not found, falling back to main bundle for \(context)")
    return Bundle.main.url(forResource: filename, withExtension: "scm")
}
```

## 3. 包装 Optional 返回的方法

当调用返回 Optional 但底层已记录日志的方法时，添加上下文日志。

```swift
// ❌ 不好：重复底层日志内容
public func configuration(forExtension ext: String) -> Config? {
    guard let language = detect(from: ext) else { return nil }
    return try? configuration(for: language)  // 底层有日志，但本层无上下文
}

// ✅ 好：添加本层上下文（使用 debug 避免重复 warning）
public func configuration(forExtension ext: String) -> Config? {
    guard let language = detect(from: ext) else { return nil }
    do {
        return try configuration(for: language)
    } catch {
        // 错误已在 configuration(for:) 中记录，这里只记录调用上下文
        logger.debug("Configuration unavailable for extension '\(ext)' (language: \(language.displayName))")
        return nil
    }
}
```

## 4. 日志级别选择指南

| 级别 | 使用场景 | 示例 |
|------|----------|------|
| `error` | 不可恢复的错误，影响核心功能 | 数据库无法打开、关键配置缺失 |
| `warning` | 可恢复的错误，功能降级 | 高亮查询加载失败（降级为无高亮） |
| `info` | 重要的正常事件 | 配置加载完成、缓存清理 |
| `debug` | 调试信息、回退路径 | Bundle 查找回退、缓存命中/未命中 |

## 5. 日志消息格式

### 标准格式

```
"Failed to [动作] for [上下文]: [错误描述]. [降级行为说明]"
```

### 示例

```swift
// 包含完整信息
logger.warning("Failed to load highlights query for \(language.displayName): \(error.localizedDescription). Syntax highlighting will be disabled for this language.")

// 回退场景
logger.debug("Resource bundle '\(bundleName)' not found, falling back to main bundle for \(language.displayName)")

// 操作成功
logger.info("Preload complete: \(loadedCount) loaded, \(failedCount) failed")
```

## 6. 注释说明降级行为

在 catch 块中添加注释说明降级策略：

```swift
do {
    return try riskyOperation()
} catch {
    // 降级行为：返回 nil，语法高亮将不可用，但代码编辑功能正常
    logger.warning("...")
    return nil
}
```

## 7. 方法文档中说明降级

在方法的文档注释中说明可能的降级行为：

```swift
/// 加载高亮 Query
///
/// - Note: 如果加载失败，返回 nil 并记录警告日志。语法高亮将降级为无高亮模式。
private static func loadHighlightsQuery(for language: SupportedLanguage) -> Query? {
    // ...
}
```

## 相关文档

- [错误处理](error-handling.md) - 错误类型设计和传播策略
- [线程安全](thread-safety.md) - 并发场景下的日志记录注意事项
