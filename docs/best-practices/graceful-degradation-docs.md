# API 降级行为文档规范

## 问题

当 API 支持优雅降级时，如果文档不清晰会导致：
1. 使用者不知道某个功能可能不可用
2. 无法正确处理降级后的状态
3. 调试时难以定位问题根源

## 最佳实践

### 1. 在类型级别文档中说明降级行为

在结构体/类的顶层文档中明确列出所有降级场景：

```swift
// ❌ 降级行为分散在各方法中，难以发现
/// 语法语言配置
///
/// 封装 Tree-sitter 的 Language 和相关的高亮 Query。
public struct SyntaxLanguageConfiguration { ... }

// ✅ 在顶层文档中集中说明
/// 语法语言配置
///
/// 封装 Tree-sitter 的 Language 和相关的高亮 Query。
///
/// ## 降级行为
/// 当高亮 Query 加载失败时（如 .scm 文件缺失或格式错误），配置仍可成功创建，
/// 但 `highlightsQuery` 为 nil。此时语法高亮将不可用，代码仅显示默认文本样式，
/// 但代码编辑/浏览功能正常。具体降级场景：
/// - Query 文件不存在：`highlightsQuery = nil`，无语法高亮
/// - Query 语法错误：`highlightsQuery = nil`，无语法高亮
/// - Language 初始化失败：此情况不会降级，直接抛出错误
public struct SyntaxLanguageConfiguration { ... }
```

### 2. 说明降级检测方法

文档应该告诉使用者如何检测是否发生了降级：

```swift
/// ## 使用示例
/// ```swift
/// let config = try SyntaxLanguageConfiguration.create(for: .swift)
///
/// // 检查是否支持语法高亮
/// if let query = config.highlightsQuery {
///     // 正常路径：应用语法高亮
///     highlighter.apply(query: query)
/// } else {
///     // 降级路径：显示无高亮的纯文本
///     logger.info("Syntax highlighting unavailable for \(config.language)")
/// }
/// ```
```

### 3. 区分降级级别

明确不同级别的降级及其影响：

```swift
/// ## 降级行为
///
/// ### 完全降级（功能不可用）
/// - `highlightsQuery = nil`：语法高亮完全禁用
/// - 影响：代码显示为纯文本，无颜色区分
///
/// ### 部分降级（功能受限）
/// - 某些 capture name 未定义：使用 defaultStyle
/// - 影响：部分 token 显示为默认颜色
///
/// ### 不降级（直接失败）
/// - Language 初始化失败：抛出 `LanguageConfigurationError`
/// - 影响：必须处理错误，无法继续
```

### 4. 在方法文档中使用 Note 标注

对于会发生降级的方法，使用 `- Note:` 标注：

```swift
/// 加载高亮 Query
///
/// - Parameter language: 目标语言
/// - Returns: Query 对象，加载失败时返回 nil
///
/// - Note: 如果加载失败，返回 nil 并记录警告日志。
///   语法高亮将降级为无高亮模式，但不影响其他功能。
private static func loadHighlightsQuery(for language: SupportedLanguage) -> Query?
```

### 5. 记录降级日志

降级发生时应该记录日志，帮助调试：

```swift
// ✅ 记录降级信息
private static func loadHighlightsQuery(for language: SupportedLanguage) -> Query? {
    guard let url = getQueryURL(for: language) else {
        logger.warning("Query URL not found for \(language.displayName). " +
                      "Syntax highlighting will be disabled for this language.")
        return nil
    }
    
    do {
        return try language.query(contentsOf: url)
    } catch {
        logger.warning("Failed to load query for \(language.displayName): " +
                      "\(error.localizedDescription). " +
                      "Syntax highlighting will be disabled for this language.")
        return nil
    }
}
```

## 文档模板

```swift
/// [类型名称]
///
/// [功能描述]
///
/// ## 降级行为
/// [说明什么情况下会降级]
///
/// | 场景 | 行为 | 检测方式 |
/// |------|------|---------|
/// | [场景1] | [行为1] | [如何检测] |
/// | [场景2] | [行为2] | [如何检测] |
///
/// ## 使用示例
/// ```swift
/// // 正常使用
/// let result = try api.doSomething()
///
/// // 检查降级
/// if result.isFullyFunctional {
///     // 正常路径
/// } else {
///     // 降级路径
/// }
/// ```
```

## 检查清单

编写支持降级的 API 文档时：

- [ ] 在类型顶层文档中列出所有降级场景
- [ ] 说明每种降级的触发条件
- [ ] 说明降级后的系统行为
- [ ] 提供检测降级状态的方法
- [ ] 区分哪些错误会降级、哪些会直接失败
- [ ] 在代码中添加降级日志

## 相关文档

- [error-handling.md](error-handling.md) - 错误处理
- [error-logging-patterns.md](error-logging-patterns.md) - 错误日志模式
- [documentation-comments.md](documentation-comments.md) - 文档注释规范
