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

## Coding Guidelines

详细最佳实践参见 `docs/best-practices/` 目录。

### Error Handling
- **禁止使用 `try?` 静默吞掉错误** - 至少使用 `logger.error()` 记录错误信息
- 错误消息应包含用户可操作的指引，例如："请选择包含 .git 文件夹的目录"

### SwiftUI/AppKit 集成
- 使用 AppKit UI 组件（如 NSOpenPanel）的类必须标记 `@MainActor`
- 避免与 SwiftUI 内置类型重名（如 TabView、Text、Button 等）

### Hashable 实现
- 当 struct 包含可变属性时，自定义 `hash(into:)` 和 `==`，只包含不可变属性
- 在注释中说明为何某些属性不参与 hash 计算

### View 与 ViewModel 一致性
- 当 View 和 ViewModel 有相似逻辑（如 closeTab），必须保持行为一致
- 优先让 View 调用 ViewModel 方法，而非重复实现逻辑

### 测试覆盖
- 所有 enum case 必须有测试覆盖
- 所有 async 方法必须有测试覆盖
- 测试用例应覆盖正常路径和错误路径
- 所有公开的 Bool 属性必须有测试覆盖

### 边界情况测试
- **字符串处理**：对于 `prefix`、`suffix` 等操作必须测试：
  - 空字符串
  - 长度不足的字符串
  - 恰好达到阈值的字符串
- **行数计算**：必须测试空内容、单行、多行、trailing newline 等场景
- **集合操作**：必须测试空集合、单元素、边界索引等场景
