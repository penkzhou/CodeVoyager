import Foundation
import Testing
@testable import CodeVoyager

@Suite("FileNode Tests")
struct FileNodeTests {
    @Test("FileNode identifies directories correctly")
    func isDirectory() {
        let directory = FileNode(
            url: URL(fileURLWithPath: "/test/folder"),
            children: []
        )
        #expect(directory.isDirectory == true)

        let file = FileNode(
            url: URL(fileURLWithPath: "/test/file.txt"),
            children: nil
        )
        #expect(file.isDirectory == false)
    }

    @Test("FileNode extracts name from URL")
    func name() {
        let node = FileNode(url: URL(fileURLWithPath: "/path/to/MyFile.swift"))
        #expect(node.name == "MyFile.swift")
    }

    @Test("FileNode extracts file extension correctly")
    func fileExtension() {
        let swiftFile = FileNode(url: URL(fileURLWithPath: "/test/App.swift"))
        #expect(swiftFile.fileExtension == "swift")

        let tsxFile = FileNode(url: URL(fileURLWithPath: "/test/Component.TSX"))
        #expect(tsxFile.fileExtension == "tsx")

        let directory = FileNode(
            url: URL(fileURLWithPath: "/test/folder"),
            children: []
        )
        #expect(directory.fileExtension == "")
    }

    @Test("FileNode returns correct SF Symbol icons for file types")
    func iconNames() {
        // Swift files
        let swiftFile = FileNode(url: URL(fileURLWithPath: "/test/App.swift"))
        #expect(swiftFile.iconName() == "swift")

        // JavaScript/TypeScript
        let jsFile = FileNode(url: URL(fileURLWithPath: "/test/app.js"))
        #expect(jsFile.iconName() == "curlybraces")

        let tsxFile = FileNode(url: URL(fileURLWithPath: "/test/Component.tsx"))
        #expect(tsxFile.iconName() == "curlybraces")

        // Images
        let pngFile = FileNode(url: URL(fileURLWithPath: "/test/image.png"))
        #expect(pngFile.iconName() == "photo")

        // Markdown
        let mdFile = FileNode(url: URL(fileURLWithPath: "/test/README.md"))
        #expect(mdFile.iconName() == "doc.richtext")

        // Shell scripts
        let shFile = FileNode(url: URL(fileURLWithPath: "/test/build.sh"))
        #expect(shFile.iconName() == "terminal")

        // Git files
        let gitignore = FileNode(url: URL(fileURLWithPath: "/test/.gitignore"))
        #expect(gitignore.iconName() == "arrow.triangle.branch")

        // Unknown type defaults to doc
        let unknownFile = FileNode(url: URL(fileURLWithPath: "/test/file.xyz"))
        #expect(unknownFile.iconName() == "doc")
    }

    @Test("FileNode directory icon changes based on expanded state parameter")
    func directoryIconState() {
        let directory = FileNode(
            url: URL(fileURLWithPath: "/test/folder"),
            children: []
        )

        // isExpanded is managed by ViewModel, passed as parameter
        #expect(directory.iconName(isExpanded: false) == "folder")
        #expect(directory.iconName(isExpanded: true) == "folder.fill")
    }
}

@Suite("FileContent Tests")
struct FileContentTests {
    @Test("FileContent calculates line count correctly")
    func lineCount() {
        let content = FileContent(
            path: "/test/file.txt",
            content: "Line 1\nLine 2\nLine 3"
        )
        #expect(content.lineCount == 3)
    }

    @Test("FileContent calculates line count for empty content")
    func lineCountEmpty() {
        let content = FileContent(
            path: "/test/empty.txt",
            content: ""
        )
        // Empty file should have 0 lines
        #expect(content.lineCount == 0)
    }

    @Test("FileContent calculates line count for single line without newline")
    func lineCountSingleLine() {
        let content = FileContent(
            path: "/test/single.txt",
            content: "Hello World"
        )
        #expect(content.lineCount == 1)
    }

    @Test("FileContent calculates line count for content ending with newline")
    func lineCountTrailingNewline() {
        let content = FileContent(
            path: "/test/trailing.txt",
            content: "Line 1\nLine 2\n"
        )
        // "Line 1\nLine 2\n" should be 2 lines (trailing newline doesn't add a line)
        #expect(content.lineCount == 2)
    }
    
    // 问题 7 修复: 添加更多边界情况测试
    // Note: components(separatedBy: .newlines) treats both \r and \n as newline characters separately
    
    @Test("FileContent calculates line count for only newline character")
    func lineCountOnlyNewline() {
        let content = FileContent(
            path: "/test/newline.txt",
            content: "\n"
        )
        // "\n" splits into ["", ""], trailing empty component removed = 1 line
        #expect(content.lineCount == 1)
    }
    
    @Test("FileContent calculates line count for multiple newlines")
    func lineCountMultipleNewlines() {
        let content = FileContent(
            path: "/test/empty-lines.txt",
            content: "\n\n\n"
        )
        // "\n\n\n" splits into ["", "", "", ""], trailing removed = 3 lines
        #expect(content.lineCount == 3)
    }
    
    @Test("FileContent calculates line count with only LF line endings")
    func lineCountLFOnly() {
        let content = FileContent(
            path: "/test/lf.txt",
            content: "Line 1\nLine 2\nLine 3"
        )
        #expect(content.lineCount == 3)
    }
    
    @Test("FileContent calculates line count for content with embedded CR")
    func lineCountWithCR() {
        // Note: .newlines treats \r as a separate newline character
        // This is a known limitation - CRLF files may report different line counts
        let content = FileContent(
            path: "/test/cr.txt",
            content: "Line 1\rLine 2"
        )
        // "\r" is treated as newline by .newlines
        #expect(content.lineCount == 2)
    }

    @Test("FileContent detects files over 50MB as too large")
    func isTooLarge() {
        let smallFile = FileContent(
            path: "/test/small.txt",
            fileSize: 1024 * 1024 // 1MB
        )
        #expect(smallFile.isTooLarge == false)

        let largeFile = FileContent(
            path: "/test/large.bin",
            fileSize: 51 * 1024 * 1024 // 51MB
        )
        #expect(largeFile.isTooLarge == true)

        let exactlyAtLimit = FileContent(
            path: "/test/edge.bin",
            fileSize: 50 * 1024 * 1024 // 50MB exactly
        )
        #expect(exactlyAtLimit.isTooLarge == false)
    }

    @Test("FileContent isBinary property")
    func isBinary() {
        let textFile = FileContent(
            path: "/test/file.txt",
            content: "Hello",
            isBinary: false
        )
        #expect(textFile.isBinary == false)

        let binaryFile = FileContent(
            path: "/test/image.png",
            isBinary: true
        )
        #expect(binaryFile.isBinary == true)
    }
}

@Suite("LineEnding Tests")
struct LineEndingTests {
    @Test("LineEnding has correct display symbols")
    func displaySymbols() {
        #expect(LineEnding.lf.displaySymbol == "↵")
        #expect(LineEnding.crlf.displaySymbol == "↵↵")
        #expect(LineEnding.mixed.displaySymbol == "⚠️")
    }
}
