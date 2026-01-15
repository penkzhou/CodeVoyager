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

    /// 生成指定行数的 Swift 代码
    /// - Parameter lineCount: 目标行数
    /// - Returns: 生成的 Swift 代码字符串
    private func generateSwiftCode(lineCount: Int) -> String {
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("")

        var currentLine = 2
        var functionIndex = 0

        while currentLine < lineCount {
            // 每个函数约 20 行
            let functionName = "function\(functionIndex)"
            lines.append("/// Documentation for \(functionName)")
            lines.append("/// - Parameter value: The input value")
            lines.append("/// - Returns: The computed result")
            lines.append("func \(functionName)(value: Int) -> Int {")
            lines.append("    // Local variable declarations")
            lines.append("    let multiplier = 2")
            lines.append("    let offset = 10")
            lines.append("    var result = value * multiplier")
            lines.append("")
            lines.append("    // Conditional logic")
            lines.append("    if result > 100 {")
            lines.append("        result = result - offset")
            lines.append("    } else {")
            lines.append("        result = result + offset")
            lines.append("    }")
            lines.append("")
            lines.append("    // String interpolation")
            lines.append("    let message = \"Result: \\(result)\"")
            lines.append("    print(message)")
            lines.append("")
            lines.append("    return result")
            lines.append("}")
            lines.append("")

            currentLine += 23
            functionIndex += 1
        }

        return lines.joined(separator: "\n")
    }

    /// 生成指定行数的 Python 代码
    /// - Parameter lineCount: 目标行数
    /// - Returns: 生成的 Python 代码字符串
    private func generatePythonCode(lineCount: Int) -> String {
        var lines: [String] = []
        lines.append("#!/usr/bin/env python3")
        lines.append("\"\"\"Generated Python module for performance testing.\"\"\"")
        lines.append("")
        lines.append("import os")
        lines.append("import sys")
        lines.append("")

        var currentLine = 6
        var functionIndex = 0

        while currentLine < lineCount {
            let functionName = "function_\(functionIndex)"
            lines.append("def \(functionName)(value: int) -> int:")
            lines.append("    \"\"\"")
            lines.append("    Compute a result from the input value.")
            lines.append("")
            lines.append("    Args:")
            lines.append("        value: The input integer value")
            lines.append("")
            lines.append("    Returns:")
            lines.append("        The computed result")
            lines.append("    \"\"\"")
            lines.append("    multiplier = 2")
            lines.append("    offset = 10")
            lines.append("    result = value * multiplier")
            lines.append("")
            lines.append("    if result > 100:")
            lines.append("        result = result - offset")
            lines.append("    else:")
            lines.append("        result = result + offset")
            lines.append("")
            lines.append("    message = f\"Result: {result}\"")
            lines.append("    print(message)")
            lines.append("")
            lines.append("    return result")
            lines.append("")
            lines.append("")

            currentLine += 25
            functionIndex += 1
        }

        return lines.joined(separator: "\n")
    }

    /// 生成指定行数的 JavaScript 代码
    /// - Parameter lineCount: 目标行数
    /// - Returns: 生成的 JavaScript 代码字符串
    private func generateJavaScriptCode(lineCount: Int) -> String {
        var lines: [String] = []
        lines.append("// Generated JavaScript module for performance testing")
        lines.append("")
        lines.append("const MODULE_NAME = 'PerformanceTest';")
        lines.append("")

        var currentLine = 4
        var functionIndex = 0

        while currentLine < lineCount {
            let functionName = "function\(functionIndex)"
            lines.append("/**")
            lines.append(" * Compute a result from the input value.")
            lines.append(" * @param {number} value - The input value")
            lines.append(" * @returns {number} The computed result")
            lines.append(" */")
            lines.append("function \(functionName)(value) {")
            lines.append("    const multiplier = 2;")
            lines.append("    const offset = 10;")
            lines.append("    let result = value * multiplier;")
            lines.append("")
            lines.append("    if (result > 100) {")
            lines.append("        result = result - offset;")
            lines.append("    } else {")
            lines.append("        result = result + offset;")
            lines.append("    }")
            lines.append("")
            lines.append("    const message = `Result: ${result}`;")
            lines.append("    console.log(message);")
            lines.append("")
            lines.append("    return result;")
            lines.append("}")
            lines.append("")

            currentLine += 22
            functionIndex += 1
        }

        return lines.joined(separator: "\n")
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
