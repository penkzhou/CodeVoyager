# 协议 Mock 示例规范

## 问题

协议文档中的 Mock 示例不完整，导致：
1. 测试编写者不知道需要实现哪些方法
2. 复制示例代码后编译失败
3. 遗漏关键方法的实现

## 最佳实践

### 1. 展示所有必需方法

Mock 示例必须包含所有没有默认实现的方法：

```swift
// ❌ 不完整的示例
/// ## 测试 Mock 示例
/// ```swift
/// class MockRegistry: LanguageRegistryProtocol {
///     func configuration(for language: SupportedLanguage) throws -> Config {
///         // ...
///     }
///     // ... 其他方法实现  ← 模糊！
/// }
/// ```

// ✅ 完整的示例
/// ## 测试 Mock 示例
/// ```swift
/// class MockRegistry: LanguageRegistryProtocol {
///     var configurationToReturn: Config?
///     var configurationForExtension: [String: Config] = [:]
///
///     func configuration(for language: SupportedLanguage) throws -> Config {
///         guard let config = configurationToReturn else {
///             throw ConfigError.failed(language)
///         }
///         return config
///     }
///
///     func configuration(forExtension ext: String) -> Config? {
///         configurationForExtension[ext]
///     }
///
///     // 以下方法有默认实现，可根据测试需要覆盖：
///     // - configuration(forFile:)
///     // - detectLanguage(for:)
///     // - isSupported(fileExtension:)
/// }
/// ```
```

### 2. 明确标注默认实现

在 Mock 示例中注明哪些方法有默认实现：

```swift
/// ## 测试 Mock 示例
/// ```swift
/// class MockThemeManager: ThemeManagerProtocol {
///     // === 必须实现的属性 ===
///     var currentTheme: SyntaxTheme = DefaultThemes.light
///     var preference: ThemePreference = .followSystem
///     var availableThemes: [SyntaxTheme] = DefaultThemes.all
///
///     // === 必须实现的方法 ===
///     func setTheme(_ theme: SyntaxTheme) { ... }
///     func setTheme(withId themeId: String) -> Bool { ... }
///     func setFollowSystem() { ... }
///     func updateForSystemAppearance() { ... }
///
///     // === 有默认实现，可选覆盖 ===
///     // （无）
/// }
/// ```
```

### 3. 提供可测试的 Stub 值

Mock 应该提供可配置的返回值：

```swift
// ❌ 硬编码返回值
class MockService: ServiceProtocol {
    func fetchData() -> Data {
        return Data()  // 无法测试不同场景
    }
}

// ✅ 可配置的 Stub
class MockService: ServiceProtocol {
    var dataToReturn: Data = Data()
    var errorToThrow: Error?
    
    func fetchData() throws -> Data {
        if let error = errorToThrow {
            throw error
        }
        return dataToReturn
    }
}
```

### 4. 处理 Sendable 要求

如果协议要求 `Sendable`，Mock 需要正确处理：

```swift
// ✅ 使用 @unchecked Sendable（仅用于测试）
final class MockThemeManager: ThemeManagerProtocol, @unchecked Sendable {
    // 测试环境中可以接受 @unchecked
    var currentTheme: SyntaxTheme = DefaultThemes.light
    // ...
}
```

## 检查清单

编写协议 Mock 示例时：

- [ ] 列出所有没有默认实现的属性
- [ ] 列出所有没有默认实现的方法
- [ ] 提供完整的方法实现（不是 `// ...`）
- [ ] 注明哪些方法有默认实现可选覆盖
- [ ] 提供可配置的 Stub 属性
- [ ] 处理 Sendable/MainActor 等并发要求

## 相关文档

- [testing-guidelines.md](testing-guidelines.md) - 测试指南
- [documentation-comments.md](documentation-comments.md) - 文档注释规范
