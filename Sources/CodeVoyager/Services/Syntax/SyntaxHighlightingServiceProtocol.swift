import AppKit
import STTextView
import Neon

/// 语法高亮服务的文件上下文
///
/// 包含进行语法高亮所需的全部信息：文件 URL、语言类型、文本视图引用
public struct HighlightingContext: Sendable {
    /// 文件 URL（用于缓存键）
    public let fileURL: URL

    /// 检测到的语言
    public let language: SupportedLanguage

    /// 文件内容
    public let content: String

    /// 创建高亮上下文
    /// - Parameters:
    ///   - fileURL: 文件 URL
    ///   - language: 编程语言
    ///   - content: 文件内容
    public init(fileURL: URL, language: SupportedLanguage, content: String) {
        self.fileURL = fileURL
        self.language = language
        self.content = content
    }
}

/// 高亮会话
///
/// 管理单个文件的高亮状态，包含 Highlighter 实例。
/// 使用 class 类型以支持弱引用和生命周期管理。
@MainActor
public final class HighlightingSession {
    /// 文件 URL
    public let fileURL: URL

    /// 检测到的语言
    public let language: SupportedLanguage

    /// Neon Highlighter 实例
    public let highlighter: Highlighter

    /// 创建高亮会话
    /// - Parameters:
    ///   - fileURL: 文件 URL
    ///   - language: 编程语言
    ///   - highlighter: Highlighter 实例
    internal init(fileURL: URL, language: SupportedLanguage, highlighter: Highlighter) {
        self.fileURL = fileURL
        self.language = language
        self.highlighter = highlighter
    }

    /// 使整个文本失效，触发重新高亮
    public func invalidate() {
        highlighter.invalidate(.all)
    }

    /// 通知可见内容变化（滚动）
    public func visibleContentDidChange() {
        highlighter.visibleContentDidChange()
    }
}

/// 语法高亮服务错误
public enum SyntaxHighlightingError: Error, LocalizedError {
    /// 语言不支持
    case unsupportedLanguage(String)

    /// 语言配置加载失败
    case configurationFailed(SupportedLanguage, Error)

    /// 高亮查询不可用
    case queryNotAvailable(SupportedLanguage)

    /// TreeSitterClient 创建失败
    case clientCreationFailed(SupportedLanguage, Error)

    /// 错误描述
    public var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let ext):
            return "文件扩展名 .\(ext) 暂不支持语法高亮"
        case .configurationFailed(let lang, let error):
            return "加载 \(lang.displayName) 配置失败: \(error.localizedDescription)"
        case .queryNotAvailable(let lang):
            return "无法为 \(lang.displayName) 加载高亮 Query"
        case .clientCreationFailed(let lang, let error):
            return "创建 \(lang.displayName) 解析器失败: \(error.localizedDescription)"
        }
    }
}

/// 语法高亮服务协议
///
/// 负责管理语法高亮的完整生命周期：
/// - 语言检测
/// - TreeSitterClient 创建和缓存
/// - Highlighter 配置
/// - 主题应用
@MainActor
public protocol SyntaxHighlightingServiceProtocol: AnyObject {
    /// 当前使用的语言注册表
    var languageRegistry: LanguageRegistryProtocol { get }

    /// 当前使用的主题管理器
    var themeManager: ThemeManagerProtocol { get }

    /// 检测文件语言
    /// - Parameter fileURL: 文件 URL
    /// - Returns: 检测到的语言，如不支持返回 nil
    func detectLanguage(for fileURL: URL) -> SupportedLanguage?

    /// 为文本视图创建高亮会话
    ///
    /// 该方法会：
    /// 1. 获取或创建语言的 TreeSitterClient
    /// 2. 创建 STTextViewSystemInterface 适配器
    /// 3. 配置 Highlighter 和 TokenProvider
    /// 4. 设置初始文本内容
    ///
    /// - Parameters:
    ///   - textView: 需要高亮的 STTextView
    ///   - context: 高亮上下文
    /// - Returns: 高亮会话
    /// - Throws: `SyntaxHighlightingError` 如果配置失败
    func createSession(
        for textView: STTextView,
        context: HighlightingContext
    ) throws -> HighlightingSession

    /// 更新指定文件的内容并触发重新高亮
    ///
    /// - Parameters:
    ///   - fileURL: 文件 URL
    ///   - newContent: 新内容
    ///   - previousContentLength: 旧内容长度（用于增量更新）
    func updateContent(
        for fileURL: URL,
        newContent: String,
        previousContentLength: Int
    )

    /// 释放文件的高亮会话
    ///
    /// 调用后，相关资源会进入 LRU 缓存以便重用
    /// - Parameter fileURL: 文件 URL
    func releaseSession(for fileURL: URL)

    /// 清除所有缓存
    ///
    /// 释放所有 TreeSitterClient 和相关资源
    func clearAllCaches()
}
