# SwiftPM 资源管理最佳实践

## Bundle 命名规范

### 问题场景

使用 SwiftPM 管理的第三方包时，资源 Bundle 的命名可能与预期不同。

### ❌ 错误示例

```swift
// 假设包名为 TreeSitterLanguages，target 名为 TreeSitterSwiftQueries
// 错误地假设 bundle 名为 target 名
let bundleName = "TreeSitterSwift_TreeSitterSwiftQueries"  // ❌ 不存在

guard let resourceBundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle") else {
    // 总是 nil，因为 bundle 名不对
    return nil
}
```

### ✅ 正确示例

```swift
// SwiftPM 生成的 bundle 名格式：<PackageName>_<TargetName>
let bundleName = "TreeSitterLanguages_TreeSitterSwiftQueries"  // ✅ 正确

guard let resourceBundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle") else {
    logger.warning("Resource bundle '\(bundleName)' not found")
    return nil
}
```

### 验证方法

构建项目后，检查 `.build/` 目录中生成的 bundle 文件：

```bash
find .build -name "*.bundle" -type d
```

输出示例：
```
.build/debug/TreeSitterLanguages_TreeSitterSwiftQueries.bundle
.build/debug/TreeSitterLanguages_TreeSitterJavaScriptQueries.bundle
```

---

## SF Symbol 验证

### 问题场景

使用不存在的 SF Symbol 名称会导致图标无法显示。

### ❌ 错误示例

```swift
// 这些不是官方 SF Symbol
case .javascript: return "js.circle"    // ❌ 不存在
case .python: return "p.circle"         // ❌ 不存在
```

### ✅ 正确示例

```swift
// 使用官方支持的 SF Symbol
case .javascript: return "j.square"                              // ✅ 有效
case .python: return "chevron.left.forwardslash.chevron.right"   // ✅ 有效
```

### 验证方法

1. 使用 SF Symbols App（Apple 官方工具）验证图标名称
2. 参考官方文档：https://developer.apple.com/sf-symbols/
3. 在代码注释中标明目标 macOS 版本

---

## @MainActor 与测试环境

### 问题场景

使用 `NSApp` 等 AppKit 全局对象时，测试环境中可能为 nil。

### ❌ 错误示例

```swift
@MainActor
private static func themeForCurrentSystemAppearance() -> SyntaxTheme {
    let appearance = NSApp.effectiveAppearance  // ❌ 测试时 crash
    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    return isDark ? DefaultThemes.dark : DefaultThemes.light
}
```

### ✅ 正确示例

```swift
@MainActor
private static func themeForCurrentSystemAppearance() -> SyntaxTheme {
    guard let app = NSApp else {
        // 测试环境或 App 未初始化时的降级
        return DefaultThemes.light
    }
    
    let appearance = app.effectiveAppearance
    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    return isDark ? DefaultThemes.dark : DefaultThemes.light
}
```

### 测试 Suite 标记

```swift
@Suite("ThemeManager Tests")
@MainActor  // 测试 @MainActor 类型时需要此标记
struct ThemeManagerTests {
    // ...
}
```

---

## 相关文档

- [线程安全](./thread-safety.md)
- [错误日志模式](./error-logging-patterns.md)
- [优雅降级文档](./graceful-degradation-docs.md)
