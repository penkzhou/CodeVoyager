import Foundation

/// 语言注册表协议
///
/// 定义语言配置管理的核心接口，支持依赖注入以便测试时 mock。
///
/// ## 职责
/// - 根据语言或文件扩展名获取语言配置
/// - 管理语言配置的缓存
/// - 检测文件对应的语言
///
/// ## 测试 Mock 示例
/// ```swift
/// class MockLanguageRegistry: LanguageRegistryProtocol {
///     var configurationToReturn: SyntaxLanguageConfiguration?
///     var configurationForExtension: [String: SyntaxLanguageConfiguration] = [:]
///
///     func configuration(for language: SupportedLanguage) throws -> SyntaxLanguageConfiguration {
///         guard let config = configurationToReturn else {
///             throw LanguageConfigurationError.languageInitializationFailed(language)
///         }
///         return config
///     }
///
///     func configuration(forExtension fileExtension: String) -> SyntaxLanguageConfiguration? {
///         configurationForExtension[fileExtension]
///     }
///
///     // 以下方法有默认实现，可根据测试需要覆盖：
///     // - configuration(forFile:)
///     // - detectLanguage(for:)
///     // - isSupported(fileExtension:)
///     // - supportedExtensions
/// }
/// ```
public protocol LanguageRegistryProtocol: Sendable {
    /// 获取指定语言的配置
    /// - Parameter language: 目标语言
    /// - Returns: 语言配置
    /// - Throws: 配置加载失败时抛出错误
    func configuration(for language: SupportedLanguage) throws -> SyntaxLanguageConfiguration

    /// 根据文件扩展名获取语言配置
    /// - Parameter fileExtension: 文件扩展名（不含点号）
    /// - Returns: 语言配置，扩展名不支持时返回 nil
    func configuration(forExtension fileExtension: String) -> SyntaxLanguageConfiguration?

    /// 根据文件 URL 获取语言配置
    /// - Parameter url: 文件 URL
    /// - Returns: 语言配置，文件类型不支持时返回 nil
    func configuration(forFile url: URL) -> SyntaxLanguageConfiguration?

    /// 检测文件对应的语言
    /// - Parameter url: 文件 URL
    /// - Returns: 检测到的语言，不支持时返回 nil
    func detectLanguage(for url: URL) -> SupportedLanguage?

    /// 检查是否支持指定扩展名
    /// - Parameter fileExtension: 文件扩展名（不含点号）
    /// - Returns: 是否支持
    func isSupported(fileExtension: String) -> Bool

    /// 获取所有支持的文件扩展名
    var supportedExtensions: [String] { get }
}

// MARK: - Default Implementations

public extension LanguageRegistryProtocol {
    /// 根据文件 URL 获取语言配置（默认实现）
    func configuration(forFile url: URL) -> SyntaxLanguageConfiguration? {
        let ext = url.pathExtension
        guard !ext.isEmpty else { return nil }
        return configuration(forExtension: ext)
    }

    /// 检测文件对应的语言（默认实现）
    func detectLanguage(for url: URL) -> SupportedLanguage? {
        SupportedLanguage.detect(from: url)
    }

    /// 检查是否支持指定扩展名（默认实现）
    func isSupported(fileExtension: String) -> Bool {
        SupportedLanguage.detect(from: fileExtension) != nil
    }

    /// 获取所有支持的文件扩展名（默认实现）
    var supportedExtensions: [String] {
        SupportedLanguage.allCases.flatMap { $0.fileExtensions }
    }
}
