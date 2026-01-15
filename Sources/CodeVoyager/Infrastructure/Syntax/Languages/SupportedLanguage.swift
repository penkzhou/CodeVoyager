import Foundation

/// 语法高亮支持的语言枚举
///
/// 每个语言定义了：
/// - 文件扩展名映射（固定映射，不做内容推断）
/// - 显示名称（用于状态栏）
/// - 图标名称（SF Symbol）
/// - Tree-sitter 语言标识符
public enum SupportedLanguage: String, CaseIterable, Sendable {
    case swift
    case javascript
    case typescript
    case tsx
    case python
    case json
    case markdown

    // MARK: - Display Properties

    /// 用于状态栏显示的语言名称
    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .tsx: return "TypeScript"
        case .python: return "Python"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        }
    }

    /// 用于状态栏显示的图标名称（SF Symbol）
    ///
    /// 所有图标名称均为 macOS 14+ 支持的官方 SF Symbol。
    /// 参考: https://developer.apple.com/sf-symbols/
    public var iconName: String {
        switch self {
        case .swift: return "swift"
        case .javascript: return "j.square"         // 使用有效的 SF Symbol
        case .typescript: return "t.square"
        case .tsx: return "t.square"
        case .python: return "chevron.left.forwardslash.chevron.right"  // 使用代码符号
        case .json: return "curlybraces"
        case .markdown: return "doc.richtext"
        }
    }

    // MARK: - File Extension Mapping

    /// 该语言对应的所有文件扩展名（不含点号）
    public var fileExtensions: [String] {
        switch self {
        case .swift:
            return ["swift"]
        case .javascript:
            return ["js", "jsx", "mjs", "cjs"]
        case .typescript:
            return ["ts"]
        case .tsx:
            return ["tsx"]
        case .python:
            return ["py", "pyw"]
        case .json:
            return ["json", "jsonc"]
        case .markdown:
            return ["md", "markdown"]
        }
    }

    /// 根据文件扩展名检测语言
    /// - Parameter fileExtension: 文件扩展名（不含点号，如 "swift"）
    /// - Returns: 匹配的语言，未找到返回 nil
    public static func detect(from fileExtension: String) -> SupportedLanguage? {
        let lowercased = fileExtension.lowercased()
        return allCases.first { language in
            language.fileExtensions.contains(lowercased)
        }
    }

    /// 根据文件 URL 检测语言
    /// - Parameter url: 文件 URL
    /// - Returns: 匹配的语言，未找到返回 nil
    public static func detect(from url: URL) -> SupportedLanguage? {
        let fileExtension = url.pathExtension
        guard !fileExtension.isEmpty else { return nil }
        return detect(from: fileExtension)
    }

    // MARK: - Tree-sitter Identifier

    /// Tree-sitter 内部使用的语言标识符
    /// 用于嵌套语言解析时的语言识别
    ///
    /// - Note: 当前所有语言的 Tree-sitter 标识符与枚举的 rawValue 一致。
    ///   如果未来添加的语言标识符与 rawValue 不同，需要恢复为 switch-case 实现。
    public var treeSitterLanguageName: String {
        rawValue
    }

    // MARK: - Resource Bundle

    /// SwiftPM 生成的 Queries 资源 bundle 名称
    ///
    /// 格式为: TreeSitterLanguages_TreeSitter<Language>Queries
    /// 用于加载 highlights.scm 等查询文件
    var queriesBundleName: String {
        switch self {
        case .swift:
            return "TreeSitterLanguages_TreeSitterSwiftQueries"
        case .javascript:
            return "TreeSitterLanguages_TreeSitterJavaScriptQueries"
        case .typescript:
            return "TreeSitterLanguages_TreeSitterTypeScriptQueries"
        case .tsx:
            return "TreeSitterLanguages_TreeSitterTSXQueries"
        case .python:
            return "TreeSitterLanguages_TreeSitterPythonQueries"
        case .json:
            return "TreeSitterLanguages_TreeSitterJSONQueries"
        case .markdown:
            return "TreeSitterLanguages_TreeSitterMarkdownQueries"
        }
    }
}
