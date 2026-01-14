# 线程安全最佳实践

## MainActor 与 AppKit

### 原则

在 macOS 应用中使用 AppKit UI 组件时，必须确保在主线程执行：
- `NSOpenPanel`、`NSSavePanel`
- `NSAlert`
- `NSWindow` 操作
- 任何 UI 更新

### 反模式

### ❌ 不推荐

```swift
@Observable
final class AppState {
    func showOpenPanel() {
        let panel = NSOpenPanel()  // 可能在非主线程调用！
        panel.runModal()
    }
}

// 异步调用时可能出问题
Task {
    appState.showOpenPanel()  // 在后台线程执行
}
```

### ✅ 推荐

```swift
@MainActor
@Observable
final class AppState {
    func showOpenPanel() {
        let panel = NSOpenPanel()  // 保证在主线程
        panel.runModal()
    }
}
```

## @MainActor 使用指南

### 整个类标记

当类主要处理 UI 相关逻辑时：

```swift
@MainActor
@Observable
final class RepositoryViewModel {
    var tabs: [TabItem] = []
    var errorMessage: String?
    
    func openFile(_ node: FileNode) { ... }
    func closeTab(_ id: UUID) { ... }
}
```

### 单个方法标记

当只有部分方法需要主线程时：

```swift
@Observable
final class DataManager {
    var items: [Item] = []
    
    // 后台数据处理
    func processData() async { ... }
    
    // UI 更新需要主线程
    @MainActor
    func updateUI(with results: [Item]) {
        self.items = results
    }
}
```

### 显式切换到主线程

在 async 函数中需要更新 UI 时：

```swift
func loadData() async {
    let data = await fetchFromNetwork()  // 后台执行
    
    await MainActor.run {
        self.items = data  // 主线程更新
        self.isLoading = false
    }
}
```

## 常见场景

### 文件选择对话框

```swift
@MainActor
func showOpenPanel() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    
    if panel.runModal() == .OK, let url = panel.url {
        openRepository(at: url)
    }
}
```

### 警告对话框

```swift
@MainActor
func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Error"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
}
```

### 从后台任务更新 UI

```swift
func performBackgroundWork() async {
    // 后台工作
    let result = await heavyComputation()
    
    // 切换到主线程更新 UI
    await MainActor.run {
        self.result = result
        self.isProcessing = false
    }
}
```

## SwiftUI 中的注意事项

SwiftUI View body 自动在主线程执行，但：

```swift
struct ContentView: View {
    @State private var data: [Item] = []
    
    var body: some View {
        List(data) { item in ... }
            .task {
                // .task 在后台执行
                let fetched = await api.fetch()
                
                // 这里自动切换到主线程（SwiftUI 处理）
                data = fetched
            }
    }
}
```

## 测试代码适配

当 ViewModel 标记 `@MainActor` 后，测试代码也需要相应调整：

### Swift Testing 框架

```swift
@Suite("RepositoryViewModel Tests")
@MainActor  // 整个 Suite 在 MainActor 上运行
struct RepositoryViewModelTests {
    @Test("Opening a file creates a new tab")
    func openFileCreatesTab() async {
        let viewModel = RepositoryViewModel(repository: repo)
        await viewModel.openFile(fileNode)
        #expect(viewModel.tabs.count == 1)
    }
}
```

### XCTest 框架

```swift
@MainActor
final class RepositoryViewModelTests: XCTestCase {
    func testOpenFileCreatesTab() async {
        let viewModel = RepositoryViewModel(repository: repo)
        await viewModel.openFile(fileNode)
        XCTAssertEqual(viewModel.tabs.count, 1)
    }
}
```

## 检查清单

- [ ] 使用 AppKit UI 组件的类是否标记了 `@MainActor`？
- [ ] 异步方法中更新 `@Published`/`@Observable` 属性是否在主线程？
- [ ] 是否避免在后台线程调用 UI 相关方法？
- [ ] `@MainActor` 类的测试 Suite 是否也标记了 `@MainActor`？
