# CodeVoyager

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/version-0.1.0-green" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="License">
</p>

<p align="center">
  <a href="./README.md">English</a>
</p>

**CodeVoyager** 是一款原生 macOS 代码阅读与 Git 可视化应用，旨在以 Swift 原生方式替代基于 Electron 的解决方案，实现高性能、低内存占用的代码浏览体验。

> 🚧 **项目状态**: 早期开发阶段

## ✨ 特性

- 🚀 **原生性能** - 纯 Swift + SwiftUI 构建，内存占用 < 200MB
- 📂 **文件树浏览** - 支持懒加载的仓库文件浏览器
- 📝 **代码阅读** - 基于 Tree-sitter 的语法高亮，支持万行级大文件
- 🔀 **Git 集成** - 查看提交历史、分支、差异对比
- 🎨 **现代 UI** - 遵循 macOS 设计规范的三栏布局

## 📸 截图

> 即将推出

## 🔧 系统要求

- **macOS 14.0** (Sonoma) 或更高版本
- Xcode 15+ (用于开发)
- Swift 5.9+

## 🚀 快速开始

### 构建运行

```bash
# 克隆仓库
git clone https://github.com/yourusername/CodeVoyager.git
cd CodeVoyager

# 构建项目
swift build

# 运行应用
swift run

# 或使用脚本一键编译打包运行
./Scripts/compile_and_run.sh
```

### 构建 .app 包

```bash
# 构建 release 版本并打包
./Scripts/package_app.sh release

# 应用将生成在项目根目录: CodeVoyager.app
```

### 运行测试

```bash
swift test
# 或
./Scripts/compile_and_run.sh --test
```

## 🏗️ 项目架构

项目采用分层架构设计，遵循清晰的职责划分：

```
Sources/CodeVoyager/
├── App/                    # 应用入口与主窗口
│   ├── CodeVoyagerApp.swift
│   ├── AppState.swift
│   └── MainWindowView.swift
├── Core/                   # 通用组件与工具
│   ├── Components/         # 可复用 UI 组件
│   └── Utilities/          # 工具类
├── Domain/                 # 领域层
│   └── Entities/           # 核心实体 (Repository, Commit, Branch...)
├── Features/               # 功能模块
│   ├── Repository/         # 仓库管理
│   ├── FileTree/           # 文件树浏览
│   ├── CodeEditor/         # 代码编辑器 (只读)
│   ├── GitHistory/         # 提交历史 (v0.2)
│   ├── GitDiff/            # 差异对比 (v0.2)
│   ├── GitBlame/           # Blame 注解 (v0.2)
│   └── BranchGraph/        # 分支图 (v0.2)
├── Services/               # 服务层
│   ├── FileSystem/         # 文件系统服务
│   └── Git/                # Git 操作服务
└── Infrastructure/         # 基础设施
    ├── Database/           # GRDB 缓存
    └── Syntax/             # 语法高亮引擎
```

### 技术栈

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| UI 框架 | SwiftUI + AppKit | SwiftUI 为主，AppKit 用于高性能文本渲染 |
| 文本视图 | STTextView | 基于 TextKit 2 的高性能文本组件 |
| 语法高亮 | Neon + Tree-sitter | 增量解析，支持大文件 |
| Git 操作 | 混合方案 | SwiftGit3 + git CLI |
| 数据缓存 | GRDB.swift | SQLite 封装，用于元数据缓存 |

## 📦 依赖项

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.0"),
    .package(url: "https://github.com/ChimeHQ/Neon.git", exact: "0.5.1"),
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", .upToNextMinor(from: "0.7.1")),
]
```

## 📋 性能目标

| 指标 | 目标 |
|------|------|
| 内存占用 | < 200MB (常规使用) |
| 冷启动时间 | < 2 秒 |
| 大文件支持 | 10,000+ 行流畅滚动 |
| 提交历史加载 | 虚拟化列表，按需加载 |

## 🚀 发布流程

### Landing Page 发布

**官网地址**: https://penkzhou.github.io/CodeVoyager/

| 触发条件 | 说明 |
|---------|------|
| Push 到 `main` 分支 | 仅当 `docs/landing/**` 路径下的文件有变更时触发 |
| 手动触发 | 通过 GitHub Actions 的 `workflow_dispatch` 手动运行 |

Landing Page 上的**版本号和下载链接是动态获取的**：
- 页面加载时会调用 GitHub API 获取最新 Release 信息
- 自动显示最新版本号（如 `v0.0.1`）
- 下载按钮直接链接到最新的 DMG 文件
- 若 API 请求失败（如速率限制），会 fallback 显示 "Latest" 并链接到 Release 页面

### 应用发布

| 触发条件 | 说明 |
|---------|------|
| Push 符合 `v*.*.*` 格式的 Tag | 例如：`v0.0.1`、`v1.2.3` |

发布流程自动执行以下步骤：
1. 构建 Universal Binary（支持 arm64 和 x86_64）
2. 使用 Apple Developer ID 签名
3. 提交 Apple 公证（Notarization）
4. 创建 DMG 安装包
5. 生成 GitHub Release 并上传构建产物

**发布新版本**：
```bash
# 创建并推送 tag
git tag v0.1.0
git push origin v0.1.0
```

## 🗺️ 路线图

### v0.1.0 (当前)
- [x] 项目基础架构
- [x] 仓库打开与管理
- [x] 文件树浏览
- [x] 基础代码查看器
- [ ] 语法高亮集成

### v0.2.0
- [ ] Git 提交历史
- [ ] Diff 差异视图
- [ ] Git Blame
- [ ] 分支图可视化

### v0.3.0
- [ ] 搜索功能
- [ ] 书签与导航
- [ ] 多仓库支持
- [ ] 偏好设置

## 🤝 贡献

欢迎贡献代码！请先阅读项目的 [CLAUDE.md](./CLAUDE.md) 了解开发规范。

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 发起 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [Fork](https://git-fork.com/) - 设计灵感来源
- [STTextView](https://github.com/krzyzanowskim/STTextView) - 高性能文本组件
- [Neon](https://github.com/ChimeHQ/Neon) - Tree-sitter 语法高亮引擎
- [GRDB.swift](https://github.com/groue/GRDB.swift) - Swift SQLite 工具包
