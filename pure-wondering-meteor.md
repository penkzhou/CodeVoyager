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

## 详细技术规格

### 1. 渲染技术选择

| 组件 | 技术方案 | 说明 |
|------|----------|------|
| 整体框架 | SwiftUI + AppKit | SwiftUI 负责布局，AppKit 处理核心渲染 |
| 代码视图 | AppKit (STTextView) | 直接使用 AppKit，不做 SwiftUI 包装层 |
| 文件树 | SwiftUI | 使用 OutlineGroup 配合虚拟化 |
| Git 历史 | SwiftUI (LazyVStack) | 虚拟化滚动列表 |
| Diff 视图 | AppKit | 高性能文本对比渲染 |

### 2. 代码编辑器规格

#### 2.1 选择状态管理
- **每个 Tab 独立维护选择状态**
- 切换 Tab 或视图时保留并高亮显示选择
- 返回 Tab 时自动恢复焦点到选择位置

#### 2.2 行尾符处理
- **行内可视化显示**：在每行末尾显示 LF 或 CRLF 标记
- 对于混合行尾符的文件，用不同颜色标记不一致的行

#### 2.3 超长行处理
- **截断 + 提示**：超过阈值的行截断显示
- 显示"此行过长，点击查看完整"的提示
- 点击后可在弹出窗口或新 Tab 中查看完整内容

#### 2.4 语法高亮降级
- **Tree-sitter 失败时降级为纯文本**
- 不使用正则备选方案，保持简洁

#### 2.5 语言检测
- **混合优先策略**：
  1. 优先按文件扩展名选择语言
  2. 未知扩展名时检测 shebang/magic number
  3. 仍无法识别则显示纯文本

#### 2.6 超大文件处理
- 阈值设定：50MB
- 超过阈值时**显示警告，让用户决定是否继续**
- 用户确认后正常加载

#### 2.7 二进制文件
- **显示占位符**："二进制文件无法预览"
- 不提供 hex dump 或外部打开功能

### 3. 文件树规格

#### 3.1 加载策略
- **仅加载顶层目录**
- 子目录完全懒加载，展开时才加载内容
- 支持大型仓库（10万+ 文件）

#### 3.2 展开状态
- **持久化记住展开状态**
- 下次打开同一仓库时恢复展开的目录

#### 3.3 .gitignore 文件显示
- **灰色文字显示**：保持可见但视觉上降低优先级
- 不提供隐藏/显示切换

#### 3.4 文件图标
- **仅使用 SF Symbols**
- 按文件类型使用通用图标（文档、代码、图片等）
- 不使用第三方图标库

#### 3.5 长路径截断
- **中间截断**：显示开头和结尾，中间用 `...` 替代
- 例如：`src/.../components/Button.tsx`

### 4. Tab 管理规格

#### 4.1 溢出处理
- 前 N 个 Tab 直接显示
- **超出部分收纳到下拉菜单**
- 下拉菜单按最近使用排序

#### 4.2 Diff 显示
- **Diff 作为独立 Tab 打开**
- 与代码文件 Tab 使用相同的 Tab 系统

### 5. Git 历史规格

#### 5.1 数据加载
- **初始加载固定 500 条提交**
- 滚动到底部时加载更多
- 支持 100万+ 提交的大型仓库

#### 5.2 搜索范围
- **仅在已加载的记录中搜索**
- 不触发完整的 git log --grep
- 快速但可能不完整

#### 5.3 排序
- **仅支持时间倒序**
- 最新提交在顶部

#### 5.4 分支显示
- **在分支头提交旁显示分支名标签**
- 不显示分支图可视化（v0.2+）
- 不显示 reflog

#### 5.5 合并提交
- **默认与第一父提交比较**
- 显示合并带入的变更

#### 5.6 Commit 详情
- 仅显示核心信息：
  - SHA（完整和缩写）
  - 作者（姓名和邮箱）
  - 提交时间
  - Commit message
  - 变更文件列表

#### 5.7 链接解析
- **纯文本显示**
- 不解析 #123 为 issue 链接
- 不解析邮箱为 mailto 链接

### 6. Diff 视图规格

#### 6.1 同步滚动
- **行对齐优先**
- 插入空白行保持两侧行号对应
- 两侧始终同步滚动

#### 6.2 字符级别高亮
- **精确到字符级别**
- 高亮变更的具体字符，不只是整行

#### 6.3 两种模式
- 并排模式（side-by-side）
- 统一模式（unified）
- 可切换

### 7. Git 操作规格

#### 7.1 错误处理
- **立即报错**
- 不静默降级到 git CLI
- 显示错误弹窗让用户知晓问题

#### 7.2 外部变更检测
- **使用 FSEvents 监听 .git 目录**
- 检测到变化后刷新相关视图

#### 7.3 Submodule 处理
- **透明显示**
- 文件树中用特殊图标标记 submodule
- 点击可进入 submodule 浏览

### 8. 窗口与多实例

#### 8.1 多窗口支持
- **多窗口独立**
- 每个窗口是独立实例
- 不共享状态（除应用级设置）

#### 8.2 状态恢复
- **崩溃/退出后仅恢复仓库**
- 不恢复 Tab 状态
- 不恢复滚动位置

#### 8.3 响应式布局
- **代码视图优先**
- 代码视图占据剩余空间
- 侧边栏（文件树、Git 历史）固定宽度

### 9. 搜索功能

#### 9.1 文件内搜索
- `Cmd+F` 搜索当前文件
- 支持正则表达式
- 高亮所有匹配项

#### 9.2 全局搜索入口
- 提供 `Cmd+Shift+F` 入口
- MVP 显示"即将推出"占位符
- v0.2 实现完整功能

### 10. 文件外部修改

- **提示重载**
- 检测到文件变化时显示横幅
- 用户点击后重新加载

### 11. 最近仓库

- **固定 10 条记录**
- 不存在的仓库标记为灰色但保留
- 不提供数量配置

### 12. 主题与外观

- **仅跟随系统主题**
- macOS 深/浅色模式自动切换
- MVP 不提供自定义选项

### 13. 快捷键

最小集：
| 快捷键 | 功能 |
|--------|------|
| `Cmd+O` | 打开仓库 |
| `Cmd+W` | 关闭当前 Tab |
| `Cmd+F` | 文件内搜索 |

### 14. 可访问性

- **基本支持**
- 确保 UI 元素有正确的 accessibility label
- 支持 VoiceOver 基本导航

### 15. 国际化

- **MVP 仅英文界面**
- 代码中使用 NSLocalizedString 为未来做准备

### 16. 日志

- **仅控制台输出**
- 使用 os_log
- 开发时可见，用户不可访问

### 17. 空仓库/非 Git 目录

- **显示空状态提示**
- 进入主界面但显示友好的空状态消息
- 例如："此仓库没有提交历史"或"此目录不是 Git 仓库"

### 18. 文件预览

- **MVP 仅显示源代码**
- 不提供 Markdown/SVG 渲染预览
- 所有文件按源代码显示

### 19. 语法文件分发

- **全部打包在应用内**
- 支持的所有语言的 Tree-sitter 语法文件都包含在 app bundle 中

### 20. 缓存策略 (GRDB)

仅缓存 Git 元数据：
- 提交历史
- 分支信息
- 标签信息

不缓存：
- 文件内容
- Tree-sitter AST
- Diff 结果

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

---

## 访谈记录摘要

以下是产品规格访谈中确定的关键决策：

| 类别 | 问题 | 决策 |
|------|------|------|
| 状态管理 | Tab 切换时的选择状态 | 每个 Tab 独立维护，保留并高亮 |
| 文件树 | 历史 commit 的文件快照 | 始终显示 HEAD |
| 文件树 | 初始加载策略 | 仅加载顶层 |
| 显示 | 行尾符显示 | 行内可视化标记 |
| 显示 | 超长行处理 | 截断 + 提示 |
| Git | Reflog 显示 | 不显示 |
| Git | 外部变更检测 | FSEvents 监听 |
| 文件 | 二进制文件 | 拒绝打开，显示占位符 |
| 文件 | 超大文件 (50MB+) | 警告后允许打开 |
| Tab | 溢出处理 | 下拉菜单 |
| 导航 | Vim 键绑定 | 仅标准 macOS 快捷键 |
| Diff | 滚动同步 | 行对齐优先 |
| Diff | 合并提交 | 与第一父比较 |
| 语法 | 语法文件分发 | 全部打包 |
| 缓存 | GRDB 存储内容 | 仅 Git 元数据 |
| 搜索 | Cmd+F 范围 | 当前文件 + 全局入口 |
| 仓库 | 最近仓库数量 | 固定 10 条 |
| 错误 | SwiftGit3 失败 | 立即报错 |
| Git | Submodule 处理 | 透明显示，可进入 |
| 文件 | 外部修改响应 | 提示重载 |
| 语言 | 语言检测 | 混合优先（扩展名 > 内容检测） |
| 历史 | 初始加载量 | 固定 500 条 |
| 历史 | 搜索范围 | 仅已加载记录 |
| 窗口 | 多仓库支持 | 多窗口独立 |
| 状态 | 崩溃恢复 | 仅恢复仓库 |
| 显示 | gitignore 文件 | 灰色显示 |
| 主题 | MVP 主题选项 | 仅系统主题 |
| Diff | 字符级变更 | 字符级别高亮 |
| Commit | 详情信息 | 核心信息 |
| 可访问性 | VoiceOver 支持 | 基本支持 |
| 国际化 | UI 语言 | 仅英文 |
| 日志 | 日志功能 | 仅控制台 |
| 空仓库 | 空/非 Git 目录 | 空状态提示 |
| 分支 | 历史中分支显示 | 标签显示 |
| 链接 | Commit message 链接 | 纯文本 |
| 布局 | 窗口缩放响应 | 代码视图优先 |
| 渲染 | 代码视图技术 | AppKit 核心 |
| 降级 | 语法解析失败 | 纯文本 |
| 图标 | 文件图标方案 | SF Symbols |
| 排序 | 历史排序方式 | 仅时间倒序 |
| 快捷键 | 核心快捷键 | 最小集 |
| 状态 | 文件树展开状态 | 记住展开 |
| 截断 | 长路径显示 | 中间截断 |
| Diff | Diff 显示位置 | 独立 Tab |
| 预览 | Markdown/SVG 预览 | 仅源代码 |
