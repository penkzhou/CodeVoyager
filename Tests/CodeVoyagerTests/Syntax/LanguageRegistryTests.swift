import Foundation
import Testing
@testable import CodeVoyager

@Suite("LanguageRegistry Tests")
struct LanguageRegistryTests {

    // MARK: - Configuration Loading Tests

    @Test("Loads Swift configuration successfully")
    func loadSwiftConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .swift)

        #expect(config.language == .swift)
    }

    @Test("Loads JavaScript configuration successfully")
    func loadJavaScriptConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .javascript)

        #expect(config.language == .javascript)
    }

    @Test("Loads TypeScript configuration successfully")
    func loadTypeScriptConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .typescript)

        #expect(config.language == .typescript)
    }

    @Test("Loads TSX configuration successfully")
    func loadTSXConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .tsx)

        #expect(config.language == .tsx)
    }

    @Test("Loads Python configuration successfully")
    func loadPythonConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .python)

        #expect(config.language == .python)
    }

    @Test("Loads JSON configuration successfully")
    func loadJSONConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .json)

        #expect(config.language == .json)
    }

    @Test("Loads Markdown configuration successfully")
    func loadMarkdownConfiguration() throws {
        let registry = LanguageRegistry()
        let config = try registry.configuration(for: .markdown)

        #expect(config.language == .markdown)
    }

    // MARK: - Cache Behavior Tests

    @Test("Configuration is cached after first load")
    func configurationIsCached() throws {
        let registry = LanguageRegistry()

        // First load
        _ = try registry.configuration(for: .swift)
        #expect(registry.cachedLanguages.contains(.swift))

        // Second load should return cached value
        _ = try registry.configuration(for: .swift)
        #expect(registry.cachedLanguages.count == 1)
    }

    @Test("Clear cache removes all cached configurations")
    func clearCacheRemovesAll() throws {
        let registry = LanguageRegistry()

        // Load multiple configurations
        _ = try registry.configuration(for: .swift)
        _ = try registry.configuration(for: .python)
        #expect(registry.cachedLanguages.count == 2)

        // Clear cache
        registry.clearCache()
        #expect(registry.cachedLanguages.isEmpty)
    }

    @Test("Clear cache allows reloading configurations")
    func clearCacheAllowsReload() throws {
        let registry = LanguageRegistry()

        // Load configuration
        let config1 = try registry.configuration(for: .swift)
        #expect(registry.cachedLanguages.contains(.swift))

        // Clear cache
        registry.clearCache()
        #expect(registry.cachedLanguages.isEmpty)

        // Reload - should work without issues
        let config2 = try registry.configuration(for: .swift)
        #expect(registry.cachedLanguages.contains(.swift))

        // Both configurations should represent the same language
        #expect(config1.language == config2.language)
    }

    @Test("Multiple clear cache calls are safe")
    func multipleClearCacheCalls() {
        let registry = LanguageRegistry()

        // Multiple clears should not cause issues
        registry.clearCache()
        registry.clearCache()
        registry.clearCache()

        #expect(registry.cachedLanguages.isEmpty)
    }

    // MARK: - Extension-based Loading Tests

    @Test("Loads configuration by file extension")
    func loadByExtension() throws {
        let registry = LanguageRegistry()

        let swiftConfig = registry.configuration(forExtension: "swift")
        #expect(swiftConfig?.language == .swift)

        let jsConfig = registry.configuration(forExtension: "js")
        #expect(jsConfig?.language == .javascript)

        let tsxConfig = registry.configuration(forExtension: "tsx")
        #expect(tsxConfig?.language == .tsx)
    }

    @Test("Returns nil for unsupported extension")
    func unsupportedExtensionReturnsNil() {
        let registry = LanguageRegistry()

        #expect(registry.configuration(forExtension: "rs") == nil)
        #expect(registry.configuration(forExtension: "go") == nil)
        #expect(registry.configuration(forExtension: "") == nil)
    }

    // MARK: - URL-based Loading Tests

    @Test("Loads configuration by file URL")
    func loadByURL() throws {
        let registry = LanguageRegistry()

        let swiftURL = URL(fileURLWithPath: "/path/to/App.swift")
        let swiftConfig = registry.configuration(forFile: swiftURL)
        #expect(swiftConfig?.language == .swift)

        let pyURL = URL(fileURLWithPath: "/project/main.py")
        let pyConfig = registry.configuration(forFile: pyURL)
        #expect(pyConfig?.language == .python)
    }

    @Test("Returns nil for URL without extension")
    func urlWithoutExtensionReturnsNil() {
        let registry = LanguageRegistry()

        let noExtURL = URL(fileURLWithPath: "/path/to/Makefile")
        #expect(registry.configuration(forFile: noExtURL) == nil)
    }

    // MARK: - Language Detection Tests

    @Test("Detects language from URL")
    func detectLanguageFromURL() {
        let registry = LanguageRegistry()

        let swiftURL = URL(fileURLWithPath: "/path/App.swift")
        #expect(registry.detectLanguage(for: swiftURL) == .swift)

        let jsURL = URL(fileURLWithPath: "/path/index.js")
        #expect(registry.detectLanguage(for: jsURL) == .javascript)
    }

    // MARK: - Supported Extensions Tests

    @Test("isSupported returns true for supported extensions")
    func isSupportedTrue() {
        let registry = LanguageRegistry()

        #expect(registry.isSupported(fileExtension: "swift") == true)
        #expect(registry.isSupported(fileExtension: "js") == true)
        #expect(registry.isSupported(fileExtension: "tsx") == true)
        #expect(registry.isSupported(fileExtension: "py") == true)
        #expect(registry.isSupported(fileExtension: "json") == true)
        #expect(registry.isSupported(fileExtension: "md") == true)
    }

    @Test("isSupported returns false for unsupported extensions")
    func isSupportedFalse() {
        let registry = LanguageRegistry()

        #expect(registry.isSupported(fileExtension: "rs") == false)
        #expect(registry.isSupported(fileExtension: "go") == false)
        #expect(registry.isSupported(fileExtension: "java") == false)
        #expect(registry.isSupported(fileExtension: "") == false)
    }

    @Test("supportedExtensions contains all expected extensions")
    func supportedExtensionsComplete() {
        let registry = LanguageRegistry()
        let extensions = registry.supportedExtensions

        // Swift
        #expect(extensions.contains("swift"))

        // JavaScript
        #expect(extensions.contains("js"))
        #expect(extensions.contains("jsx"))
        #expect(extensions.contains("mjs"))
        #expect(extensions.contains("cjs"))

        // TypeScript
        #expect(extensions.contains("ts"))
        #expect(extensions.contains("tsx"))

        // Python
        #expect(extensions.contains("py"))
        #expect(extensions.contains("pyw"))

        // JSON
        #expect(extensions.contains("json"))
        #expect(extensions.contains("jsonc"))

        // Markdown
        #expect(extensions.contains("md"))
        #expect(extensions.contains("markdown"))
    }

    // MARK: - Preload Tests

    @Test("Preload loads all configurations")
    func preloadAllConfigurations() {
        let registry = LanguageRegistry()

        // Initially no configurations are cached
        #expect(registry.cachedLanguages.isEmpty)

        // Preload all
        registry.preloadAllConfigurations()

        // All languages should be cached
        #expect(registry.cachedLanguages.count == SupportedLanguage.allCases.count)
    }

    // MARK: - Shared Instance Tests

    @Test("Shared instance is accessible")
    func sharedInstanceExists() {
        let shared = LanguageRegistry.shared
        #expect(shared.supportedExtensions.contains("swift"))
    }
}

@Suite("SyntaxLanguageConfiguration Tests")
struct SyntaxLanguageConfigurationTests {

    @Test("Creates configuration for each supported language")
    func createForAllLanguages() throws {
        for language in SupportedLanguage.allCases {
            let config = try SyntaxLanguageConfiguration.create(for: language)
            #expect(config.language == language)
        }
    }

    @Test("Creates configuration from file extension")
    func createFromExtension() throws {
        let config = try SyntaxLanguageConfiguration.create(forExtension: "swift")
        #expect(config.language == .swift)
    }

    @Test("Throws for unsupported extension")
    func throwsForUnsupportedExtension() {
        #expect(throws: LanguageConfigurationError.self) {
            _ = try SyntaxLanguageConfiguration.create(forExtension: "rs")
        }
    }
}

@Suite("LanguageConfigurationError Tests")
struct LanguageConfigurationErrorTests {

    @Test("languageInitializationFailed error description contains language name")
    func languageInitializationFailedDescription() {
        let error = LanguageConfigurationError.languageInitializationFailed(.swift)

        #expect(error.errorDescription?.contains("Swift") == true)
        #expect(error.errorDescription?.contains("initialize") == true)
    }

    @Test("unsupportedLanguage error description contains extension")
    func unsupportedLanguageDescription() {
        let error = LanguageConfigurationError.unsupportedLanguage("rs")

        #expect(error.errorDescription?.contains("rs") == true)
        #expect(error.errorDescription?.contains("Unsupported") == true)
    }

    @Test("queryLoadFailed error description contains language and underlying error")
    func queryLoadFailedDescription() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test underlying error" }
        }

        let error = LanguageConfigurationError.queryLoadFailed(.python, underlying: TestError())

        #expect(error.errorDescription?.contains("Python") == true)
        #expect(error.errorDescription?.contains("query") == true)
        #expect(error.errorDescription?.contains("Test underlying error") == true)
    }

    @Test("All error cases have non-nil descriptions")
    func allErrorsHaveDescriptions() {
        struct DummyError: Error {}

        let errors: [LanguageConfigurationError] = [
            .languageInitializationFailed(.swift),
            .queryLoadFailed(.javascript, underlying: DummyError()),
            .unsupportedLanguage("unknown")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
