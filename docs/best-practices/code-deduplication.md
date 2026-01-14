# 代码重复消除最佳实践

本文档描述如何识别和消除代码重复，保持代码库的可维护性。

## 工具函数提取

当格式化、转换等函数在多处重复定义时，应提取到共享模块。

### 识别标志

- 同一函数体在两个或更多位置出现
- 函数逻辑完全相同，仅名称或作用域不同

### 解决方案

1. 在 `Core/Utilities/` 目录下创建共享模块
2. 使用 `enum` 作为命名空间（避免实例化）
3. 将函数定义为 `static` 方法

### 示例

❌ **重复代码（修复前）**：

```swift
// CodeEditorView.swift
struct CodeEditorView: View {
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// LargeFileWarning.swift
struct LargeFileWarning: View {
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

✅ **提取后**：

```swift
// Core/Utilities/FormatUtilities.swift
enum FormatUtilities {
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// 使用处
Text(FormatUtilities.formatFileSize(content.fileSize))
```

## 相似逻辑合并

同一文件中重复的 map/filter/reduce 逻辑应提取为私有方法。

### 识别标志

- 相同的闭包逻辑在多个 map/filter 调用中出现
- 仅输入变量名不同，处理逻辑相同

### 示例

❌ **重复逻辑（修复前）**：

```swift
// 在 loadRootLevel() 中
nodes = nodes.map { node in
    var updated = node
    updated.isGitIgnored = isPathGitIgnored(node.url)
    return updated
}

// 在 loadChildren() 中
children = children.map { child in
    var updated = child
    updated.isGitIgnored = isPathGitIgnored(child.url)
    return updated
}
```

✅ **提取后**：

```swift
private func markGitIgnoredStatus(_ nodes: [FileNode]) -> [FileNode] {
    nodes.map { node in
        var updated = node
        updated.isGitIgnored = isPathGitIgnored(node.url)
        return updated
    }
}

// 使用处
nodes = markGitIgnoredStatus(nodes)
children = markGitIgnoredStatus(children)
```

## UI 状态与领域实体分离

UI 相关状态（如展开、选中、高亮）不应存储在领域实体中，应由 ViewModel 管理。

### 识别标志

- 领域实体包含 `isExpanded`、`isSelected`、`isHighlighted` 等 UI 状态属性
- 这些属性在实体创建后需要频繁修改
- 属性值需要与 View 层保持同步

### 问题

- 违反关注点分离原则
- 领域实体的 Hashable 实现需要排除这些属性
- 状态同步容易出错

### 解决方案

将 UI 状态移至 ViewModel，领域实体通过函数参数获取状态：

❌ **错误做法**：

```swift
struct FileNode {
    var isExpanded: Bool = false  // UI 状态存储在实体中
    
    var iconName: String {
        isDirectory ? (isExpanded ? "folder.fill" : "folder") : "doc"
    }
}
```

✅ **正确做法**：

```swift
struct FileNode {
    // 移除 isExpanded 属性
    
    func iconName(isExpanded: Bool = false) -> String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return "doc"
    }
}

// ViewModel 管理展开状态
@Observable
class FileTreeViewModel {
    private(set) var expandedIDs: Set<UUID> = []
    
    func isExpanded(_ node: FileNode) -> Bool {
        expandedIDs.contains(node.id)
    }
}

// View 中使用
Image(systemName: node.iconName(isExpanded: viewModel.isExpanded(node)))
```

## 错误消息上下文

错误消息应包含足够的上下文信息，帮助用户和开发者定位问题。

### 识别标志

- 错误消息如 `"Failed to read file"` 没有指明哪个文件
- 原始错误信息被丢弃

### 解决方案

```swift
// ❌ 过于笼统
fileLoadingStates[tab.id] = .error("Failed to read file")

// ✅ 包含上下文
fileLoadingStates[tab.id] = .error("Failed to read file: \(error.localizedDescription)")

// ✅ 日志中包含更多细节
logger.error("Failed to load file '\(path)': \(error.localizedDescription)")
```

## 未使用代码清理

### 未使用的变量和导入

- 定期运行编译检查未使用警告
- 移除声明但从未调用的 Logger、常量等
- 移除不再需要的 import 语句

### 空方法或占位实现

空方法应添加明确的 TODO 标记：

```swift
// ❌ 容易被遗忘
private func loadExpansionState() {
    // Future improvement
}

// ✅ 明确标记
/// Load expansion state from persistent storage.
/// - Note: Currently not implemented. Requires path-based tracking.
private func loadExpansionState() {
    // TODO: Implement path-based expansion state persistence
}
```

## View 复用 ViewModel 方法

当 View 需要查找、计算或转换数据时，应复用 ViewModel 中已有的方法，而不是重复实现。

### 识别标志

- View 中有与 ViewModel 完全相同的私有方法
- 方法功能是数据查找、遍历、转换等非 UI 相关逻辑

### 示例

❌ **重复实现（修复前）**：

```swift
// FileTreeView.swift
struct FileTreeView: View {
    @Bindable var viewModel: FileTreeViewModel
    
    // 与 ViewModel 中完全相同的实现！
    private func findNodeRecursively(in nodes: [FileNode], id: UUID) -> FileNode? {
        for node in nodes {
            if node.id == id { return node }
            if let children = node.children,
               let found = findNodeRecursively(in: children, id: id) {
                return found
            }
        }
        return nil
    }
    
    private func findNode(by id: UUID?) -> FileNode? {
        guard let id = id else { return nil }
        return findNodeRecursively(in: viewModel.rootNodes, id: id)
    }
}

// FileTreeViewModel.swift
class FileTreeViewModel {
    func findNode(by id: UUID) -> FileNode? {
        findNodeRecursively(in: rootNodes, id: id)
    }
    
    private func findNodeRecursively(in nodes: [FileNode], id: UUID) -> FileNode? {
        // 完全相同的实现...
    }
}
```

✅ **复用后**：

```swift
// FileTreeView.swift
struct FileTreeView: View {
    @Bindable var viewModel: FileTreeViewModel
    
    // 直接复用 ViewModel 的方法
    private func findNode(by id: UUID?) -> FileNode? {
        guard let id = id else { return nil }
        return viewModel.findNode(by: id)  // ✅ 复用
    }
}
```

### 何时复用 vs 何时独立实现

| 场景 | 建议 |
|------|------|
| 数据查找、遍历、转换 | 复用 ViewModel |
| 纯 UI 计算（如布局、动画） | 可在 View 中实现 |
| 需要不同行为（如搜索策略） | 提取到共享模块 |

## 检查清单

在代码审查时检查：

- [ ] 是否有重复的函数定义？
- [ ] 是否有重复的 map/filter 闭包逻辑？
- [ ] 领域实体是否包含 UI 状态？
- [ ] 错误消息是否包含足够上下文？
- [ ] 是否有未使用的变量或导入？
- [ ] 空方法是否有 TODO 标记？
- [ ] View 中是否有可复用 ViewModel 方法的重复实现？
