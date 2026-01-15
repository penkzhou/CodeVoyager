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
public struct SyntaxLanguageConfiguration {
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
    ///
    /// - Note: 如果加载失败，返回 nil 并记录警告日志。语法高亮将降级为无高亮模式。
    private static func loadHighlightsQuery(for language: SupportedLanguage, tsLanguage: Language) -> SwiftTreeSitter.Query? {
        let queryURLs = highlightsQueryURLs(for: language)
        guard !queryURLs.isEmpty else {
            logger.warning(
                "Highlights query URL not found for \(language.displayName, privacy: .public). Syntax highlighting will be disabled for this language."
            )
            return nil
        }

        do {
            let query = try buildHighlightsQuery(from: queryURLs, tsLanguage: tsLanguage, language: language)
            return query
        } catch {
            // 降级行为：返回 nil，语法高亮将不可用，但代码编辑功能正常
            logger.warning(
                "Failed to load highlights query for \(language.displayName, privacy: .public): \(error.localizedDescription, privacy: .public). Syntax highlighting will be disabled for this language."
            )
            return nil
        }
    }

    private static func buildHighlightsQuery(
        from queryURLs: [URL],
        tsLanguage: Language,
        language: SupportedLanguage
    ) throws -> SwiftTreeSitter.Query {
        var combinedData = Data()
        var includedURLs: [URL] = []

        for url in queryURLs {
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                logger.warning(
                    "Failed to read highlights query \(url.lastPathComponent, privacy: .public) for \(language.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }

            var candidate = combinedData
            if !candidate.isEmpty {
                candidate.append(0x0A)
            }
            candidate.append(data)

            do {
                _ = try SwiftTreeSitter.Query(language: tsLanguage, data: candidate)
                combinedData = candidate
                includedURLs.append(url)
            } catch {
                logger.warning(
                    "Skipping highlights query \(url.lastPathComponent, privacy: .public) for \(language.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        guard !combinedData.isEmpty else {
            throw LanguageConfigurationError.queryLoadFailed(language, underlying: QueryLoadError.noValidQuery)
        }

        if includedURLs.count < queryURLs.count {
            let skippedCount = queryURLs.count - includedURLs.count
            logger.warning(
                "Loaded highlights for \(language.displayName, privacy: .public) with \(skippedCount, privacy: .public) query file(s) skipped due to incompatibility."
            )
        }

        return try SwiftTreeSitter.Query(language: tsLanguage, data: combinedData)
    }

    private enum QueryLoadError: LocalizedError {
        case noValidQuery

        var errorDescription: String? {
            switch self {
            case .noValidQuery:
                return "No compatible highlights query could be loaded"
            }
        }
    }

    private static func highlightsQueryURLs(for language: SupportedLanguage) -> [URL] {
        switch language {
        case .swift:
            return [TreeSitterSwiftQueries.Query.highlightsFileURL]
        case .javascript:
            return [
                TreeSitterJavaScriptQueries.Query.highlightsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsParamsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsJSXFileURL
            ]
        case .typescript:
            return [
                TreeSitterJavaScriptQueries.Query.highlightsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsParamsFileURL,
                TreeSitterTypeScriptQueries.Query.highlightsFileURL
            ]
        case .tsx:
            return [
                TreeSitterJavaScriptQueries.Query.highlightsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsParamsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsJSXFileURL,
                TreeSitterTSXQueries.Query.highlightsFileURL
            ]
        case .python:
            return [TreeSitterPythonQueries.Query.highlightsFileURL]
        case .json:
            return [TreeSitterJSONQueries.Query.highlightsFileURL]
        case .markdown:
            return [TreeSitterMarkdownQueries.Query.highlightsFileURL]
        }
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
