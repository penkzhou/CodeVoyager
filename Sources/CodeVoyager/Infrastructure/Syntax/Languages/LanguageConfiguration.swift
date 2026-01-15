import Foundation
import SwiftTreeSitter
import os.log

// 导入各语言的 Tree-sitter 解析器
import TreeSitterSwift
import TreeSitterSwiftQueries
import TreeSitterJavaScript
import TreeSitterJavaScriptQueries
import TreeSitterTypeScript
import TreeSitterTypeScriptQueries
import TreeSitterTSX
import TreeSitterTSXQueries
import TreeSitterPython
import TreeSitterPythonQueries
import TreeSitterJSON
import TreeSitterJSONQueries
import TreeSitterMarkdown
import TreeSitterMarkdownQueries
import TreeSitterMarkdownInline
import TreeSitterMarkdownInlineQueries

/// 语言配置加载错误
public enum LanguageConfigurationError: Error, LocalizedError {
    case languageInitializationFailed(SupportedLanguage)
    case queryLoadFailed(SupportedLanguage, underlying: Error)
    case unsupportedLanguage(String)

    public var errorDescription: String? {
        switch self {
        case .languageInitializationFailed(let language):
            return "Failed to initialize Tree-sitter language: \(language.displayName)"
        case .queryLoadFailed(let language, let underlying):
            return "Failed to load highlight query for \(language.displayName): \(underlying.localizedDescription)"
        case .unsupportedLanguage(let extension_):
            return "Unsupported file extension: .\(extension_)"
        }
    }
}

/// 语法语言配置
///
/// 封装 Tree-sitter 的 Language 和相关的高亮 Query，提供便利的创建方法
/// 和对各支持语言的统一访问接口。
///
/// ## 降级行为
/// 当高亮 Query 加载失败时（如 .scm 文件缺失或格式错误），配置仍可成功创建，
/// 但 `highlightsQuery` 为 nil。此时语法高亮将不可用，代码仅显示默认文本样式，
/// 但代码编辑/浏览功能正常。具体降级场景：
/// - Query 文件不存在：`highlightsQuery = nil`，无语法高亮
/// - Query 语法错误：`highlightsQuery = nil`，无语法高亮
/// - Language 初始化失败：此情况不会降级，直接抛出错误
///
/// ## 使用示例
/// ```swift
/// let config = try SyntaxLanguageConfiguration.create(for: .swift)
/// let parser = Parser()
/// try parser.setLanguage(config.tsLanguage)
///
/// // 检查是否支持语法高亮
/// if let query = config.highlightsQuery {
///     // 应用语法高亮
/// } else {
///     // 降级：显示无高亮的纯文本
/// }
/// ```
public struct SyntaxLanguageConfiguration: Sendable {
    private static let logger = Logger(subsystem: "CodeVoyager", category: "SyntaxLanguageConfiguration")
    /// 对应的支持语言
    public let language: SupportedLanguage

    /// Tree-sitter Language 实例
    public let tsLanguage: Language

    /// 高亮 Query（从 bundle 加载的 highlights.scm）
    public let highlightsQuery: SwiftTreeSitter.Query?

    // MARK: - Factory Methods

    /// 为指定语言创建配置
    /// - Parameter language: 目标语言
    /// - Returns: 语言配置
    /// - Throws: 配置加载失败时抛出 LanguageConfigurationError
    public static func create(for language: SupportedLanguage) throws -> SyntaxLanguageConfiguration {
        let tsLanguage = getTreeSitterLanguage(for: language)
        let query = loadHighlightsQuery(for: language, tsLanguage: tsLanguage)

        return SyntaxLanguageConfiguration(
            language: language,
            tsLanguage: tsLanguage,
            highlightsQuery: query
        )
    }

    /// 根据文件扩展名创建配置
    /// - Parameter fileExtension: 文件扩展名（不含点号）
    /// - Returns: 语言配置
    /// - Throws: 扩展名不支持或配置加载失败时抛出错误
    public static func create(forExtension fileExtension: String) throws -> SyntaxLanguageConfiguration {
        guard let language = SupportedLanguage.detect(from: fileExtension) else {
            throw LanguageConfigurationError.unsupportedLanguage(fileExtension)
        }
        return try create(for: language)
    }

    // MARK: - Private Helpers

    /// 获取 Tree-sitter Language 实例
    private static func getTreeSitterLanguage(for language: SupportedLanguage) -> Language {
        switch language {
        case .swift:
            return Language(language: tree_sitter_swift())
        case .javascript:
            return Language(language: tree_sitter_javascript())
        case .typescript:
            return Language(language: tree_sitter_typescript())
        case .tsx:
            return Language(language: tree_sitter_tsx())
        case .python:
            return Language(language: tree_sitter_python())
        case .json:
            return Language(language: tree_sitter_json())
        case .markdown:
            return Language(language: tree_sitter_markdown())
        }
    }

    /// 加载高亮 Query
    /// TreeSitterLanguages 包会将 queries 包含在各自的 Queries bundle 中
    ///
    /// - Note: 如果加载失败，返回 nil 并记录警告日志。语法高亮将降级为无高亮模式。
    private static func loadHighlightsQuery(for language: SupportedLanguage, tsLanguage: Language) -> SwiftTreeSitter.Query? {
        guard let queryURL = getHighlightsQueryURL(for: language) else {
            logger.warning("Highlights query URL not found for \(language.displayName). Syntax highlighting will be disabled for this language.")
            return nil
        }

        do {
            return try tsLanguage.query(contentsOf: queryURL)
        } catch {
            // 降级行为：返回 nil，语法高亮将不可用，但代码编辑功能正常
            logger.warning("Failed to load highlights query for \(language.displayName): \(error.localizedDescription). Syntax highlighting will be disabled for this language.")
            return nil
        }
    }

    /// 获取高亮 Query 文件的 URL
    private static func getHighlightsQueryURL(for language: SupportedLanguage) -> URL? {
        let queryFileName = "highlights"

        // 尝试在主 bundle 中查找资源 bundle
        guard let resourceBundleURL = Bundle.main.url(forResource: language.queriesBundleName, withExtension: "bundle"),
              let resourceBundle = Bundle(url: resourceBundleURL) else {
            // 回退：直接在主 bundle 中查找
            logger.debug("Resource bundle '\(language.queriesBundleName)' not found, falling back to main bundle for \(language.displayName)")
            return Bundle.main.url(forResource: queryFileName, withExtension: "scm")
        }

        return resourceBundle.url(forResource: queryFileName, withExtension: "scm")
    }

    // MARK: - Internal Initialization

    /// 内部初始化器
    ///
    /// 使用 `create(for:)` 或 `create(forExtension:)` 工厂方法创建实例。
    /// 直接初始化仅用于内部实现和测试。
    internal init(
        language: SupportedLanguage,
        tsLanguage: Language,
        highlightsQuery: SwiftTreeSitter.Query?
    ) {
        self.language = language
        self.tsLanguage = tsLanguage
        self.highlightsQuery = highlightsQuery
    }
}
