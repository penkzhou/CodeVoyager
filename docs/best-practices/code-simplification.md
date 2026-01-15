# 代码简化最佳实践

## 概述

本文档描述了代码简化的常见模式，帮助保持代码简洁、可读。

## Switch-Case 简化

### 问题

当枚举的计算属性与 rawValue 完全一致时，显式的 switch-case 是冗余的：

```swift
// ❌ 冗余的 switch-case
public enum Language: String {
    case swift, javascript, python
    
    public var identifier: String {
        switch self {
        case .swift: return "swift"
        case .javascript: return "javascript"
        case .python: return "python"
        }
    }
}
```

### 解决方案

直接返回 rawValue：

```swift
// ✅ 简化后
public enum Language: String {
    case swift, javascript, python
    
    /// - Note: 当前所有语言的标识符与 rawValue 一致。
    ///   如果未来添加的语言标识符与 rawValue 不同，需要恢复为 switch-case。
    public var identifier: String {
        rawValue
    }
}
```

**重要**：添加注释说明简化的假设条件，便于未来维护。

## Nil 合并运算符

### 问题

使用 if-let 处理可选值的默认情况：

```swift
// ❌ 冗余的 if-let
public func style(for key: String) -> Style {
    if let style = styles[key] {
        return style
    }
    return defaultStyle
}
```

### 解决方案

使用 nil 合并运算符：

```swift
// ✅ 简化后
public func style(for key: String) -> Style {
    styles[key] ?? defaultStyle
}
```

## Bool 属性简化

### 问题

带关联值的枚举检查使用冗余的 switch-case：

```swift
// ❌ 冗余的 switch-case
public enum Preference: Equatable {
    case automatic
    case manual(id: String)
    
    public var isAutomatic: Bool {
        switch self {
        case .automatic:
            return true
        case .manual:
            return false
        }
    }
}
```

### 解决方案

直接使用等值比较：

```swift
// ✅ 简化后
public var isAutomatic: Bool {
    self == .automatic
}
```

**注意**：此模式要求枚举遵循 `Equatable`。对于带关联值的枚举，Swift 会自动合成正确的比较逻辑。

## 协议默认实现

### 问题

重复实现与协议默认实现完全相同的方法：

```swift
// ❌ 重复实现
public protocol DataSource {
    func item(at index: Int) -> Item?
}

extension DataSource {
    func item(at index: Int) -> Item? {
        guard index >= 0 && index < count else { return nil }
        return items[index]
    }
}

class MyDataSource: DataSource {
    // 与协议默认实现完全相同
    func item(at index: Int) -> Item? {
        guard index >= 0 && index < count else { return nil }
        return items[index]
    }
}
```

### 解决方案

直接使用协议默认实现，添加注释说明：

```swift
// ✅ 使用默认实现
class MyDataSource: DataSource {
    // Note: item(at:) 使用 DataSource 协议的默认实现
}
```

## 静态 Logger 实例

### 问题

在频繁调用的方法中每次创建 Logger：

```swift
// ❌ 每次调用创建 Logger
public struct TokenStyle {
    public func font(from baseFont: NSFont) -> NSFont {
        // 这个方法可能被调用数千次（每个 token 一次）
        if failed {
            let logger = Logger(subsystem: "App", category: "TokenStyle")
            logger.warning("Failed to create font")
        }
        return baseFont
    }
}
```

### 解决方案

使用静态 Logger 属性：

```swift
// ✅ 静态 Logger
public struct TokenStyle {
    private static let logger = Logger(subsystem: "App", category: "TokenStyle")
    
    public func font(from baseFont: NSFont) -> NSFont {
        if failed {
            Self.logger.warning("Failed to create font")
        }
        return baseFont
    }
}
```

**注意**：Logger 是 Sendable 的，可以安全地作为静态属性在 Sendable 类型中使用。

## 相关准则

- [代码复用](code-deduplication.md)
- [冗余代码检查](../CLAUDE.md#冗余代码检查)
