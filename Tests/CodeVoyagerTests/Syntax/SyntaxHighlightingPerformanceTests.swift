import Foundation
import Testing
@testable import CodeVoyager

/// 语法高亮性能测试套件
///
/// 测试大文件解析性能，确保满足项目性能目标：
/// - 10000+ 行文件应流畅处理
/// - 解析时间应在可接受范围内
///
/// ## 测试策略
/// 使用动态生成的测试内容，避免依赖外部资源文件。
/// 通过测量配置加载时间来间接验证性能。
@Suite("Syntax Highlighting Performance Tests")
struct SyntaxHighlightingPerformanceTests {

    // MARK: - Code Generation Helpers

    /// 语言特定的代码模板
    private struct LanguageTemplate {
        /// 文件头部内容
        let header: [String]
        /// 生成函数代码块
        /// - Parameters:
        ///   - functionIndex: 函数索引号
        /// - Returns: 函数的代码行数组
        let generateFunction: (_ functionIndex: Int) -> [String]
        /// 每个函数的行数（用于计数）
        let linesPerFunction: Int
    }

    /// Swift 语言模板
    private var swiftTemplate: LanguageTemplate {
        LanguageTemplate(
            header: ["import Foundation", ""],
            generateFunction: { index in
                let name = "function\(index)"
                return [
                    "/// Documentation for \(name)",
                    "/// - Parameter value: The input value",
                    "/// - Returns: The computed result",
                    "func \(name)(value: Int) -> Int {",
                    "    // Local variable declarations",
                    "    let multiplier = 2",
                    "    let offset = 10",
                    "    var result = value * multiplier",
                    "",
                    "    // Conditional logic",
                    "    if result > 100 {",
                    "        result = result - offset",
                    "    } else {",
                    "        result = result + offset",
                    "    }",
                    "",
                    "    // String interpolation",
                    "    let message = \"Result: \\(result)\"",
                    "    print(message)",
                    "",
                    "    return result",
                    "}",
                    ""
                ]
            },
            linesPerFunction: 23
        )
    }

    /// Python 语言模板
    private var pythonTemplate: LanguageTemplate {
        LanguageTemplate(
            header: [
                "#!/usr/bin/env python3",
                "\"\"\"Generated Python module for performance testing.\"\"\"",
                "",
                "import os",
                "import sys",
                ""
            ],
            generateFunction: { index in
                let name = "function_\(index)"
                return [
                    "def \(name)(value: int) -> int:",
                    "    \"\"\"",
                    "    Compute a result from the input value.",
                    "",
                    "    Args:",
                    "        value: The input integer value",
                    "",
                    "    Returns:",
                    "        The computed result",
                    "    \"\"\"",
                    "    multiplier = 2",
                    "    offset = 10",
                    "    result = value * multiplier",
                    "",
                    "    if result > 100:",
                    "        result = result - offset",
                    "    else:",
                    "        result = result + offset",
                    "",
                    "    message = f\"Result: {result}\"",
                    "    print(message)",
                    "",
                    "    return result",
                    "",
                    ""
                ]
            },
            linesPerFunction: 25
        )
    }

    /// JavaScript 语言模板
    private var javaScriptTemplate: LanguageTemplate {
        LanguageTemplate(
            header: [
                "// Generated JavaScript module for performance testing",
                "",
                "const MODULE_NAME = 'PerformanceTest';",
                ""
            ],
            generateFunction: { index in
                let name = "function\(index)"
                return [
                    "/**",
                    " * Compute a result from the input value.",
                    " * @param {number} value - The input value",
                    " * @returns {number} The computed result",
                    " */",
                    "function \(name)(value) {",
                    "    const multiplier = 2;",
                    "    const offset = 10;",
                    "    let result = value * multiplier;",
                    "",
                    "    if (result > 100) {",
                    "        result = result - offset;",
                    "    } else {",
                    "        result = result + offset;",
                    "    }",
                    "",
                    "    const message = `Result: ${result}`;",
                    "    console.log(message);",
                    "",
                    "    return result;",
                    "}",
                    ""
                ]
            },
            linesPerFunction: 22
        )
    }

    /// 使用模板生成指定行数的代码
    /// - Parameters:
    ///   - template: 语言模板
    ///   - lineCount: 目标行数
    /// - Returns: 生成的代码字符串
    private func generateCode(using template: LanguageTemplate, lineCount: Int) -> String {
        var lines = template.header
        var currentLine = template.header.count
        var functionIndex = 0

        while currentLine < lineCount {
            lines.append(contentsOf: template.generateFunction(functionIndex))
            currentLine += template.linesPerFunction
            functionIndex += 1
        }

        return lines.joined(separator: "\n")
    }

    /// 生成指定行数的 Swift 代码
    private func generateSwiftCode(lineCount: Int) -> String {
        generateCode(using: swiftTemplate, lineCount: lineCount)
    }

    /// 生成指定行数的 Python 代码
    private func generatePythonCode(lineCount: Int) -> String {
        generateCode(using: pythonTemplate, lineCount: lineCount)
    }

    /// 生成指定行数的 JavaScript 代码
    private func generateJavaScriptCode(lineCount: Int) -> String {
        generateCode(using: javaScriptTemplate, lineCount: lineCount)
    }

    // MARK: - Code Generation Tests

    @Test("Generate 1000 lines of Swift code")
    func generate1000LinesSwift() {
        let code = generateSwiftCode(lineCount: 1000)
        let lineCount = code.components(separatedBy: "\n").count

        #expect(lineCount >= 1000)
    }

    @Test("Generate 10000 lines of Swift code")
    func generate10000LinesSwift() {
        let code = generateSwiftCode(lineCount: 10000)
        let lineCount = code.components(separatedBy: "\n").count

        #expect(lineCount >= 10000)
    }

    @Test("Generate 1000 lines of Python code")
    func generate1000LinesPython() {
        let code = generatePythonCode(lineCount: 1000)
        let lineCount = code.components(separatedBy: "\n").count

        #expect(lineCount >= 1000)
    }

    @Test("Generate 1000 lines of JavaScript code")
    func generate1000LinesJavaScript() {
        let code = generateJavaScriptCode(lineCount: 1000)
        let lineCount = code.components(separatedBy: "\n").count

        #expect(lineCount >= 1000)
    }

    // MARK: - Language Configuration Performance Tests

    @Test("Swift configuration loads within acceptable time")
    func swiftConfigurationLoadTime() throws {
        let registry = LanguageRegistry()
        registry.clearCache()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try registry.configuration(for: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Swift 配置包含复杂的 Query 文件，首次加载可能需要较长时间
        // 在 CI 环境下允许更长时间（考虑到 Query 编译开销和系统负载）
        // 目标：< 60s（非常宽松，主要用于检测严重性能退化）
        #expect(elapsed < 60.0, "Swift configuration took \(elapsed)s, expected < 60.0s")
    }

    @Test("JavaScript configuration loads within acceptable time")
    func javaScriptConfigurationLoadTime() throws {
        let registry = LanguageRegistry()
        registry.clearCache()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try registry.configuration(for: .javascript)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(elapsed < 5.0, "JavaScript configuration took \(elapsed)s, expected < 5.0s")
    }

    @Test("Python configuration loads within acceptable time")
    func pythonConfigurationLoadTime() throws {
        let registry = LanguageRegistry()
        registry.clearCache()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try registry.configuration(for: .python)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(elapsed < 5.0, "Python configuration took \(elapsed)s, expected < 5.0s")
    }

    @Test("All configurations preload within acceptable time")
    func allConfigurationsPreloadTime() throws {
        let registry = LanguageRegistry()
        registry.clearCache()

        let startTime = CFAbsoluteTimeGetCurrent()
        registry.preloadAllConfigurations()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // 所有 7 种语言配置预加载时间
        // 在高负载环境下允许更长时间（考虑到 Query 编译开销）
        // 目标：< 120s（非常宽松，主要用于检测严重性能退化）
        #expect(elapsed < 120.0, "All configurations preload took \(elapsed)s, expected < 120.0s")
    }

    // MARK: - Cached Configuration Performance Tests

    @Test("Cached configuration retrieval is fast")
    func cachedConfigurationRetrievalTime() throws {
        let registry = LanguageRegistry()

        // 首次加载（可能较慢）
        _ = try registry.configuration(for: .swift)

        // 缓存读取应非常快
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try registry.configuration(for: .swift)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // 100 次缓存读取应在 100ms 内完成
        #expect(elapsed < 0.1, "100 cached retrievals took \(elapsed)s, expected < 0.1s")
    }

    // MARK: - HighlightingContext Performance Tests

    @Test("HighlightingContext creation with large content is fast")
    func highlightingContextCreationPerformance() {
        let largeContent = generateSwiftCode(lineCount: 10000)
        let url = URL(fileURLWithPath: "/test/large.swift")

        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            _ = HighlightingContext(
                fileURL: url,
                language: .swift,
                content: largeContent
            )
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // 10 次 Context 创建应在 100ms 内完成
        #expect(elapsed < 0.1, "10 context creations took \(elapsed)s, expected < 0.1s")
    }

    // MARK: - Memory Usage Estimation Tests

    @Test("Large Swift code generation does not exceed expected size")
    func largeSwiftCodeMemoryEstimate() {
        let code = generateSwiftCode(lineCount: 10000)
        let byteCount = code.utf8.count

        // 10000 行代码应小于 1MB
        let oneMB = 1024 * 1024
        #expect(byteCount < oneMB, "Generated code size \(byteCount) bytes exceeds 1MB")
    }

    @Test("Large Python code generation does not exceed expected size")
    func largePythonCodeMemoryEstimate() {
        let code = generatePythonCode(lineCount: 10000)
        let byteCount = code.utf8.count

        let oneMB = 1024 * 1024
        #expect(byteCount < oneMB, "Generated code size \(byteCount) bytes exceeds 1MB")
    }

    @Test("Large JavaScript code generation does not exceed expected size")
    func largeJavaScriptCodeMemoryEstimate() {
        let code = generateJavaScriptCode(lineCount: 10000)
        let byteCount = code.utf8.count

        let oneMB = 1024 * 1024
        #expect(byteCount < oneMB, "Generated code size \(byteCount) bytes exceeds 1MB")
    }
}
