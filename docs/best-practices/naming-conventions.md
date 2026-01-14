# 命名规范

## 避免与系统类型冲突

### 原则

不要使用与 SwiftUI/UIKit/AppKit 内置类型相同的名称，这会导致：
- 编译器歧义
- 需要完整模块名称限定
- 代码可读性下降
- 潜在的运行时问题

### 常见冲突名称

| 避免使用 | 冲突对象 | 推荐替代 |
|----------|----------|----------|
| `TabView` | SwiftUI.TabView | `SingleTabView`, `TabItemView` |
| `Text` | SwiftUI.Text | `TextContent`, `MessageText` |
| `Button` | SwiftUI.Button | `ActionButton`, `CustomButton` |
| `List` | SwiftUI.List | `ItemList`, `DataList` |
| `Image` | SwiftUI.Image | `ImageContent`, `AssetImage` |
| `Color` | SwiftUI.Color | `ThemeColor`, `CustomColor` |
| `View` | SwiftUI.View | `ContentView`, `CustomView` |
| `App` | SwiftUI.App | `MainApp`, `MyApp` |
| `Scene` | SwiftUI.Scene | `AppScene`, `MainScene` |
| `Window` | AppKit.NSWindow | `AppWindow`, `MainWindow` |
| `Menu` | SwiftUI.Menu | `ContextMenu`, `ActionMenu` |
| `Alert` | SwiftUI.Alert | `CustomAlert`, `ErrorAlert` |

### 反模式

#### ❌ 不推荐

```swift
// 与 SwiftUI.TabView 冲突
struct TabView: View {
    let tab: TabItem
    var body: some View { ... }
}

// 使用时产生歧义
struct ContentView: View {
    var body: some View {
        TabView(tab: item)  // 是哪个 TabView？
        SwiftUI.TabView {   // 需要完整限定
            ...
        }
    }
}
```

### ✅ 推荐

```swift
// 明确的名称，不会冲突
struct SingleTabView: View {
    let tab: TabItem
    var body: some View { ... }
}

// 或者使用更具描述性的名称
struct EditorTabView: View {
    let tab: TabItem
    var body: some View { ... }
}
```

## 命名模式

### View 命名

```swift
// 功能 + View
struct FileTreeView: View { ... }
struct CommitHistoryView: View { ... }
struct DiffContentView: View { ... }

// 组件 + View
struct TabBarView: View { ... }
struct SearchFieldView: View { ... }
struct LoadingIndicatorView: View { ... }
```

### ViewModel 命名

```swift
// 对应 View + ViewModel
class FileTreeViewModel: ObservableObject { ... }
class CommitHistoryViewModel: ObservableObject { ... }
class RepositoryViewModel: ObservableObject { ... }
```

### Model 命名

```swift
// 领域实体，使用名词
struct Commit { ... }
struct Branch { ... }
struct Repository { ... }

// 避免过于通用的名称
// ❌ Item, Data, Object, Model
// ✅ FileNode, TabItem, DiffHunk
```

### Protocol 命名

```swift
// 能力型：-able, -ible
protocol Identifiable { ... }
protocol Hashable { ... }
protocol Codable { ... }

// 服务型：-Protocol 或 -Service
protocol GitServiceProtocol { ... }
protocol FileSystemService { ... }

// 代理型：-Delegate
protocol TabBarDelegate { ... }
```

## 文件命名

```
Views/
  ├── FileTreeView.swift       // View 文件
  ├── CommitHistoryView.swift
  └── Components/
      ├── TabBarView.swift
      └── SingleTabView.swift  // 避免与 SwiftUI.TabView 冲突

ViewModels/
  ├── FileTreeViewModel.swift
  └── CommitHistoryViewModel.swift

Models/
  ├── Commit.swift
  ├── Branch.swift
  └── Repository.swift
```

## 检查清单

- [ ] 新类型名称是否与 SwiftUI/AppKit 类型冲突？
- [ ] 名称是否具有描述性，表明其用途？
- [ ] 文件名是否与主要类型名称匹配？
