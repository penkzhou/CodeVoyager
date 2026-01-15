import Foundation
import os.log

/// 语言注册表
///
/// 管理语言配置的懒加载和缓存。使用锁机制确保线程安全。
///
/// ## 设计决策
/// - 使用懒加载：配置仅在首次请求时加载
/// - 配置缓存：加载后缓存在内存中，避免重复创建
/// - 线程安全：使用 NSLock 保护共享状态
/// - 同步 API：协议要求同步方法，便于在非 async 上下文中使用
///
/// ## 使用示例
/// ```swift
/// // 推荐：通过依赖注入使用
/// let registry: LanguageRegistryProtocol = LanguageRegistry.shared
/// if let config = registry.configuration(forFile: fileURL) {
///     // 使用配置
/// }
/// ```
public final class LanguageRegistry: LanguageRegistryProtocol, @unchecked Sendable {
    /// 共享实例
    public static let shared = LanguageRegistry()

    private let logger = Logger(subsystem: "CodeVoyager", category: "LanguageRegistry")

    /// 保护缓存访问的锁
    private let lock = NSLock()

    /// 缓存的语言配置
    private var configurationCache: [SupportedLanguage: SyntaxLanguageConfiguration] = [:]

    /// 配置加载失败记录（避免重复尝试加载失败的语言）
    private var failedLanguages: Set<SupportedLanguage> = []

    // MARK: - Initialization

    public init() {}

    // MARK: - LanguageRegistryProtocol

    /// 获取指定语言的配置
    public func configuration(for language: SupportedLanguage) throws -> SyntaxLanguageConfiguration {
        lock.lock()
        defer { lock.unlock() }

        // 检查缓存
        if let cached = configurationCache[language] {
            return cached
        }

        // 检查是否已知加载失败
        if failedLanguages.contains(language) {
            throw LanguageConfigurationError.languageInitializationFailed(language)
        }

        // 懒加载配置
        do {
            let config = try SyntaxLanguageConfiguration.create(for: language)
            configurationCache[language] = config
            logger.debug("Loaded language configuration for \(language.displayName)")
            return config
        } catch {
            failedLanguages.insert(language)
            logger.error("Failed to load configuration for \(language.displayName): \(error.localizedDescription)")
            throw error
        }
    }

    /// 根据文件扩展名获取语言配置
    ///
    /// - Note: 如果配置加载失败，返回 nil。错误已在底层方法记录。
    public func configuration(forExtension fileExtension: String) -> SyntaxLanguageConfiguration? {
        guard let language = SupportedLanguage.detect(from: fileExtension) else {
            return nil
        }
        do {
            return try configuration(for: language)
        } catch {
            // 错误已在 configuration(for:) 中记录，这里只记录上下文
            logger.debug("Configuration unavailable for extension '\(fileExtension)' (language: \(language.displayName))")
            return nil
        }
    }

    // MARK: - Additional Methods
    //
    // Note: configuration(forFile:), detectLanguage(for:), isSupported(fileExtension:),
    // supportedExtensions 使用 LanguageRegistryProtocol 的默认实现

    /// 预加载所有语言配置
    ///
    /// 可以在应用启动时调用，避免首次使用时的延迟。
    /// 加载失败的语言会被记录但不会中断加载过程。
    public func preloadAllConfigurations() {
        logger.info("Preloading all language configurations...")

        for language in SupportedLanguage.allCases {
            do {
                _ = try configuration(for: language)
            } catch {
                logger.warning("Failed to preload \(language.displayName): \(error.localizedDescription)")
            }
        }

        lock.lock()
        let loadedCount = configurationCache.count
        let failedCount = failedLanguages.count
        lock.unlock()

        logger.info("Preload complete: \(loadedCount) loaded, \(failedCount) failed")
    }

    /// 清除配置缓存
    ///
    /// 同时清除已缓存的配置和失败语言记录。调用后，之前因加载失败而被记录的语言
    /// 将可以重新尝试加载。
    ///
    /// - Note: 主要用于测试场景
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        configurationCache.removeAll()
        failedLanguages.removeAll()
        logger.debug("Configuration cache cleared")
    }

    /// 获取已缓存的语言列表
    public var cachedLanguages: [SupportedLanguage] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configurationCache.keys)
    }
}
