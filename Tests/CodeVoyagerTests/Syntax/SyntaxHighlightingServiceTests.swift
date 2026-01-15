import Foundation
import Testing
import AppKit
@testable import CodeVoyager

// MARK: - SyntaxHighlightingService Tests

/// SyntaxHighlightingService 测试套件
///
/// 测试范围：
/// - 初始化和依赖注入
/// - 语言检测功能
/// - 缓存清理功能
/// - 错误类型
///
/// ## 测试限制
/// 由于 `createSession` 需要真实的 STTextView 实例和 Neon Highlighter，
/// 完整的集成测试需要在 UI 测试中进行。这里只测试不依赖 UI 组件的功能。
@Suite("SyntaxHighlightingService Tests")
@MainActor
struct SyntaxHighlightingServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with default dependencies")
    func initializesWithDefaults() {
        let service = SyntaxHighlightingService()

        #expect(service.languageRegistry is LanguageRegistry)
        #expect(service.themeManager is ThemeManager)
    }

    @Test("Service initializes with custom dependencies")
    func initializesWithCustomDependencies() {
        let registry = LanguageRegistry()
        let themeManager = ThemeManager()

        let service = SyntaxHighlightingService(
            languageRegistry: registry,
            themeManager: themeManager
        )

        // 验证注入的依赖是正确的类型实例
        #expect(service.languageRegistry is LanguageRegistry)
        #expect(service.themeManager is ThemeManager)
    }

    @Test("Service initializes with custom cache capacity")
    func initializesWithCustomCacheCapacity() {
        let service = SyntaxHighlightingService(cacheCapacity: 5)

        // 由于没有公开的 cacheCapacity 属性，我们通过 LRU 行为间接验证
        #expect(service.lruCacheCount == 0)
    }

    // MARK: - Language Detection Tests

    @Test("detectLanguage returns correct language for Swift file")
    func detectSwiftLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.swift")

        let language = service.detectLanguage(for: url)

        #expect(language == .swift)
    }

    @Test("detectLanguage returns correct language for JavaScript file")
    func detectJavaScriptLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.js")

        let language = service.detectLanguage(for: url)

        #expect(language == .javascript)
    }

    @Test("detectLanguage returns correct language for TypeScript file")
    func detectTypeScriptLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.ts")

        let language = service.detectLanguage(for: url)

        #expect(language == .typescript)
    }

    @Test("detectLanguage returns correct language for TSX file")
    func detectTSXLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.tsx")

        let language = service.detectLanguage(for: url)

        #expect(language == .tsx)
    }

    @Test("detectLanguage returns correct language for Python file")
    func detectPythonLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.py")

        let language = service.detectLanguage(for: url)

        #expect(language == .python)
    }

    @Test("detectLanguage returns correct language for JSON file")
    func detectJSONLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.json")

        let language = service.detectLanguage(for: url)

        #expect(language == .json)
    }

    @Test("detectLanguage returns correct language for Markdown file")
    func detectMarkdownLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.md")

        let language = service.detectLanguage(for: url)

        #expect(language == .markdown)
    }

    @Test("detectLanguage returns nil for unsupported extension")
    func detectUnsupportedLanguage() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.rs")

        let language = service.detectLanguage(for: url)

        #expect(language == nil)
    }

    @Test("detectLanguage returns nil for file without extension")
    func detectLanguageNoExtension() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/Makefile")

        let language = service.detectLanguage(for: url)

        #expect(language == nil)
    }

    // MARK: - Initial State Tests

    @Test("Service starts with empty caches")
    func startsWithEmptyCaches() {
        let service = SyntaxHighlightingService()

        #expect(service.activeSessionCount == 0)
        #expect(service.lruCacheCount == 0)
        #expect(service.clientCacheCount == 0)
    }

    // MARK: - clearAllCaches Tests

    @Test("clearAllCaches clears all internal caches")
    func clearAllCachesWorks() {
        let service = SyntaxHighlightingService()

        // 初始状态应为空
        #expect(service.activeSessionCount == 0)
        #expect(service.lruCacheCount == 0)
        #expect(service.clientCacheCount == 0)

        // 调用清理（即使为空也不应崩溃）
        service.clearAllCaches()

        // 仍然为空
        #expect(service.activeSessionCount == 0)
        #expect(service.lruCacheCount == 0)
        #expect(service.clientCacheCount == 0)
    }

    // MARK: - Graceful Degradation Tests

    @Test("releaseSession for non-existent URL does not crash")
    func releaseNonExistentSession() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/non/existent/file.swift")

        // 释放不存在的会话不应崩溃
        service.releaseSession(for: url)

        #expect(service.activeSessionCount == 0)
    }

    @Test("updateContent for non-existent session does not crash")
    func updateNonExistentSession() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/non/existent/file.swift")

        // 更新不存在的会话不应崩溃
        service.updateContent(
            for: url,
            newContent: "let x = 1",
            previousContentLength: 0
        )

        #expect(service.activeSessionCount == 0)
    }

    // MARK: - hasActiveSession Tests

    @Test("hasActiveSession returns false for unknown URL")
    func hasActiveSessionFalseForUnknown() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.swift")

        #expect(service.hasActiveSession(for: url) == false)
    }

    // MARK: - hasCachedSession Tests

    @Test("hasCachedSession returns false for unknown URL")
    func hasCachedSessionFalseForUnknown() {
        let service = SyntaxHighlightingService()
        let url = URL(fileURLWithPath: "/path/to/file.swift")

        #expect(service.hasCachedSession(for: url) == false)
    }
}

// MARK: - SyntaxHighlightingError Tests

@Suite("SyntaxHighlightingError Tests")
struct SyntaxHighlightingErrorTests {

    @Test("unsupportedLanguage error has correct description")
    func unsupportedLanguageDescription() {
        let error = SyntaxHighlightingError.unsupportedLanguage("rs")

        let description = error.errorDescription ?? ""
        #expect(description.contains("rs"))
        #expect(description.contains("support") || description.contains("支持"))
    }

    @Test("configurationFailed error has correct description")
    func configurationFailedDescription() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = SyntaxHighlightingError.configurationFailed(.swift, underlyingError)

        let description = error.errorDescription ?? ""
        #expect(description.contains("Swift") || description.contains("swift"))
    }

    @Test("queryNotAvailable error has correct description")
    func queryNotAvailableDescription() {
        let error = SyntaxHighlightingError.queryNotAvailable(.python)

        let description = error.errorDescription ?? ""
        #expect(description.contains("Python") || description.contains("python") || description.contains("query") || description.contains("Query"))
    }

    @Test("clientCreationFailed error has correct description")
    func clientCreationFailedDescription() {
        let underlyingError = NSError(domain: "test", code: 2, userInfo: nil)
        let error = SyntaxHighlightingError.clientCreationFailed(.javascript, underlyingError)

        let description = error.errorDescription ?? ""
        #expect(description.contains("JavaScript") || description.contains("javascript") || description.contains("client") || description.contains("Client"))
    }

    @Test("All error cases have non-empty descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [SyntaxHighlightingError] = [
            .unsupportedLanguage("test"),
            .configurationFailed(.swift, NSError(domain: "test", code: 1)),
            .queryNotAvailable(.python),
            .clientCreationFailed(.json, NSError(domain: "test", code: 2))
        ]

        for error in errors {
            let description = error.errorDescription ?? ""
            #expect(!description.isEmpty, "Error \(error) should have a non-empty description")
        }
    }
}

// MARK: - HighlightingContext Tests

@Suite("HighlightingContext Tests")
struct HighlightingContextTests {

    @Test("HighlightingContext initializes with all properties")
    func contextInitialization() {
        let url = URL(fileURLWithPath: "/path/to/file.swift")
        let language = SupportedLanguage.swift
        let content = "let x = 1"

        let context = HighlightingContext(
            fileURL: url,
            language: language,
            content: content
        )

        #expect(context.fileURL == url)
        #expect(context.language == language)
        #expect(context.content == content)
    }

    @Test("HighlightingContext with empty content")
    func contextWithEmptyContent() {
        let url = URL(fileURLWithPath: "/path/to/empty.swift")
        let context = HighlightingContext(
            fileURL: url,
            language: .swift,
            content: ""
        )

        #expect(context.content.isEmpty)
    }

    @Test("HighlightingContext with multiline content")
    func contextWithMultilineContent() {
        let content = """
        import Foundation

        func hello() {
            print("Hello, World!")
        }
        """

        let context = HighlightingContext(
            fileURL: URL(fileURLWithPath: "/path/to/hello.swift"),
            language: .swift,
            content: content
        )

        #expect(context.content.contains("import"))
        #expect(context.content.contains("func"))
    }
}
