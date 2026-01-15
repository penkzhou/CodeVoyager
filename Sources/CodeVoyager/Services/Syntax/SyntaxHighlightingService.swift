import AppKit
import STTextView
import Neon
import TreeSitterClient
import SwiftTreeSitter
import os.log

/// 语法高亮服务实现
///
/// 管理语法高亮的完整生命周期，包括：
/// - TreeSitterClient 实例管理（每语言一个实例）
/// - LRU 缓存管理（保留最近关闭文件的资源）
/// - 主题应用
///
/// ## 设计决策
///
/// ### 客户端策略
/// 每种语言维护一个 TreeSitterClient 实例，所有同语言文件共享解析能力。
/// 这在内存和性能之间取得平衡。
///
/// ### LRU 缓存
/// 文件关闭后，相关资源进入 LRU 缓存，便于快速重新打开。
/// 缓存容量由 `cacheCapacity` 参数控制。
///
/// ### 线程安全
/// 使用 @MainActor 确保所有状态访问在主线程，与 Neon 库要求一致。
@MainActor
public final class SyntaxHighlightingService: SyntaxHighlightingServiceProtocol {
    private static let logger = Logger(subsystem: "CodeVoyager", category: "SyntaxHighlightingService")

    // MARK: - Dependencies

    public let languageRegistry: LanguageRegistryProtocol
    public let themeManager: ThemeManagerProtocol

    // MARK: - Cache

    /// TreeSitterClient 缓存（每语言一个实例）
    private var clientCache: [SupportedLanguage: TreeSitterClient] = [:]

    /// 活跃的高亮会话（按文件 URL 索引）
    private var activeSessions: [URL: HighlightingSession] = [:]

    /// LRU 缓存：已关闭文件的 Highlighter（可快速恢复）
    /// 使用数组模拟 LRU，最近使用的在末尾
    private var sessionLRUCache: [(url: URL, session: HighlightingSession)] = []

    /// LRU 缓存容量
    private let cacheCapacity: Int

    /// 基础字体（用于样式生成）
    private let baseFont: NSFont

    // MARK: - Initialization

    /// 创建语法高亮服务
    /// - Parameters:
    ///   - languageRegistry: 语言注册表
    ///   - themeManager: 主题管理器
    ///   - cacheCapacity: LRU 缓存容量，默认 10
    ///   - baseFont: 基础字体，默认 13pt 等宽字体
    public init(
        languageRegistry: LanguageRegistryProtocol? = nil,
        themeManager: ThemeManagerProtocol? = nil,
        cacheCapacity: Int = 10,
        baseFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    ) {
        self.languageRegistry = languageRegistry ?? LanguageRegistry.shared
        self.themeManager = themeManager ?? ThemeManager.shared
        self.cacheCapacity = cacheCapacity
        self.baseFont = baseFont
    }

    // MARK: - SyntaxHighlightingServiceProtocol

    public func detectLanguage(for fileURL: URL) -> SupportedLanguage? {
        languageRegistry.detectLanguage(for: fileURL)
    }

    public func createSession(
        for textView: STTextView,
        context: HighlightingContext
    ) throws -> HighlightingSession {
        let language = context.language
        let fileURL = context.fileURL

        Self.logger.debug("Creating highlighting session for \(fileURL.lastPathComponent) (\(language.displayName))")

        // 1. 检查是否有缓存的会话
        if let cachedSession = retrieveFromLRUCache(for: fileURL) {
            Self.logger.debug("Restored session from LRU cache for \(fileURL.lastPathComponent)")
            activeSessions[fileURL] = cachedSession
            return cachedSession
        }

        // 2. 获取或创建 TreeSitterClient
        let client = try getOrCreateClient(for: language)

        // 3. 获取语言配置（包含 Query）
        let config: SyntaxLanguageConfiguration
        do {
            config = try languageRegistry.configuration(for: language)
        } catch {
            throw SyntaxHighlightingError.configurationFailed(language, error)
        }

        guard let query = config.highlightsQuery else {
            throw SyntaxHighlightingError.queryNotAvailable(language)
        }

        // 4. 设置初始文本内容
        client.didChangeContent(
            to: context.content,
            in: NSRange(location: 0, length: 0),
            delta: context.content.utf16.count,
            limit: context.content.utf16.count
        )

        // 5. 创建 TokenProvider
        let tokenProvider = client.tokenProvider(
            with: query,
            executionMode: .asynchronous(prefetch: true)
        )

        // 6. 创建 TextSystemInterface 适配器
        let textInterface = STTextViewSystemInterface(
            textView: textView,
            attributeProvider: { [weak self] token in
                self?.attributesForToken(token)
            }
        )

        // 7. 创建 Highlighter
        let highlighter = Highlighter(
            textInterface: textInterface,
            tokenProvider: tokenProvider
        )

        // 8. 设置失效处理
        client.invalidationHandler = { [weak highlighter] ranges in
            highlighter?.invalidate(.set(ranges))
        }

        // 9. 触发初始高亮
        highlighter.invalidate(.all)

        // 10. 创建会话
        let session = HighlightingSession(
            fileURL: fileURL,
            language: language,
            highlighter: highlighter
        )

        activeSessions[fileURL] = session

        Self.logger.debug("Successfully created highlighting session for \(fileURL.lastPathComponent)")

        return session
    }

    public func updateContent(
        for fileURL: URL,
        newContent: String,
        previousContentLength: Int
    ) {
        guard let session = activeSessions[fileURL] else {
            Self.logger.warning(
                "No active highlighting session for \(fileURL.lastPathComponent). File will be displayed without updated syntax highlighting."
            )
            return
        }

        guard let client = clientCache[session.language] else {
            Self.logger.warning(
                "Missing TreeSitterClient for \(session.language.displayName) while updating \(fileURL.lastPathComponent). File will be displayed without updated syntax highlighting."
            )
            return
        }

        let newLength = newContent.utf16.count
        client.didChangeContent(
            to: newContent,
            in: NSRange(location: 0, length: previousContentLength),
            delta: newLength - previousContentLength,
            limit: newLength
        )

        session.invalidate()
    }

    public func releaseSession(for fileURL: URL) {
        guard let session = activeSessions.removeValue(forKey: fileURL) else {
            Self.logger.debug("No active session found for \(fileURL.lastPathComponent)")
            return
        }

        // 添加到 LRU 缓存
        addToLRUCache(url: fileURL, session: session)

        Self.logger.debug("Released session for \(fileURL.lastPathComponent), moved to LRU cache")
    }

    public func clearAllCaches() {
        activeSessions.removeAll()
        sessionLRUCache.removeAll()
        clientCache.removeAll()

        Self.logger.info("Cleared all syntax highlighting caches")
    }

    // MARK: - Private: Client Management

    /// 获取或创建语言的 TreeSitterClient
    private func getOrCreateClient(for language: SupportedLanguage) throws -> TreeSitterClient {
        // 检查缓存
        if let cached = clientCache[language] {
            return cached
        }

        // 获取语言配置
        let config: SyntaxLanguageConfiguration
        do {
            config = try languageRegistry.configuration(for: language)
        } catch {
            throw SyntaxHighlightingError.configurationFailed(language, error)
        }

        // 创建新的 client
        let client: TreeSitterClient
        do {
            client = try TreeSitterClient(language: config.tsLanguage)
        } catch {
            throw SyntaxHighlightingError.clientCreationFailed(language, error)
        }

        clientCache[language] = client

        Self.logger.debug("Created TreeSitterClient for \(language.displayName)")

        return client
    }

    // MARK: - Private: LRU Cache Management

    /// 从 LRU 缓存中检索会话
    private func retrieveFromLRUCache(for url: URL) -> HighlightingSession? {
        guard let index = sessionLRUCache.firstIndex(where: { $0.url == url }) else {
            return nil
        }

        let entry = sessionLRUCache.remove(at: index)
        return entry.session
    }

    /// 添加到 LRU 缓存
    private func addToLRUCache(url: URL, session: HighlightingSession) {
        // 如果已存在，先移除
        sessionLRUCache.removeAll { $0.url == url }

        // 添加到末尾（最近使用）
        sessionLRUCache.append((url: url, session: session))

        // 检查容量限制
        while sessionLRUCache.count > cacheCapacity {
            let evicted = sessionLRUCache.removeFirst()
            Self.logger.debug("Evicted session from LRU cache: \(evicted.url.lastPathComponent)")
        }
    }

    // MARK: - Private: Theme Application

    /// 为 Token 生成属性字典
    private func attributesForToken(_ token: Token) -> [NSAttributedString.Key: Any]? {
        let theme = themeManager.currentTheme
        let style = theme.style(for: token.name)
        return style.attributes(baseFont: baseFont)
    }
}

// MARK: - Testing Support

#if DEBUG
extension SyntaxHighlightingService {
    /// 仅用于测试：获取活跃会话数量
    var activeSessionCount: Int {
        activeSessions.count
    }

    /// 仅用于测试：获取 LRU 缓存数量
    var lruCacheCount: Int {
        sessionLRUCache.count
    }

    /// 仅用于测试：获取 Client 缓存数量
    var clientCacheCount: Int {
        clientCache.count
    }

    /// 仅用于测试：检查是否有指定文件的活跃会话
    func hasActiveSession(for url: URL) -> Bool {
        activeSessions[url] != nil
    }

    /// 仅用于测试：检查是否有指定文件的缓存会话
    func hasCachedSession(for url: URL) -> Bool {
        sessionLRUCache.contains { $0.url == url }
    }
}
#endif
