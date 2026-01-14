# CodeVoyager

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/version-0.1.0-green" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="License">
</p>

<p align="center">
  <a href="./README_cn.md">中文文档</a>
</p>

**CodeVoyager** is a native macOS application for code reading and Git visualization. Built with Swift to replace Electron-based solutions, it delivers high performance and low memory footprint for an exceptional code browsing experience.

> 🚧 **Status**: Early development stage

## ✨ Features

- 🚀 **Native Performance** - Pure Swift + SwiftUI, memory usage < 200MB
- 📂 **File Tree Browser** - Repository file browser with lazy loading
- 📝 **Code Reading** - Tree-sitter based syntax highlighting, supports 10K+ line files
- 🔀 **Git Integration** - View commit history, branches, and diffs
- 🎨 **Modern UI** - Three-column layout following macOS design guidelines

## 📸 Screenshots

> Coming soon

## 🔧 Requirements

- **macOS 14.0** (Sonoma) or later
- Xcode 15+ (for development)
- Swift 5.9+

## 🚀 Getting Started

### Build & Run

```bash
# Clone the repository
git clone https://github.com/penkzhou/CodeVoyager.git
cd CodeVoyager

# Build the project
swift build

# Run the app
swift run

# Or use the script to compile, package and run
./Scripts/compile_and_run.sh
```

### Build .app Bundle

```bash
# Build release version and package
./Scripts/package_app.sh release

# The app will be generated at project root: CodeVoyager.app
```

### Run Tests

```bash
swift test
# Or
./Scripts/compile_and_run.sh --test
```

## 🏗️ Architecture

The project follows a layered architecture with clear separation of concerns:

```
Sources/CodeVoyager/
├── App/                    # App entry and main window
│   ├── CodeVoyagerApp.swift
│   ├── AppState.swift
│   └── MainWindowView.swift
├── Core/                   # Shared components and utilities
│   ├── Components/         # Reusable UI components
│   └── Utilities/          # Utility classes
├── Domain/                 # Domain layer
│   └── Entities/           # Core entities (Repository, Commit, Branch...)
├── Features/               # Feature modules
│   ├── Repository/         # Repository management
│   ├── FileTree/           # File tree browser
│   ├── CodeEditor/         # Code editor (read-only)
│   ├── GitHistory/         # Commit history (v0.2)
│   ├── GitDiff/            # Diff view (v0.2)
│   ├── GitBlame/           # Blame annotations (v0.2)
│   └── BranchGraph/        # Branch graph (v0.2)
├── Services/               # Service layer
│   ├── FileSystem/         # File system service
│   └── Git/                # Git operations service
└── Infrastructure/         # Infrastructure
    ├── Database/           # GRDB caching
    └── Syntax/             # Syntax highlighting engine
```

### Tech Stack

| Component | Technology | Description |
|-----------|------------|-------------|
| UI Framework | SwiftUI + AppKit | SwiftUI primary, AppKit for high-performance text rendering |
| Text View | STTextView | High-performance text component based on TextKit 2 |
| Syntax Highlighting | Neon + Tree-sitter | Incremental parsing, supports large files |
| Git Operations | Hybrid approach | SwiftGit3 + git CLI |
| Data Caching | GRDB.swift | SQLite wrapper for metadata caching |

## 📦 Dependencies

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.0"),
    .package(url: "https://github.com/ChimeHQ/Neon.git", exact: "0.5.1"),
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", .upToNextMinor(from: "0.7.1")),
]
```

## 📋 Performance Targets

| Metric | Target |
|--------|--------|
| Memory Usage | < 200MB (normal usage) |
| Cold Start Time | < 2 seconds |
| Large File Support | 10,000+ lines with smooth scrolling |
| Commit History Loading | Virtualized list, load on demand |

## 🗺️ Roadmap

### v0.1.0 (Current)
- [x] Project foundation
- [x] Repository opening and management
- [x] File tree browser
- [x] Basic code viewer
- [ ] Syntax highlighting integration

### v0.2.0
- [ ] Git commit history
- [ ] Diff view
- [ ] Git Blame
- [ ] Branch graph visualization

### v0.3.0
- [ ] Search functionality
- [ ] Bookmarks and navigation
- [ ] Multi-repository support
- [ ] Preferences

## 🤝 Contributing

Contributions are welcome! Please read [CLAUDE.md](./CLAUDE.md) for development guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Fork](https://git-fork.com/) - Design inspiration
- [STTextView](https://github.com/krzyzanowskim/STTextView) - High-performance text component
- [Neon](https://github.com/ChimeHQ/Neon) - Tree-sitter syntax highlighting engine
- [GRDB.swift](https://github.com/groue/GRDB.swift) - Swift SQLite toolkit
