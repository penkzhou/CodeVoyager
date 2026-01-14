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
- **禁止空 catch 块** - 即使错误可以降级处理，也必须记录日志（至少 `logger.warning()`）
- 在注释中说明降级行为（如 "Return false as fallback - file will be treated as not ignored"）
- 错误消息应包含用户可操作的指引，例如："请选择包含 .git 文件夹的目录"

### SwiftUI/AppKit 集成
- 使用 AppKit UI 组件（如 NSOpenPanel）的类必须标记 `@MainActor`
- 避免与 SwiftUI 内置类型重名（如 TabView、Text、Button 等）

### SwiftUI ViewModel 线程安全
- 所有使用 `@Observable` 宏且在 async 方法中更新 UI 状态的 ViewModel **必须**标记 `@MainActor`
- 对应的测试 Suite 也需要标记 `@MainActor`（使用 Swift Testing 框架时）
- 示例模式见 `RepositoryViewModel`

### Hashable 实现
- 当 struct 包含可变属性时，自定义 `hash(into:)` 和 `==`，只包含不可变属性
- 在类型级注释中**完整列出所有被排除的可变属性**（添加新属性时同步更新）
- 每个被排除的属性应有单独注释说明排除原因

### View 与 ViewModel 一致性
- 当 View 和 ViewModel 有相似逻辑（如 closeTab），必须保持行为一致
- 优先让 View 调用 ViewModel 方法，而非重复实现逻辑
- **View 不应重复实现 ViewModel 已有的方法**（如数据查找、遍历方法）
- 示例：View 中的 `findNode(by:)` 应调用 `viewModel.findNode(by:)` 而非重复实现递归逻辑

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

### 代码注释维护
- 定期清理过时的占位符代码和注释
- Phase 标记（如 "Coming in Phase 2"）在功能实现后应及时更新或删除
- 不再使用的占位符组件应直接删除，而非保留
- **代码注释中的示例输出必须与实际实现行为完全一致**

### 方法签名诚实性
- 如果方法签名声明 `throws` 但实际从不抛出错误（总是返回默认值），应移除 `throws`
- 在方法注释中说明降级行为，如 "Returns empty set if parsing fails (logged as warning)"
- 避免误导调用者认为需要处理不存在的异常

### C API 内存安全 (FSEvents, Core Foundation)
- 使用 `Unmanaged.passUnretained` 传递 `self` 到 C 回调时存在悬空指针风险
- 正确做法：使用 `passRetained` + `retain/release` 回调让框架管理引用计数
- 详细模式参见 `docs/best-practices/c-api-memory-safety.md`

### 代码复用
- **工具函数提取**：当同一函数在两处以上重复定义时，应提取到 `Core/Utilities/` 目录下的共享模块
- **相似逻辑合并**：同一文件中重复的 map/filter 逻辑应提取为私有方法
- 详细模式参见 `docs/best-practices/code-deduplication.md`

### 关注点分离
- **UI 状态不应存储在领域实体中**：如展开状态（isExpanded）、选中状态等 UI 相关状态应由 ViewModel 管理
- 若领域实体需要根据 UI 状态计算属性，使用函数参数而非存储属性
- 示例：`func iconName(isExpanded: Bool) -> String` 而非 `var isExpanded: Bool` + `var iconName: String`

### 未使用代码清理
- 定期检查并移除未使用的 import 和变量（如未调用的 Logger）
- 空方法应添加 `// TODO:` 标记说明计划的实现
- IDE 警告（unused variable）应及时处理
- 保留但暂未使用的类型应在注释中说明保留原因和未来用途

### 类型设计文档化
- 当 `var` 属性会影响类型的核心语义（如 `isDirectory`）时，添加 `## Design Note` 说明：
  - 为什么使用 `var` 而非 `let`
  - 哪些代码路径可以修改此属性
  - 潜在的改进方向
- 示例见 `FileNode.children` 的设计说明

### 冗余代码检查
- 确保条件分支有不同的行为，避免相同 return 语句出现在多个分支
- 删除永远不会执行的代码路径
- 使用 guard 简化早返回模式

### 错误消息上下文
- 用户可见的错误消息应包含具体上下文（如文件路径）和原始错误描述
- 格式：`"Failed to [action]: \(error.localizedDescription)"`
- 避免使用过于笼统的消息如 `"Failed to read file"`
