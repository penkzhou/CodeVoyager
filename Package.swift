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

        // Syntax Highlighting - to be added in Phase 2 when versions stabilize
        // .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.0"),
        // .package(url: "https://github.com/ChimeHQ/Neon.git", ...),
        // .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", ...),
    ],
    targets: [
        .executableTarget(
            name: "CodeVoyager",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
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
