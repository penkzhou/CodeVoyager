# 文档注释最佳实践

## 副作用的完整说明

当方法有多个副作用时，必须在文档中完整列出：

```swift
// ✅ 好的做法：完整说明所有副作用
/// 清除配置缓存
///
/// 同时清除已缓存的配置和失败语言记录。调用后，之前因加载失败而被记录的语言
/// 将可以重新尝试加载。
///
/// - Note: 主要用于测试场景
public func clearCache() {
    configurationCache.removeAll()
    failedLanguages.removeAll()  // 这个副作用在文档中说明了
}

// ❌ 避免：只说明主要功能
/// 清除配置缓存
///
/// 主要用于测试场景
public func clearCache() {
    configurationCache.removeAll()
    failedLanguages.removeAll()  // 调用者不知道这也被清除了
}
```

## Equatable 实现的警告

当 `Equatable` 实现只比较部分属性时，必须添加详细警告：

```swift
// ✅ 好的做法：详细说明比较策略及其影响
// MARK: - Equatable

/// 比较两个主题是否相等
///
/// - Warning: 此实现**仅比较 id**，不比较主题的实际内容（颜色、样式等）。
///   这意味着两个具有相同 id 但不同内容的主题会被认为相等。
///   这是有意为之的设计决策，原因如下：
///   1. NSColor 的比较在不同颜色空间下可能不准确
///   2. 字典（tokenStyles）的完整比较开销较大
///   3. 主题 id 应保证唯一性，相同 id 的主题应该是同一主题
///
/// - Important: 如果需要检测主题内容是否变化，请比较具体的属性或实现自定义比较逻辑。
public static func == (lhs: SyntaxTheme, rhs: SyntaxTheme) -> Bool {
    lhs.id == rhs.id
}

// ❌ 避免：简单注释
public static func == (lhs: SyntaxTheme, rhs: SyntaxTheme) -> Bool {
    // 只比较 id
    lhs.id == rhs.id
}
```

## 手动维护集合的更新提醒

当集合需要手动维护（添加新元素时需同步更新）时：

```swift
// ✅ 好的做法：明确提醒需要更新
/// 所有内置主题
///
/// - Important: 新增内置主题时，必须将其添加到此数组中！
///   此数组被 `ThemeManager.availableThemes` 和 `theme(withId:)` 使用，
///   遗漏添加会导致新主题无法被用户选择。
public static let all: [SyntaxTheme] = [light, dark]

// ❌ 避免：无提醒
/// 所有内置主题
public static let all: [SyntaxTheme] = [light, dark]
```

## 降级行为说明

当方法在某些情况下会降级处理时：

```swift
// ✅ 好的做法：说明降级行为
/// 生成应用了样式的字体
/// - Parameter baseFont: 基础字体
/// - Returns: 应用粗体/斜体后的字体
///
/// - Note: 如果字体创建失败（例如字体不支持请求的 traits），
///   将静默回退到基础字体并记录警告日志
public func font(from baseFont: NSFont) -> NSFont {
    // 实现...
}

// ❌ 避免：隐藏降级行为
/// 生成应用了样式的字体
public func font(from baseFont: NSFont) -> NSFont {
    // 实现...
}
```

## 工厂方法 vs 直接初始化

当类型同时提供工厂方法和初始化器时：

```swift
// ✅ 好的做法：说明何时使用哪种方式
/// 内部初始化器
///
/// 使用 `create(for:)` 或 `create(forExtension:)` 工厂方法创建实例。
/// 直接初始化仅用于内部实现和测试。
internal init(
    language: SupportedLanguage,
    tsLanguage: Language,
    highlightsQuery: SwiftTreeSitter.Query?
) {
    // 实现...
}

/// 为指定语言创建配置
///
/// - Parameter language: 目标语言
/// - Returns: 语言配置
/// - Throws: 配置加载失败时抛出 LanguageConfigurationError
///
/// - Note: 这是创建配置的推荐方式，它会自动加载对应的 Tree-sitter 语言和高亮查询
public static func create(for language: SupportedLanguage) throws -> SyntaxLanguageConfiguration {
    // 实现...
}
```

## 文档注释检查清单

编写文档时确保包含：

- [ ] 方法的主要功能描述
- [ ] 所有参数的说明
- [ ] 返回值说明
- [ ] 可能抛出的错误
- [ ] 副作用（修改的其他状态）
- [ ] 降级行为
- [ ] 线程安全性要求
- [ ] 使用示例（复杂 API）
- [ ] 相关方法的交叉引用
