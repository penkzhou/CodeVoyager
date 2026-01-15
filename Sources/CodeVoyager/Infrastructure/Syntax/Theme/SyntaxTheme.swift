import Foundation
import AppKit

/// 语法高亮主题
///
/// 定义代码编辑器的完整视觉主题，包括：
/// - 编辑器背景色和行号颜色
/// - 当前行高亮
/// - 各类 Token 的样式（颜色、粗体、斜体）
///
/// ## Token 样式映射规则
/// 使用完全匹配策略：capture name 必须在主题中显式定义才有样式，
/// 未定义的 capture name 使用 `defaultStyle`。不做层级回退。
///
/// ### 映射示例
/// ```
/// tokenStyles 定义:
///   "keyword" → 蓝色粗体
///   "keyword.control" → 紫色粗体
///   "string" → 红色
///
/// 查询结果:
///   "keyword"           → 蓝色粗体 (完全匹配)
///   "keyword.control"   → 紫色粗体 (完全匹配)
///   "keyword.storage"   → defaultStyle (无匹配，不会回退到 "keyword")
///   "unknown.capture"   → defaultStyle (无匹配)
/// ```
///
/// ### 设计说明
/// 不使用层级回退（如 "keyword.control" 回退到 "keyword"）是为了：
/// 1. 保持行为可预测，避免意外的样式继承
/// 2. 简化实现，提高查找性能
/// 3. 鼓励主题作者显式定义所有需要的 capture name
///
/// ## 使用示例
/// ```swift
/// let theme = SyntaxTheme(
///     id: "my-theme",
///     name: "My Theme",
///     appearance: .dark,
///     backgroundColor: .black,
///     lineNumberColor: .gray,
///     currentLineBackgroundColor: .darkGray,
///     defaultStyle: TokenStyle(color: .white),
///     tokenStyles: [
///         "keyword": .bold(.systemBlue),
///         "comment": .italic(.systemGray)
///     ]
/// )
/// ```
public struct SyntaxTheme: Sendable, Identifiable, Equatable {
    /// 主题唯一标识符
    public let id: String

    /// 主题显示名称
    public let name: String

    /// 主题对应的外观模式
    public let appearance: Appearance

    /// 编辑器背景色
    public let backgroundColor: NSColor

    /// 行号颜色
    public let lineNumberColor: NSColor

    /// 当前行高亮背景色
    public let currentLineBackgroundColor: NSColor

    /// 选中文本的背景色
    public let selectionBackgroundColor: NSColor

    /// 默认文本样式（用于未定义的 capture name）
    public let defaultStyle: TokenStyle

    /// Token 样式映射
    /// Key: Tree-sitter capture name（如 "keyword", "comment", "string"）
    /// Value: 对应的 TokenStyle
    public let tokenStyles: [String: TokenStyle]

    // MARK: - Appearance

    /// 主题外观模式
    public enum Appearance: String, Sendable, CaseIterable {
        /// 浅色模式
        case light

        /// 深色模式
        case dark

        /// 检查是否匹配系统当前外观
        public func matches(systemAppearance: NSAppearance?) -> Bool {
            guard let appearance = systemAppearance else { return false }

            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return (self == .dark) == isDark
        }
    }

    // MARK: - Initialization

    /// 创建语法主题
    ///
    /// - Parameters:
    ///   - id: 主题唯一标识符，不能为空
    ///   - name: 主题显示名称，不能为空
    ///   - appearance: 主题对应的外观模式
    ///   - backgroundColor: 编辑器背景色
    ///   - lineNumberColor: 行号颜色
    ///   - currentLineBackgroundColor: 当前行高亮背景色
    ///   - selectionBackgroundColor: 选中文本的背景色
    ///   - defaultStyle: 默认文本样式
    ///   - tokenStyles: Token 样式映射
    ///
    /// - Precondition: `id` 和 `name` 不能为空字符串
    public init(
        id: String,
        name: String,
        appearance: Appearance,
        backgroundColor: NSColor,
        lineNumberColor: NSColor,
        currentLineBackgroundColor: NSColor,
        selectionBackgroundColor: NSColor,
        defaultStyle: TokenStyle,
        tokenStyles: [String: TokenStyle]
    ) {
        precondition(!id.trimmingCharacters(in: .whitespaces).isEmpty, "Theme id cannot be empty")
        precondition(!name.trimmingCharacters(in: .whitespaces).isEmpty, "Theme name cannot be empty")

        self.id = id
        self.name = name
        self.appearance = appearance
        self.backgroundColor = backgroundColor
        self.lineNumberColor = lineNumberColor
        self.currentLineBackgroundColor = currentLineBackgroundColor
        self.selectionBackgroundColor = selectionBackgroundColor
        self.defaultStyle = defaultStyle
        self.tokenStyles = tokenStyles
    }

    // MARK: - Style Lookup

    /// 获取指定 capture name 的样式
    ///
    /// 使用完全匹配策略，不做层级回退。
    /// 未找到时返回 defaultStyle。
    ///
    /// - Parameter captureName: Tree-sitter capture name（如 "keyword.control"）
    /// - Returns: 对应的 TokenStyle
    public func style(for captureName: String) -> TokenStyle {
        tokenStyles[captureName] ?? defaultStyle
    }

    /// 获取指定 capture name 的属性字典
    /// - Parameters:
    ///   - captureName: Tree-sitter capture name
    ///   - baseFont: 基础字体
    /// - Returns: NSAttributedString 属性字典
    public func attributes(for captureName: String, baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        style(for: captureName).attributes(baseFont: baseFont)
    }

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
}

// MARK: - Hashable

extension SyntaxTheme: Hashable {
    public func hash(into hasher: inout Hasher) {
        // 只使用 id 进行哈希
        hasher.combine(id)
    }
}

// MARK: - Common Capture Names

/// 常用的 Tree-sitter capture name 常量
///
/// 这些常量对应 Tree-sitter 官方 highlight queries 中使用的 capture name。
/// 使用常量可避免拼写错误，并提供自动补全支持。
public enum CaptureNames {
    // MARK: - Keywords

    /// 关键字（通用）
    public static let keyword = "keyword"

    /// 控制流关键字（if, else, for, while 等）
    public static let keywordControl = "keyword.control"

    /// 函数定义关键字（func, def 等）
    public static let keywordFunction = "keyword.function"

    /// 返回关键字（return）
    public static let keywordReturn = "keyword.return"

    /// 运算符关键字
    public static let keywordOperator = "keyword.operator"

    // MARK: - Types

    /// 类型名
    public static let type = "type"

    /// 内置类型
    public static let typeBuiltin = "type.builtin"

    // MARK: - Functions

    /// 函数名
    public static let function = "function"

    /// 方法名
    public static let functionMethod = "function.method"

    /// 内置函数
    public static let functionBuiltin = "function.builtin"

    /// 宏
    public static let functionMacro = "function.macro"

    // MARK: - Variables

    /// 变量名
    public static let variable = "variable"

    /// 参数名
    public static let variableParameter = "variable.parameter"

    /// 内置变量
    public static let variableBuiltin = "variable.builtin"

    // MARK: - Literals

    /// 字符串
    public static let string = "string"

    /// 字符串中的特殊字符（如转义序列）
    public static let stringSpecial = "string.special"

    /// 字符串转义
    public static let stringEscape = "string.escape"

    /// 数字
    public static let number = "number"

    /// 布尔值
    public static let boolean = "boolean"

    /// 常量
    public static let constant = "constant"

    /// 内置常量
    public static let constantBuiltin = "constant.builtin"

    // MARK: - Comments

    /// 注释
    public static let comment = "comment"

    /// 文档注释
    public static let commentDocumentation = "comment.documentation"

    // MARK: - Punctuation

    /// 标点符号（通用）
    public static let punctuation = "punctuation"

    /// 分隔符（逗号、分号等）
    public static let punctuationDelimiter = "punctuation.delimiter"

    /// 括号
    public static let punctuationBracket = "punctuation.bracket"

    /// 特殊标点
    public static let punctuationSpecial = "punctuation.special"

    // MARK: - Operators

    /// 运算符
    public static let `operator` = "operator"

    // MARK: - Properties

    /// 属性名
    public static let property = "property"

    // MARK: - Labels

    /// 标签
    public static let label = "label"

    // MARK: - Attributes

    /// 属性/装饰器（如 @available, @objc）
    public static let attribute = "attribute"

    // MARK: - Markdown Specific

    /// 标题
    public static let markupHeading = "markup.heading"

    /// 粗体
    public static let markupBold = "markup.bold"

    /// 斜体
    public static let markupItalic = "markup.italic"

    /// 链接
    public static let markupLink = "markup.link"

    /// 代码块
    public static let markupRaw = "markup.raw"

    /// 列表
    public static let markupList = "markup.list"

    /// 标题（text capture）
    public static let textTitle = "text.title"

    /// 代码或字面量（text capture）
    public static let textLiteral = "text.literal"

    /// 链接（text capture）
    public static let textURI = "text.uri"

    /// 引用（text capture）
    public static let textReference = "text.reference"

    /// 斜体（text capture）
    public static let textEmphasis = "text.emphasis"

    /// 粗体（text capture）
    public static let textStrong = "text.strong"
}
