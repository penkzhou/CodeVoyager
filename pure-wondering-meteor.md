# CodeVoyager - 高性能 macOS 代码阅读与 Git 查看应用

## 项目概述

创建一个原生 macOS 应用，专注于**代码阅读**和 **Git 查看**，用 Swift 原生技术替代 Electron，实现高性能和低内存占用。

### 核心定位
| 项目 | 选择 |
|------|------|
| 技术栈 | SwiftUI 为主 + AppKit（高性能文本） |
| 最低版本 | macOS 14+ |
| 代码浏览 | 只读，语法高亮 |
| Git 功能 | 查看为主（历史、diff、分支、blame） |
| 参考应用 | Fork |

---

## 技术选型

### 1. 语法高亮：STTextView + Neon (Tree-sitter)
- **STTextView**: 基于 TextKit 2 的高性能文本视图 ([GitHub](https://github.com/krzyzanowskim/STTextView))
- **Neon**: Tree-sitter 高亮引擎 ([GitHub](https://github.com/ChimeHQ/Neon))
- **优势**: 增量解析、10000+ 行流畅、原生性能

### 2. Git 操作：SwiftGit3 + git CLI 混合方案
- **SwiftGit3**: 常规操作（打开仓库、分支、提交历史、diff）
- **git CLI**: 复杂操作（blame、分支图、特殊格式输出）
- **优势**: 结合两者优点，性能与功能兼顾

### 3. 核心依赖
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/STTextView.git", from: "0.8.0"),
    .package(url: "https://github.com/ChimeHQ/Neon.git", from: "0.6.0"),
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.8.0"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),  // 缓存
]
```

> **注意**: SwiftGit3 需要评估最新可用版本，可能需要使用 SwiftGit2 或 SwiftGitX 作为替代。

---

## 应用架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│         CodeVoyagerApp.swift / WindowGroup / Commands        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│   ViewModels (状态管理) │ Views (SwiftUI) │ Coordinators     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│        Entities │ Use Cases │ Service Protocols              │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│     SwiftGit3Service │ GitCLIService │ FileSystemService     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure                            │
│   Neon/TreeSitter │ CacheManager │ Concurrency │ Logging     │
└─────────────────────────────────────────────────────────────┘
```

---

## 项目结构

```
CodeVoyager/
├── CodeVoyager/
│   ├── App/                          # 应用入口
│   │   ├── CodeVoyagerApp.swift
│   │   └── WindowCommands.swift
│   │
│   ├── Features/                     # 功能模块
│   │   ├── Repository/               # 仓库管理
│   │   ├── FileTree/                 # 文件树浏览
│   │   ├── CodeEditor/               # 代码查看（核心）
│   │   ├── GitHistory/               # 提交历史
│   │   ├── GitDiff/                  # Diff 视图
│   │   ├── GitBlame/                 # Blame 视图
│   │   └── BranchGraph/              # 分支图
│   │
│   ├── Core/                         # 核心组件
│   │   ├── Navigation/
│   │   ├── Components/               # 通用 UI
│   │   └── Extensions/
│   │
│   ├── Services/                     # 服务层
│   │   ├── Git/
│   │   │   ├── GitServiceProtocol.swift
│   │   │   ├── SwiftGit3Service.swift
│   │   │   ├── GitCLIService.swift
│   │   │   └── Parsers/
│   │   ├── FileSystem/
│   │   └── Cache/
│   │
│   ├── Domain/                       # 领域模型
│   │   ├── Entities/
│   │   └── UseCases/
│   │
│   └── Infrastructure/               # 基础设施
│       ├── Syntax/                   # 语法高亮
│       └── Database/
│
└── Tests/
```

---

## MVP 功能范围 (v0.1)

### 必须实现
- [ ] **仓库管理**: 打开本地仓库、最近仓库列表
- [ ] **文件浏览**: 文件树、文件图标、延迟加载
- [ ] **代码查看**: 语法高亮（10+ 语言）、行号、大文件支持
- [ ] **Tab 管理**: 多文件打开/切换/关闭
- [ ] **Git 历史**: 提交列表、提交详情、变更文件
- [ ] **Diff 查看**: 并排/统一两种模式

### 延后实现 (v0.2+)
- Blame 视图
- 分支图可视化
- Minimap 代码缩略图
- 全局内容搜索
- 自定义主题

---

## 实施步骤

### Phase 1: 项目初始化
1. 创建 Xcode 项目（SwiftUI App，macOS 14+）
2. 配置 Package.swift 依赖
3. 搭建基础目录结构
4. 定义核心协议和实体

### Phase 2: 文件浏览功能
1. 实现 FileSystemService（目录遍历、文件读取）
2. 创建 FileTreeView（OutlineGroup 虚拟化）
3. 集成 STTextView + Neon 语法高亮
4. 实现 Tab 页管理

### Phase 3: Git 功能
1. 封装 SwiftGit3Service（仓库、分支、历史）
2. 实现 CommitHistoryView（LazyVStack 虚拟化）
3. 创建 DiffView（两种模式）
4. 实现提交详情视图

### Phase 4: 集成与优化
1. 主窗口布局整合（NavigationSplitView）
2. 性能优化（缓存、预加载）
3. 错误处理完善
4. 基础单元测试

---

## 关键文件

| 文件 | 说明 |
|------|------|
| `Services/Git/GitServiceProtocol.swift` | Git 服务抽象接口 |
| `Features/CodeEditor/Views/STTextViewRepresentable.swift` | 代码视图核心 |
| `Features/FileTree/ViewModels/FileTreeViewModel.swift` | 文件树状态管理 |
| `Features/GitHistory/Views/CommitHistoryView.swift` | 提交历史虚拟化 |
| `Domain/Entities/Commit.swift` | 核心领域实体 |

---

## 验证方案

### 功能验证
1. 打开一个中型 Git 仓库（如 swift-algorithms）
2. 浏览文件树，打开多个代码文件
3. 验证语法高亮正确显示
4. 查看提交历史，滚动验证虚拟化
5. 打开一个 commit 的 diff 视图

### 性能验证
1. 打开 10000+ 行的大文件，验证滚动流畅
2. 监控内存占用（目标 < 200MB 常规使用）
3. 冷启动时间（目标 < 2 秒）

### 测试
```bash
# 运行单元测试
xcodebuild test -scheme CodeVoyager -destination 'platform=macOS'
```

---

## 风险与备选方案

| 风险 | 备选方案 |
|------|----------|
| SwiftGit3 不稳定 | 使用 SwiftGitX 或纯 git CLI |
| STTextView 集成困难 | 使用 CodeEditorView 或自定义 NSTextView |
| Tree-sitter 语言支持不足 | 降级使用 Highlightr |
