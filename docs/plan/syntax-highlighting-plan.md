# CodeVoyager 语法高亮功能规格文档

## 实施进度总览

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1: Tree-sitter 依赖 | ✅ 已完成 | 使用 TreeSitterLanguages 统一包 |
| Phase 2: 语言配置 | ✅ 已完成 | SupportedLanguage, LanguageRegistry 等 |
| Phase 3: 主题系统 | ✅ 已完成 | SyntaxTheme, ThemeManager, DefaultThemes |
| Phase 4: TextSystem 适配 | ✅ 已完成 | STTextViewSystemInterface |
| Phase 5: 语法高亮服务 | ✅ 已完成 | SyntaxHighlightingService (磁盘缓存待实现) |
| Phase 6: 视图层集成 | ✅ 已完成 | SyntaxHighlightedTextView + CodeEditor 集成 |
| Phase 7: Highlight Queries | ✅ 已完成 | 由 TreeSitterLanguages 包提供 |
| Phase 8: 测试 | ✅ 已完成 | ThemeTests, LanguageRegistryTests 等 |

---

## 目标

为 CodeVoyager 集成基于 Tree-sitter 的语法高亮功能，支持核心语言：Swift、JavaScript、TypeScript、TSX、Python、JSON、Markdown。

## 技术栈

- **STTextView** - TextKit 2 文本视图（已集成）
- **Neon** - Tree-sitter 高亮引擎（已依赖）
- **SwiftTreeSitter** - Tree-sitter Swift 绑定（已依赖）
- **TreeSitterLanguages** - 统一的语言 grammar 和 queries 包（已依赖）

---

## 支持的语言

| 语言 | 枚举值 | 文件扩展名 |
|------|--------|-----------|
| Swift | `.swift` | .swift |
| JavaScript | `.javascript` | .js, .jsx, .mjs, .cjs |
| TypeScript | `.typescript` | .ts |
| TSX | `.tsx` | .tsx |
| Python | `.python` | .py, .pyw |
| JSON | `.json` | .json, .jsonc |
| Markdown | `.markdown` | .md, .markdown |

**扩展名映射策略**: 固定映射，每个扩展名对应唯一语言，不做内容推断。

**不支持语言的处理**: 首次打开不支持的语言文件时，显示 Toast 提示「该语言暂不支持语法高亮」。

---

## 架构设计

### 1. TreeSitterClient 缓存策略

**决策**: 每文件独立 TreeSitterClient 实例

- 每个打开的文件拥有独立的 TreeSitterClient
- 隔离性好，无需处理并发解析问题
- 内存占用稍高，但简化了架构

### 2. Client 生命周期管理

**决策**: LRU 缓存延迟释放

- 文件关闭时，Client 不立即销毁
- 使用 LRU 缓存保留最近 N 个（建议 5-10 个）关闭文件的 Client
- 用户重新打开同一文件时可直接复用解析树
- 超出 LRU 容量时，最久未使用的 Client 被释放

### 3. 增量解析支持

**决策**: 仅支持全量解析

- 当前版本为只读模式，无需增量解析能力
- 保持架构简单，未来需要编辑功能时再重构

### 4. 高亮缓存

**决策**: 磁盘持久化缓存

- 将解析树序列化到磁盘（使用 GRDB 或文件系统）
- 应用重启后可复用缓存
- 打开文件时校验文件修改时间戳，决定是否使用缓存

---

## 主题系统

### 1. 主题跟随系统外观

**决策**: 手动选择优先

- 默认跟随系统外观自动切换浅色/深色主题
- 用户手动选择特定主题后，完全忽略系统外观变化
- 用户需手动选择「跟随系统」才恢复自动切换

**实现状态**: ✅ 已在 `ThemeManager.swift` 中实现

### 2. 自定义主题支持

**决策**: 仅内置主题

- 只提供内置的浅色/深色主题
- 不支持导入第三方主题或自定义调整
- 配色参考 VSCode Default 主题风格

**实现状态**: ✅ 已在 `DefaultThemes.swift` 中实现 Light+ 和 Dark+ 主题

### 3. 主题内容定义

主题需定义以下样式：

| 元素 | 样式属性 | 实现状态 |
|------|---------|---------|
| 代码背景色 | backgroundColor | ✅ |
| 行号颜色 | lineNumberColor | ✅ |
| 当前行高亮 | currentLineBackgroundColor | ✅ |
| 选中文本背景 | selectionBackgroundColor | ✅ |
| Token 样式 | 颜色 + 粗体/斜体 | ✅ |

**Token 样式**: 主题可控制颜色和字体样式（粗体、斜体），如注释用斜体、关键字用粗体。

**行号样式**: 行号颜色随主题变化，浅色/深色模式下不同。

**当前行高亮**: 光标所在行显示微妙的背景色变化。

### 4. Token 映射规则

**决策**: 完全匹配

- `@keyword.control` 必须在主题中显式定义才有样式
- 未定义的 capture name 使用默认文本样式
- 不做层级回退（如 `@keyword.control` 不回退到 `@keyword`）

**实现状态**: ✅ 已在 `SyntaxTheme.style(for:)` 方法中实现

---

## 性能策略

### 1. 初次加载策略

**决策**: 全量解析再显示

- 打开文件时等待全量解析完成后再显示内容
- 大文件（10000+ 行）可能有短暂延迟
- 考虑显示加载指示器（可选）

### 2. 线程模型

**决策**: Task 并发

- 每个文件的解析作为独立 Task
- 由 Swift Concurrency 管理并发
- 解析结果回调到主线程应用样式

### 3. 解析优先级调度

**决策**: 优先级调度

- 活跃标签页的解析任务优先级最高
- 切换标签页时，降低前一个文件的解析优先级（但不取消）
- 使用 `TaskPriority` 控制

### 4. 单行超长文件处理

**决策**: 正常解析

- 不做特殊处理，让 Tree-sitter 正常解析
- 接受可能的性能影响

---

## 错误处理

### 1. 编码错误（非法 UTF-8）

**决策**: 降级 + 状态栏提示

- 解析失败时显示纯文本（无高亮）
- 状态栏显示「解析失败」或文件编码问题提示
- 使用 `logger.warning()` 记录日志

### 2. 语法错误显示

**决策**: 红色波浪线标记

- Tree-sitter ERROR 节点位置显示红色波浪线下划线
- 帮助用户识别语法问题

### 3. 错误日志

**决策**: 最小化日志

- 只记录错误类型和文件路径
- 不记录详细堆栈或文件内容

---

## 状态栏集成

### 语言显示

**决策**: 语言名称 + 图标

- 显示语言名称（如 "Swift"、"Python"）
- 配合语言对应的小图标（如 Swift 的鸟图标）
- 不支持的语言显示「Plain Text」

**实现状态**: ✅ `SupportedLanguage.displayName` 和 `SupportedLanguage.iconName` 已实现

---

## Highlight Query 管理

**决策**: 使用 TreeSitterLanguages 包提供的 queries

- TreeSitterLanguages 包已包含各语言的 `highlights.scm`
- 无需手动维护 query 文件
- 通过 `TreeSitter[Language]Queries` 模块获取

**实现状态**: ✅ 已在 `LanguageConfiguration.swift` 中实现 query 加载

---

## 代码组织

### 已完成的代码结构

```
Sources/CodeVoyager/Infrastructure/Syntax/
├── Languages/
│   ├── SupportedLanguage.swift          ✅ 语言枚举定义
│   ├── LanguageConfiguration.swift      ✅ Tree-sitter 配置封装
│   ├── LanguageRegistryProtocol.swift   ✅ 协议定义
│   └── LanguageRegistry.swift           ✅ 语言配置管理
└── Theme/
    ├── TokenStyle.swift                 ✅ Token 样式定义
    ├── SyntaxTheme.swift                ✅ 主题定义 + CaptureNames 常量
    ├── DefaultThemes.swift              ✅ 内置主题（Light+/Dark+）
    ├── ThemeManagerProtocol.swift       ✅ 协议定义
    └── ThemeManager.swift               ✅ 主题切换管理

Tests/CodeVoyagerTests/Syntax/
├── SupportedLanguageTests.swift         ✅ 语言枚举测试
└── LanguageRegistryTests.swift          ✅ 语言注册表测试
```

### 已完成的代码结构（续）

```
Sources/CodeVoyager/Infrastructure/Syntax/
└── TextSystem/
    └── STTextViewSystemInterface.swift  ✅ TextKit 2 适配

Sources/CodeVoyager/Services/Syntax/
├── SyntaxHighlightingServiceProtocol.swift  ✅ 服务协议
├── SyntaxHighlightingService.swift          ✅ 高亮服务实现
└── HighlightCache.swift                     ⏳ 磁盘缓存（可选优化）

Sources/CodeVoyager/Features/CodeEditor/Views/
├── SyntaxHighlightedTextView.swift      ✅ NSViewRepresentable 桥接
└── CodeEditorView.swift                 ✅ 集成语法高亮

Tests/CodeVoyagerTests/Syntax/
├── ThemeTests.swift                     ✅ 主题系统完整测试
├── SupportedLanguageTests.swift         ✅ 语言枚举测试
└── LanguageRegistryTests.swift          ✅ 语言注册表测试
```

---

## 依赖管理

### 当前 Package.swift 配置

```swift
dependencies: [
    // Syntax Highlighting - Core
    .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "0.9.0"),
    .package(url: "https://github.com/ChimeHQ/Neon.git", exact: "0.5.1"),
    .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", .upToNextMinor(from: "0.7.1")),

    // Tree-sitter Language Grammars (统一包)
    .package(url: "https://github.com/simonbs/TreeSitterLanguages.git", from: "0.1.0"),
]
```

**注意**: 与原计划不同，使用 `TreeSitterLanguages` 统一包替代了单独的语言包。

---

## 实施步骤

### Phase 1: 添加 Tree-sitter 语言依赖 ✅ 已完成

**修改文件**: `Package.swift`

使用 TreeSitterLanguages 统一包，添加以下产品依赖：
- `TreeSitterSwift` + `TreeSitterSwiftQueries`
- `TreeSitterJavaScript` + `TreeSitterJavaScriptQueries`
- `TreeSitterTypeScript` + `TreeSitterTypeScriptQueries`
- `TreeSitterTSX` + `TreeSitterTSXQueries`
- `TreeSitterPython` + `TreeSitterPythonQueries`
- `TreeSitterJSON` + `TreeSitterJSONQueries`
- `TreeSitterMarkdown` + `TreeSitterMarkdownQueries`
- `TreeSitterMarkdownInline` + `TreeSitterMarkdownInlineQueries`

---

### Phase 2: 基础设施层 - 语言配置 ✅ 已完成

**已完成文件**:
- `Infrastructure/Syntax/Languages/SupportedLanguage.swift` - 7 种语言枚举
- `Infrastructure/Syntax/Languages/LanguageConfiguration.swift` - Tree-sitter 配置封装
- `Infrastructure/Syntax/Languages/LanguageRegistryProtocol.swift` - 协议定义
- `Infrastructure/Syntax/Languages/LanguageRegistry.swift` - 懒加载 + LRU 缓存管理

**核心功能**:
1. ✅ `SupportedLanguage` 枚举 - 定义支持的语言和文件扩展名映射
2. ✅ `SyntaxLanguageConfiguration` - 封装 Tree-sitter Language 和 Query
3. ✅ `LanguageRegistryProtocol` - 协议定义，便于测试
4. ✅ `LanguageRegistry` - 管理语言配置的懒加载和缓存

---

### Phase 3: 基础设施层 - 主题系统 ✅ 已完成

**已完成文件**:
- `Infrastructure/Syntax/Theme/TokenStyle.swift` - Token 样式（颜色 + 粗体/斜体）
- `Infrastructure/Syntax/Theme/SyntaxTheme.swift` - 主题定义 + CaptureNames 常量
- `Infrastructure/Syntax/Theme/DefaultThemes.swift` - Light+ 和 Dark+ 主题
- `Infrastructure/Syntax/Theme/ThemeManagerProtocol.swift` - 协议定义
- `Infrastructure/Syntax/Theme/ThemeManager.swift` - 主题切换 + 系统外观监听

**核心功能**:
1. ✅ `TokenStyle` - Token 样式，支持颜色、粗体、斜体
2. ✅ `SyntaxTheme` - 完整主题定义，包含背景色、行号、选中色、Token 样式映射
3. ✅ `CaptureNames` - 常用 Tree-sitter capture name 常量
4. ✅ `DefaultThemes` - 内置 Light+/Dark+ 主题（参考 VSCode）
5. ✅ `ThemeManager` - 手动选择优先 + UserDefaults 持久化 + 系统外观监听

---

### Phase 4: 基础设施层 - TextSystem 适配 ✅ 已完成

**已完成文件**:
- `Infrastructure/Syntax/TextSystem/STTextViewSystemInterface.swift`

**已实现功能**:
1. ✅ 实现 Neon 的 `TextSystemInterface` 协议
2. ✅ 适配 STTextView (TextKit 2) 的样式应用 (`setRenderingAttributes`)
3. ✅ 支持 Token 样式应用和清除

---

### Phase 5: 服务层 - 语法高亮服务 ✅ 已完成

**已完成文件**:
- `Services/Syntax/SyntaxHighlightingServiceProtocol.swift` - 服务协议定义
- `Services/Syntax/SyntaxHighlightingService.swift` - 完整服务实现

**已实现功能**:
1. ✅ 语言检测（根据文件扩展名，固定映射）
2. ✅ TreeSitterClient 管理（每语言共享实例）
3. ✅ LRU 缓存管理（`sessionLRUCache`，默认容量 10）
4. ✅ 会话生命周期管理（`HighlightingSession`）
5. ✅ 内容更新支持（`updateContent`）
6. ⏳ 磁盘缓存管理（`HighlightCache.swift` 未实现，可选优化）

---

### Phase 6: 视图层 - 高亮集成 ✅ 已完成

**已完成文件**:
- `Features/CodeEditor/Views/SyntaxHighlightedTextView.swift` - NSViewRepresentable 桥接
- `Features/CodeEditor/Views/CodeEditorView.swift` - 集成语法高亮

**已实现功能**:
1. ✅ 创建 `Highlighter` 并绑定到 STTextView（通过 `SyntaxHighlightingService`）
2. ✅ 在 CodeEditorView 中集成语言检测
3. ✅ 状态栏显示语言名称 + 图标
4. ⏳ 语法错误显示红色波浪线（未实现）
5. ⏳ 不支持语言时显示 Toast 提示（未实现）

---

### Phase 7: 添加 Highlight Queries ✅ 已完成

由 `TreeSitterLanguages` 包的 `*Queries` 模块提供，无需手动管理 `.scm` 文件。

Query 加载逻辑已在 `LanguageConfiguration.swift` 中实现。

---

### Phase 8: 测试 ✅ 已完成

**已完成测试**:
- ✅ `SupportedLanguageTests.swift` - 语言枚举所有 case 覆盖
- ✅ `LanguageRegistryTests.swift` - 语言注册表测试
- ✅ `ThemeTests.swift` - 主题系统完整测试（TokenStyle、SyntaxTheme、ThemeManager）

**测试覆盖**:
1. ✅ 语言检测正确性（所有扩展名）
2. ✅ 主题切换响应（手动选择优先逻辑）
3. ✅ 主题持久化和重置
4. ✅ Token 样式（颜色、粗体、斜体）
5. ✅ 捕获名称常量验证
6. ⏳ LRU 缓存行为（集成测试待添加）
7. ⏳ 大文件性能测试（待添加）

---

## 关键文件路径

| 文件 | 操作 | 状态 |
|------|------|------|
| `Package.swift` | 修改 | ✅ 已完成 |
| `Infrastructure/Syntax/Languages/` | 新建 | ✅ 已完成 |
| `Infrastructure/Syntax/Theme/` | 新建 | ✅ 已完成 |
| `Infrastructure/Syntax/TextSystem/` | 新建 | ✅ 已完成 |
| `Services/Syntax/` | 新建 | ✅ 已完成 |
| `Features/CodeEditor/Views/` | 修改 | ✅ 已完成 |
| `Tests/CodeVoyagerTests/Syntax/` | 新建 | ✅ 已完成 |

---

## 验证方案

1. **构建验证**: `xcodebuild build -scheme CodeVoyager -destination 'platform=macOS'`
2. **测试验证**: `xcodebuild test -scheme CodeVoyager -destination 'platform=macOS'`
3. **功能验证**:
   - 打开 `.swift` 文件，确认关键字、字符串、注释有不同颜色和样式
   - 打开 `.py` 文件，确认 Python 语法高亮正常
   - 切换系统外观，手动选择主题后确认不随系统变化
   - 打开 10000+ 行文件，确认滚动流畅
   - 打开 `.rs` 文件（不支持），确认显示 Toast 提示
   - 打开有语法错误的文件，确认显示红色波浪线
   - 关闭文件后重新打开，确认使用缓存（观察加载速度）

---

## 设计决策汇总

| 决策点 | 选择 | 理由 | 状态 |
|--------|------|------|------|
| Client 缓存策略 | 每文件独立实例 | 隔离性好，避免并发问题 | 设计完成 |
| Client 生命周期 | LRU 缓存延迟释放 | 平衡内存和重打开性能 | 设计完成 |
| 增量解析 | 仅全量解析 | 只读模式不需要，保持简单 | 设计完成 |
| 主题切换 | 手动选择优先 | 用户明确意图时不被系统打扰 | ✅ 已实现 |
| 自定义主题 | 不支持 | 减少复杂度，满足核心需求即可 | ✅ 已实现 |
| Token 映射 | 完全匹配 | 简单明确，易于维护 | ✅ 已实现 |
| 初次加载 | 全量解析再显示 | 保证一致性，接受延迟 | 设计完成 |
| 线程模型 | Task 并发 | 利用 Swift Concurrency | 设计完成 |
| 解析调度 | 优先级调度 | 活跃文件优先，不浪费已完成的解析 | 设计完成 |
| 编码错误 | 降级 + 提示 | 友好告知用户问题 | 设计完成 |
| 语法错误 | 红色波浪线 | 视觉反馈语法问题 | 设计完成 |
| Query 管理 | 使用统一包 | TreeSitterLanguages 已包含 | ✅ 已实现 |
| 代码位置 | Infrastructure/Syntax | 集中管理语法相关代码 | ✅ 已实现 |
| Registry 设计 | 协议 + 注入 | 便于测试 mock | ✅ 已实现 |
| 不支持语言 | Toast 提示 | 让用户知道限制 | 设计完成 |
| 扩展名映射 | 固定映射 | 简单可靠 | ✅ 已实现 |
| 日志级别 | 最小化 | 减少噪音 | ✅ 已实现 |
| 依赖版本 | 使用统一包 | TreeSitterLanguages 简化管理 | ✅ 已实现 |
| 测试数据 | 动态生成 | 不依赖外部资源 | 设计完成 |
| 高亮缓存 | 磁盘持久化 | 跨会话复用 | 设计完成 |
| 字体样式 | 颜色 + 粗体/斜体 | 丰富表现力 | ✅ 已实现 |
| 行号样式 | 随主题变化 | 整体视觉一致 | ✅ 已实现 |
| 当前行 | 微妙背景色变化 | 帮助定位光标 | ✅ 已实现 |
| 背景色 | 主题定义 | 完整的主题控制 | ✅ 已实现 |
| 配色参考 | VSCode Default | 通用性好 | ✅ 已实现 |
| 内置主题 | Light+/Dark+ | 满足基本需求 | ✅ 已实现 |
| 状态栏 | 语言 + 图标 | 直观显示 | ✅ 已实现 |
| TSX | 独立语言处理 | 更精确的语法支持 | ✅ 已实现 |
| Markdown | 基础高亮 | 标题、代码块、链接等 | ✅ 已实现 |

---

## 下一步工作

### ✅ 核心高亮功能已完成

1. ✅ **STTextViewSystemInterface** - TextKit 2 适配已实现
2. ✅ **SyntaxHighlightingService** - LRU 缓存管理已实现
3. ✅ **CodeEditor 集成** - SyntaxHighlightedTextView 已完成

### 优先级 1: 可选优化

1. **大文件性能测试**
   - 动态生成 10000+ 行测试文件
   - 验证滚动流畅性
   - 验证内存占用 < 200MB

2. **磁盘缓存** (`Services/Syntax/HighlightCache.swift`) - ⚠️ 低优先级
   - ❓ TreeSitterClient 不暴露解析树序列化 API
   - ❓ 解析速度已足够快（几千行代码 < 100ms）
   - ❓ LRU 内存缓存已覆盖常用场景
   - 若需实现：考虑缓存"文件哈希+解析时间"而非完整解析树

### 优先级 2: 用户体验增强

1. **不支持语言的 Toast 提示**
   - 首次打开不支持的语言文件时显示提示
   - 提示内容：「该语言暂不支持语法高亮」

2. **语法错误显示**
   - Tree-sitter ERROR 节点位置显示红色波浪线
   - 帮助用户识别语法问题

3. **加载指示器**
   - 大文件解析时显示加载状态
