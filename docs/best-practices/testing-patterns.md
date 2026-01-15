# 测试最佳实践

## 测试专用 API 的可见性控制

测试专用方法应使用 `#if DEBUG` 包装，防止在生产代码中被误用：

```swift
// ✅ 好的做法：使用 #if DEBUG 限制可见性
#if DEBUG
public extension SomeManager {
    /// 重置为默认状态
    ///
    /// - Warning: 仅用于测试场景，此方法仅在 DEBUG 构建中可用。
    ///   生产代码不应依赖此方法。
    func reset() {
        // 重置逻辑
    }
}
#endif

// ❌ 避免：public 方法仅靠文档说明
public extension SomeManager {
    /// 重置为默认状态
    ///
    /// 仅用于测试场景  // <- 文档说明不能阻止生产代码调用
    func reset() {
        // 重置逻辑
    }
}
```

## 测试环境的特殊处理

### 系统对象可能为 nil

在测试环境中，`NSApp` 等全局对象可能不可用：

```swift
// ✅ 好的做法：处理 nil 情况
private static func themeForCurrentSystemAppearance() -> SyntaxTheme {
    guard let app = NSApp else {
        // 测试环境或 App 未初始化时，返回默认值
        return DefaultThemes.light
    }
    // 正常逻辑
}
```

### 测试系统外观

使用 `NSAppearance(named:)` 创建测试用外观对象：

```swift
@Test("dark matches darkAqua appearance")
func darkMatchesDarkAqua() {
    let darkAppearance = NSAppearance(named: .darkAqua)
    #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: darkAppearance) == true)
}
```

## 难以测试的场景

### 1. precondition / fatalError

`precondition` 失败会导致程序崩溃，在 Swift Testing 框架中难以测试。

**替代方案**：

```swift
// 方案 1：使用可失败初始化器
public init?(id: String, name: String, ...) {
    guard !id.isEmpty, !name.isEmpty else { return nil }
    // ...
}

// 方案 2：使用抛出错误的工厂方法
public static func create(id: String, name: String, ...) throws -> SyntaxTheme {
    guard !id.isEmpty else { throw ThemeError.emptyId }
    // ...
}
```

### 2. 字体 traits 不可用

某些字体可能不支持 bold/italic traits：

```swift
@Test("Font falls back to base font when traits unavailable")
func fontFallsBackWhenTraitsUnavailable() {
    let baseFont = NSFont.systemFont(ofSize: 14)
    let style = TokenStyle.boldItalic(.black)
    
    let resultFont = style.font(from: baseFont)
    
    // 验证不崩溃且返回有效字体
    #expect(resultFont.pointSize == baseFont.pointSize)
}
```

### 3. 单例状态污染

使用 `reset()` 方法在测试间清理状态：

```swift
@Suite("ThemeManager Tests")
@MainActor
struct ThemeManagerTests {
    
    private func createTestManager() -> ThemeManager {
        let manager = ThemeManager()
        manager.reset()  // 确保初始状态
        return manager
    }
    
    @Test("setTheme changes currentTheme")
    func setThemeChangesCurrentTheme() async {
        let manager = createTestManager()
        // 测试逻辑
    }
}
```

## 测试 Suite 标记

### @MainActor 标记

当被测代码是 `@MainActor` 时，测试 Suite 也需要标记：

```swift
// ✅ 好的做法
@Suite("ThemeManager Tests")
@MainActor  // 因为 ThemeManager 是 @MainActor
struct ThemeManagerTests {
    // ...
}
```

## 测试覆盖检查清单

对于每个公开类型，确保测试覆盖：

- [ ] 所有公开方法的正常路径
- [ ] 错误路径和边界情况
- [ ] 降级行为（如回退到默认值）
- [ ] Equatable/Hashable 实现（如果有自定义）
- [ ] 异步方法的并发安全性
- [ ] 可变状态的正确清理
