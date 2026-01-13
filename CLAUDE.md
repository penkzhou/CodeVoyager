# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 语言要求

**重要：所有回复必须使用中文。** 代码、命令和技术术语可以保留英文，但解释和说明必须用中文。

## Project Overview

CodeVoyager is a native macOS application for **code reading** and **Git viewing**. It aims to replace Electron-based solutions with Swift for high performance and low memory usage. Reference app: Fork.

**Target**: macOS 14+
**Tech Stack**: SwiftUI (primary) + AppKit (for high-performance text rendering)
**Status**: Early development (project structure being established)

## Build and Test Commands

```bash
# Build the project
xcodebuild build -scheme CodeVoyager -destination 'platform=macOS'

# Run all tests
xcodebuild test -scheme CodeVoyager -destination 'platform=macOS'

# Run a single test
xcodebuild test -scheme CodeVoyager -destination 'platform=macOS' -only-testing:CodeVoyagerTests/TestClassName/testMethodName
```

## Architecture

The project follows a layered architecture:

```
Application Layer     → CodeVoyagerApp.swift, WindowGroup, Commands
Presentation Layer    → ViewModels, SwiftUI Views, Coordinators
Domain Layer          → Entities, Use Cases, Service Protocols
Data Layer            → SwiftGit3Service, GitCLIService, FileSystemService
Infrastructure        → Neon/TreeSitter, CacheManager, Concurrency, Logging
```

### Key Technical Decisions

1. **Syntax Highlighting**: STTextView (TextKit 2) + Neon (Tree-sitter) for 10000+ line files with incremental parsing
2. **Git Operations**: Hybrid approach - SwiftGit3 for common operations, git CLI for complex ones (blame, branch graph)
3. **Large List Rendering**: LazyVStack with virtualization for commit history and file trees

### Core Dependencies

- STTextView (TextKit 2 text view)
- Neon (Tree-sitter highlighting engine)
- SwiftTreeSitter
- GRDB.swift (caching)
- SwiftGit3 (or SwiftGitX as fallback)

## Feature Modules

Each feature lives in `CodeVoyager/Features/`:
- **Repository**: Repo management, recent repos list
- **FileTree**: File browser with lazy loading
- **CodeEditor**: Read-only code view with syntax highlighting (core feature)
- **GitHistory**: Commit list with virtualized scrolling
- **GitDiff**: Side-by-side and unified diff views
- **GitBlame**: Blame annotations (v0.2+)
- **BranchGraph**: Visual branch graph (v0.2+)

## Performance Targets

- Memory: < 200MB for normal usage
- Cold start: < 2 seconds
- Large files: 10000+ lines must scroll smoothly
