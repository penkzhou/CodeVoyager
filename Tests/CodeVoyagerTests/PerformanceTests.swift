import XCTest
@testable import CodeVoyager

// MARK: - Performance Tests

/// 性能测试套件
///
/// 使用 XCTest 的 measure() 方法对关键场景进行性能基准测试。
/// 测试覆盖：
/// - 大文件加载性能
/// - 语法高亮配置加载性能
/// - 语言检测性能
/// - 文件系统操作性能
///
/// ## 性能目标（参考 CLAUDE.md）
/// - 内存: < 200MB 正常使用
/// - 冷启动: < 2 秒
/// - 大文件: 10000+ 行必须平滑滚动
///
/// ## 运行方式
/// ```bash
/// xcodebuild test -scheme CodeVoyager -destination 'platform=macOS' \
///     -only-testing:CodeVoyagerTests/LargeFilePerformanceTests
/// ```
final class LargeFilePerformanceTests: XCTestCase {

    // MARK: - Test Fixtures

    /// 生成指定行数的模拟 Swift 代码
    /// - Parameter lineCount: 行数
    /// - Returns: 生成的代码字符串
    private func generateSwiftCode(lineCount: Int) -> String {
        var lines: [String] = []
        lines.reserveCapacity(lineCount)

        // 文件头部
        lines.append("import Foundation")
        lines.append("import SwiftUI")
        lines.append("")

        // 生成类和方法
        var currentLine = 3
        var classIndex = 0

        while currentLine < lineCount {
            // 类声明
            lines.append("/// Class documentation for TestClass\(classIndex)")
            lines.append("final class TestClass\(classIndex) {")
            currentLine += 2

            // 属性
            for propIndex in 0..<5 where currentLine < lineCount {
                lines.append("    private var property\(propIndex): String = \"value\(propIndex)\"")
                currentLine += 1
            }

            lines.append("")
            currentLine += 1

            // 方法
            for methodIndex in 0..<10 where currentLine < lineCount {
                lines.append("    /// Method documentation")
                lines.append("    func method\(methodIndex)(param: Int) -> String {")
                lines.append("        let result = \"Processing \\(param)\"")
                lines.append("        guard param > 0 else { return \"\" }")
                lines.append("        return result")
                lines.append("    }")
                lines.append("")
                currentLine += 7
            }

            lines.append("}")
            lines.append("")
            currentLine += 2
            classIndex += 1
        }

        return lines.prefix(lineCount).joined(separator: "\n")
    }

    /// 生成指定行数的模拟 JavaScript 代码
    private func generateJavaScriptCode(lineCount: Int) -> String {
        var lines: [String] = []
        lines.reserveCapacity(lineCount)

        lines.append("'use strict';")
        lines.append("")
        lines.append("const config = require('./config');")
        lines.append("")

        var currentLine = 4
        var funcIndex = 0

        while currentLine < lineCount {
            lines.append("/**")
            lines.append(" * Function documentation for function\(funcIndex)")
            lines.append(" * @param {Object} options - The options object")
            lines.append(" * @returns {Promise<string>} The result")
            lines.append(" */")
            lines.append("async function processData\(funcIndex)(options) {")
            lines.append("    const { input, output } = options;")
            lines.append("    ")
            lines.append("    try {")
            lines.append("        const result = await fetch(input);")
            lines.append("        const data = await result.json();")
            lines.append("        return JSON.stringify(data);")
            lines.append("    } catch (error) {")
            lines.append("        console.error('Error:', error.message);")
            lines.append("        throw error;")
            lines.append("    }")
            lines.append("}")
            lines.append("")
            currentLine += 18
            funcIndex += 1
        }

        lines.append("module.exports = { processData0 };")
        return lines.prefix(lineCount).joined(separator: "\n")
    }

    // MARK: - Large File Loading Tests

    /// 测试 10,000 行文件的字符串处理性能
    func testStringProcessing_10000Lines() throws {
        let content = generateSwiftCode(lineCount: 10_000)

        measure {
            // 模拟文件内容处理
            let lines = content.components(separatedBy: .newlines)
            _ = lines.count
        }
    }

    /// 测试 50,000 行文件的字符串处理性能
    func testStringProcessing_50000Lines() throws {
        let content = generateSwiftCode(lineCount: 50_000)

        measure {
            let lines = content.components(separatedBy: .newlines)
            _ = lines.count
        }
    }

    /// 测试 100,000 行文件的字符串处理性能
    func testStringProcessing_100000Lines() throws {
        let content = generateSwiftCode(lineCount: 100_000)

        measure {
            let lines = content.components(separatedBy: .newlines)
            _ = lines.count
        }
    }

    // MARK: - Line Counting Performance

    /// 测试行数统计性能 - 使用 split 方法
    func testLineCount_Split_10000Lines() throws {
        let content = generateSwiftCode(lineCount: 10_000)

        measure {
            _ = content.split(separator: "\n", omittingEmptySubsequences: false).count
        }
    }

    /// 测试行数统计性能 - 使用 enumerateLines
    func testLineCount_Enumerate_10000Lines() throws {
        let content = generateSwiftCode(lineCount: 10_000)

        measure {
            var count = 0
            content.enumerateLines { _, _ in
                count += 1
            }
            _ = count
        }
    }

    /// 测试行数统计性能 - 使用 UTF8 直接计数
    func testLineCount_UTF8_10000Lines() throws {
        let content = generateSwiftCode(lineCount: 10_000)

        measure {
            var count = 1 // 至少一行
            for byte in content.utf8 where byte == 0x0A {  // '\n'
                count += 1
            }
            _ = count
        }
    }

    // MARK: - Memory Allocation Tests

    /// 测试大字符串内存分配
    func testMemoryAllocation_LargeString() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                let content = generateSwiftCode(lineCount: 50_000)
                _ = content.utf16.count
            }
        }
    }

    /// 测试多文件内存累积
    func testMemoryAllocation_MultipleFiles() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                var contents: [String] = []
                for _ in 0..<10 {
                    contents.append(generateSwiftCode(lineCount: 5_000))
                }
                _ = contents.count
            }
        }
    }
}

// MARK: - Language Detection Performance Tests

final class LanguageDetectionPerformanceTests: XCTestCase {

    /// 测试语言检测性能 - 通过扩展名
    func testLanguageDetection_ByExtension() throws {
        let extensions = ["swift", "js", "ts", "tsx", "py", "json", "md", "swift", "js", "ts"]

        measure {
            for ext in extensions {
                _ = SupportedLanguage.detect(from: ext)
            }
        }
    }

    /// 测试语言检测性能 - 通过文件 URL
    func testLanguageDetection_ByURL() throws {
        let urls = [
            URL(fileURLWithPath: "/test/file.swift"),
            URL(fileURLWithPath: "/test/file.js"),
            URL(fileURLWithPath: "/test/file.ts"),
            URL(fileURLWithPath: "/test/file.tsx"),
            URL(fileURLWithPath: "/test/file.py"),
            URL(fileURLWithPath: "/test/file.json"),
            URL(fileURLWithPath: "/test/file.md"),
            URL(fileURLWithPath: "/test/nested/deep/file.swift"),
            URL(fileURLWithPath: "/test/nested/deep/file.js"),
            URL(fileURLWithPath: "/test/nested/deep/file.ts"),
        ]

        measure {
            for url in urls {
                _ = SupportedLanguage.detect(from: url.pathExtension)
            }
        }
    }

    /// 测试批量语言检测（1000 个文件）
    func testLanguageDetection_Batch1000() throws {
        // 使用支持的扩展名 + 一些不支持的扩展名（测试未匹配路径）
        let extensions = ["swift", "js", "ts", "tsx", "py", "json", "md", "jsx", "mjs", "markdown"]
        var urls: [URL] = []
        for i in 0..<1000 {
            let ext = extensions[i % extensions.count]
            urls.append(URL(fileURLWithPath: "/test/file\(i).\(ext)"))
        }

        measure {
            for url in urls {
                _ = SupportedLanguage.detect(from: url.pathExtension)
            }
        }
    }
}

// MARK: - Language Configuration Performance Tests

@MainActor
final class LanguageConfigurationPerformanceTests: XCTestCase {

    private var registry: LanguageRegistry!

    override func setUp() {
        super.setUp()
        registry = LanguageRegistry()
    }

    override func tearDown() {
        registry.clearCache()
        registry = nil
        super.tearDown()
    }

    /// 测试语言配置首次加载性能（冷启动）
    func testConfigurationLoad_ColdStart() throws {
        measure {
            registry.clearCache()
            _ = try? registry.configuration(for: .swift)
        }
    }

    /// 测试语言配置缓存命中性能（热启动）
    func testConfigurationLoad_CacheHit() throws {
        // 预热缓存
        _ = try? registry.configuration(for: .swift)

        measure {
            _ = try? registry.configuration(for: .swift)
        }
    }

    /// 测试预加载所有语言配置
    func testPreloadAllConfigurations() throws {
        measure {
            registry.clearCache()
            registry.preloadAllConfigurations()
        }
    }

    /// 测试多语言配置顺序加载
    func testConfigurationLoad_MultipleLanguages() throws {
        let languages: [SupportedLanguage] = [.swift, .javascript, .typescript, .tsx, .python, .json, .markdown]

        measure {
            registry.clearCache()
            for language in languages {
                _ = try? registry.configuration(for: language)
            }
        }
    }
}

// MARK: - File Content Processing Performance Tests

final class FileContentProcessingPerformanceTests: XCTestCase {

    // MARK: - Test Fixtures

    private func generateContent(lineCount: Int) -> String {
        (0..<lineCount).map { "Line \($0): Some content here with various characters äöü 中文" }.joined(separator: "\n")
    }

    // MARK: - Line Ending Detection

    /// 测试行尾符检测性能 - Unix (LF)
    func testLineEndingDetection_LF() throws {
        let content = generateContent(lineCount: 10_000)

        measure {
            _ = detectLineEnding(in: content)
        }
    }

    /// 测试行尾符检测性能 - Windows (CRLF)
    func testLineEndingDetection_CRLF() throws {
        let content = generateContent(lineCount: 10_000).replacingOccurrences(of: "\n", with: "\r\n")

        measure {
            _ = detectLineEnding(in: content)
        }
    }

    /// 检测行尾符类型
    private func detectLineEnding(in content: String) -> LineEnding {
        let hasCRLF = content.contains("\r\n")
        let hasCR = content.contains("\r") && !hasCRLF
        let hasLF = content.contains("\n") && !hasCRLF

        if (hasCRLF && hasLF) || (hasCRLF && hasCR) || (hasLF && hasCR) {
            return .mixed
        } else if hasCRLF {
            return .crlf
        }
        return .lf
    }

    // MARK: - UTF-16 Count (for Neon/Tree-sitter)

    /// 测试 UTF-16 长度计算性能
    func testUTF16Count_10000Lines() throws {
        let content = generateContent(lineCount: 10_000)

        measure {
            _ = content.utf16.count
        }
    }

    /// 测试 UTF-16 长度计算性能 - 大文件
    func testUTF16Count_50000Lines() throws {
        let content = generateContent(lineCount: 50_000)

        measure {
            _ = content.utf16.count
        }
    }

    // MARK: - NSRange Conversion

    /// 测试 NSRange 转换性能
    func testNSRangeConversion_10000Lines() throws {
        let content = generateContent(lineCount: 10_000)
        let nsString = content as NSString

        measure {
            // 模拟随机范围转换
            for i in stride(from: 0, to: min(1000, nsString.length - 100), by: 100) {
                _ = NSRange(location: i, length: 50)
            }
        }
    }
}

// MARK: - File Tree Performance Tests

final class FileTreePerformanceTests: XCTestCase {

    // MARK: - Test Fixtures

    private func createMockFileTree(depth: Int, breadth: Int) -> FileNode {
        func createNode(name: String, depth: Int, isDirectory: Bool) -> FileNode {
            let url = URL(fileURLWithPath: "/mock/\(name)")

            if isDirectory && depth > 0 {
                var children: [FileNode] = []
                // 添加子目录
                for i in 0..<(breadth / 2) {
                    children.append(createNode(name: "\(name)_dir\(i)", depth: depth - 1, isDirectory: true))
                }
                // 添加文件
                for i in 0..<(breadth / 2) {
                    children.append(createNode(name: "\(name)_file\(i).swift", depth: 0, isDirectory: false))
                }
                return FileNode(url: url, children: children)
            } else if isDirectory {
                // 空目录
                return FileNode(url: url, children: [])
            } else {
                // 文件（children = nil）
                return FileNode(url: url, children: nil)
            }
        }

        return createNode(name: "root", depth: depth, isDirectory: true)
    }

    /// 测试文件树遍历性能 - 小型项目（约 100 个节点）
    func testFileTreeTraversal_SmallProject() throws {
        let root = createMockFileTree(depth: 3, breadth: 4)

        measure {
            _ = countNodes(root)
        }
    }

    /// 测试文件树遍历性能 - 中型项目（约 1000 个节点）
    func testFileTreeTraversal_MediumProject() throws {
        let root = createMockFileTree(depth: 4, breadth: 6)

        measure {
            _ = countNodes(root)
        }
    }

    /// 测试文件树遍历性能 - 大型项目（约 5000 个节点）
    func testFileTreeTraversal_LargeProject() throws {
        let root = createMockFileTree(depth: 5, breadth: 6)

        measure {
            _ = countNodes(root)
        }
    }

    private func countNodes(_ node: FileNode) -> Int {
        var count = 1
        if let children = node.children {
            for child in children {
                count += countNodes(child)
            }
        }
        return count
    }

    // MARK: - File Node Sorting Performance

    /// 测试文件节点排序性能
    func testFileNodeSorting_1000Nodes() throws {
        var nodes: [FileNode] = []
        for i in 0..<1000 {
            let isDir = i % 3 == 0
            let url = URL(fileURLWithPath: "/test/node\(i)\(isDir ? "" : ".swift")")
            // isDirectory 由 children 是否为 nil 决定
            nodes.append(FileNode(url: url, children: isDir ? [] : nil))
        }

        measure {
            _ = nodes.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    // MARK: - File Node Search Performance

    /// 测试文件节点搜索性能
    func testFileNodeSearch_DeepTree() throws {
        let root = createMockFileTree(depth: 5, breadth: 6)
        let targetName = "root_dir0_dir0_dir0_file1.swift"

        measure {
            _ = findNode(in: root, name: targetName)
        }
    }

    private func findNode(in node: FileNode, name: String) -> FileNode? {
        if node.name == name {
            return node
        }
        if let children = node.children {
            for child in children {
                if let found = findNode(in: child, name: name) {
                    return found
                }
            }
        }
        return nil
    }
}

// MARK: - Theme Performance Tests

@MainActor
final class ThemePerformanceTests: XCTestCase {

    /// 测试主题样式查询性能
    func testThemeStyleLookup() throws {
        let theme = DefaultThemes.light

        // 常见的 token 名称
        let tokenNames = [
            "keyword", "string", "comment", "type", "function",
            "variable", "number", "operator", "punctuation", "property"
        ]

        measure {
            for _ in 0..<1000 {
                for name in tokenNames {
                    _ = theme.style(for: name)
                }
            }
        }
    }

    /// 测试主题切换性能
    func testThemeSwitching() throws {
        let themes = [DefaultThemes.light, DefaultThemes.dark]

        measure {
            for i in 0..<100 {
                let theme = themes[i % 2]
                _ = theme.style(for: "keyword")
                _ = theme.style(for: "string")
                _ = theme.style(for: "comment")
            }
        }
    }
}

// MARK: - Baseline Metrics

/// 基准性能指标记录
///
/// 运行测试后，记录以下基准数据用于后续对比：
/// - testStringProcessing_10000Lines: 目标 < 50ms
/// - testStringProcessing_50000Lines: 目标 < 200ms
/// - testConfigurationLoad_ColdStart: 目标 < 100ms
/// - testFileTreeTraversal_LargeProject: 目标 < 10ms
///
/// ## 使用方式
/// 1. 运行所有性能测试
/// 2. 在 Xcode Test Report 中查看各测试的平均时间
/// 3. 设置 baseline（右键测试 → Set Baseline）
/// 4. 后续修改代码后，重新运行测试检查是否退化
