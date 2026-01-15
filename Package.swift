// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeVoyager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CodeVoyager",
            targets: ["CodeVoyager"]
        )
    ],
    dependencies: [
        // Database for caching Git metadata
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),

        // Syntax Highlighting - Core
        .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.6"),
        .package(url: "https://github.com/ChimeHQ/Neon.git", exact: "0.5.1"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", .upToNextMinor(from: "0.7.1")),

        // Tree-sitter Language Grammars (consolidated package with all supported languages)
        .package(url: "https://github.com/simonbs/TreeSitterLanguages.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "CodeVoyager",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "STTextView", package: "STTextView"),
                .product(name: "Neon", package: "Neon"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                // Tree-sitter Language Parsers + Queries
                .product(name: "TreeSitterSwift", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSwiftQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaScript", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaScriptQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTypeScript", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTypeScriptQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTSX", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTSXQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPython", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPythonQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJSON", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJSONQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdown", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownInline", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownInlineQueries", package: "TreeSitterLanguages"),
            ],
            path: "Sources/CodeVoyager"
        ),
        .testTarget(
            name: "CodeVoyagerTests",
            dependencies: ["CodeVoyager"],
            path: "Tests/CodeVoyagerTests"
        ),
    ]
)
