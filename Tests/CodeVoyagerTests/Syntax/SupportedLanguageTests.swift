import Foundation
import Testing
@testable import CodeVoyager

@Suite("SupportedLanguage Tests")
struct SupportedLanguageTests {

    // MARK: - Display Properties Tests

    @Test("SupportedLanguage has correct display names")
    func displayNames() {
        #expect(SupportedLanguage.swift.displayName == "Swift")
        #expect(SupportedLanguage.javascript.displayName == "JavaScript")
        #expect(SupportedLanguage.typescript.displayName == "TypeScript")
        #expect(SupportedLanguage.tsx.displayName == "TypeScript")
        #expect(SupportedLanguage.python.displayName == "Python")
        #expect(SupportedLanguage.json.displayName == "JSON")
        #expect(SupportedLanguage.markdown.displayName == "Markdown")
    }

    @Test("SupportedLanguage has correct icon names")
    func iconNames() {
        // 所有图标名称均为 macOS 14+ 支持的官方 SF Symbol
        #expect(SupportedLanguage.swift.iconName == "swift")
        #expect(SupportedLanguage.javascript.iconName == "j.square")
        #expect(SupportedLanguage.typescript.iconName == "t.square")
        #expect(SupportedLanguage.tsx.iconName == "t.square")
        #expect(SupportedLanguage.python.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(SupportedLanguage.json.iconName == "curlybraces")
        #expect(SupportedLanguage.markdown.iconName == "doc.richtext")
    }

    @Test("SupportedLanguage has correct Tree-sitter language names")
    func treeSitterLanguageNames() {
        #expect(SupportedLanguage.swift.treeSitterLanguageName == "swift")
        #expect(SupportedLanguage.javascript.treeSitterLanguageName == "javascript")
        #expect(SupportedLanguage.typescript.treeSitterLanguageName == "typescript")
        #expect(SupportedLanguage.tsx.treeSitterLanguageName == "tsx")
        #expect(SupportedLanguage.python.treeSitterLanguageName == "python")
        #expect(SupportedLanguage.json.treeSitterLanguageName == "json")
        #expect(SupportedLanguage.markdown.treeSitterLanguageName == "markdown")
    }

    @Test("SupportedLanguage has correct queries bundle names")
    func queriesBundleNames() {
        #expect(SupportedLanguage.swift.queriesBundleName == "TreeSitterLanguages_TreeSitterSwiftQueries")
        #expect(SupportedLanguage.javascript.queriesBundleName == "TreeSitterLanguages_TreeSitterJavaScriptQueries")
        #expect(SupportedLanguage.typescript.queriesBundleName == "TreeSitterLanguages_TreeSitterTypeScriptQueries")
        #expect(SupportedLanguage.tsx.queriesBundleName == "TreeSitterLanguages_TreeSitterTSXQueries")
        #expect(SupportedLanguage.python.queriesBundleName == "TreeSitterLanguages_TreeSitterPythonQueries")
        #expect(SupportedLanguage.json.queriesBundleName == "TreeSitterLanguages_TreeSitterJSONQueries")
        #expect(SupportedLanguage.markdown.queriesBundleName == "TreeSitterLanguages_TreeSitterMarkdownQueries")
    }

    // MARK: - File Extension Mapping Tests

    @Test("SupportedLanguage returns correct file extensions")
    func fileExtensions() {
        #expect(SupportedLanguage.swift.fileExtensions == ["swift"])
        #expect(SupportedLanguage.javascript.fileExtensions == ["js", "jsx", "mjs", "cjs"])
        #expect(SupportedLanguage.typescript.fileExtensions == ["ts"])
        #expect(SupportedLanguage.tsx.fileExtensions == ["tsx"])
        #expect(SupportedLanguage.python.fileExtensions == ["py", "pyw"])
        #expect(SupportedLanguage.json.fileExtensions == ["json", "jsonc"])
        #expect(SupportedLanguage.markdown.fileExtensions == ["md", "markdown"])
    }

    // MARK: - Detection from Extension Tests

    @Test("Detects Swift from extension")
    func detectSwift() {
        #expect(SupportedLanguage.detect(from: "swift") == .swift)
        #expect(SupportedLanguage.detect(from: "SWIFT") == .swift)
        #expect(SupportedLanguage.detect(from: "Swift") == .swift) // 混合大小写
    }

    @Test("Detects JavaScript from all extensions")
    func detectJavaScript() {
        #expect(SupportedLanguage.detect(from: "js") == .javascript)
        #expect(SupportedLanguage.detect(from: "jsx") == .javascript)
        #expect(SupportedLanguage.detect(from: "mjs") == .javascript)
        #expect(SupportedLanguage.detect(from: "cjs") == .javascript)
        #expect(SupportedLanguage.detect(from: "JS") == .javascript)
    }

    @Test("Detects TypeScript from extension")
    func detectTypeScript() {
        #expect(SupportedLanguage.detect(from: "ts") == .typescript)
        #expect(SupportedLanguage.detect(from: "TS") == .typescript)
    }

    @Test("Detects TSX from extension")
    func detectTSX() {
        #expect(SupportedLanguage.detect(from: "tsx") == .tsx)
        #expect(SupportedLanguage.detect(from: "TSX") == .tsx)
    }

    @Test("Detects Python from all extensions")
    func detectPython() {
        #expect(SupportedLanguage.detect(from: "py") == .python)
        #expect(SupportedLanguage.detect(from: "pyw") == .python)
        #expect(SupportedLanguage.detect(from: "PY") == .python)
        #expect(SupportedLanguage.detect(from: "PyW") == .python) // 混合大小写
        #expect(SupportedLanguage.detect(from: "Py") == .python) // 混合大小写
    }

    @Test("Detects JSON from all extensions")
    func detectJSON() {
        #expect(SupportedLanguage.detect(from: "json") == .json)
        #expect(SupportedLanguage.detect(from: "jsonc") == .json)
        #expect(SupportedLanguage.detect(from: "JSON") == .json)
    }

    @Test("Detects Markdown from all extensions")
    func detectMarkdown() {
        #expect(SupportedLanguage.detect(from: "md") == .markdown)
        #expect(SupportedLanguage.detect(from: "markdown") == .markdown)
        #expect(SupportedLanguage.detect(from: "MD") == .markdown)
    }

    @Test("Returns nil for unsupported extensions")
    func detectUnsupported() {
        #expect(SupportedLanguage.detect(from: "rs") == nil)
        #expect(SupportedLanguage.detect(from: "go") == nil)
        #expect(SupportedLanguage.detect(from: "java") == nil)
        #expect(SupportedLanguage.detect(from: "cpp") == nil)
        #expect(SupportedLanguage.detect(from: "txt") == nil)
        #expect(SupportedLanguage.detect(from: "") == nil)
    }

    // MARK: - Detection from URL Tests

    @Test("Detects language from URL")
    func detectFromURL() {
        let swiftURL = URL(fileURLWithPath: "/path/to/App.swift")
        #expect(SupportedLanguage.detect(from: swiftURL) == .swift)

        let jsURL = URL(fileURLWithPath: "/project/src/index.js")
        #expect(SupportedLanguage.detect(from: jsURL) == .javascript)

        let tsxURL = URL(fileURLWithPath: "/components/Button.tsx")
        #expect(SupportedLanguage.detect(from: tsxURL) == .tsx)
    }

    @Test("Returns nil for URL without extension")
    func detectFromURLWithoutExtension() {
        let noExtURL = URL(fileURLWithPath: "/path/to/Makefile")
        #expect(SupportedLanguage.detect(from: noExtURL) == nil)
    }

    @Test("Returns nil for URL with unsupported extension")
    func detectFromURLUnsupported() {
        let rustURL = URL(fileURLWithPath: "/path/to/main.rs")
        #expect(SupportedLanguage.detect(from: rustURL) == nil)
    }

    // MARK: - Case Iterable Tests

    @Test("All languages are iterable")
    func allCases() {
        let allLanguages = SupportedLanguage.allCases
        #expect(allLanguages.count == 7)
        #expect(allLanguages.contains(.swift))
        #expect(allLanguages.contains(.javascript))
        #expect(allLanguages.contains(.typescript))
        #expect(allLanguages.contains(.tsx))
        #expect(allLanguages.contains(.python))
        #expect(allLanguages.contains(.json))
        #expect(allLanguages.contains(.markdown))
    }
}
