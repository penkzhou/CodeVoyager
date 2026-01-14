# View 与 ViewModel 一致性

## 原则

当 View 和 ViewModel 有相似的逻辑时：
1. **ViewModel 是唯一真相来源** - 业务逻辑只在 ViewModel 中实现
2. **View 只负责调用** - View 不应重复实现相同逻辑
3. **行为必须一致** - 如果必须在两处实现，行为必须完全相同

## 反模式：逻辑不一致

### ❌ 问题代码

```swift
// TabBarView.swift
struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTab: UUID?
    
    private func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTab == id {
            selectedTab = tabs.first?.id  // 选择第一个
        }
    }
}

// RepositoryViewModel.swift
class RepositoryViewModel {
    func closeTab(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs.remove(at: index)
        
        if selectedTabID == tabID {
            // 选择相邻的 tab（更好的用户体验）
            let newIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[newIndex].id
        }
    }
}
```

**问题**：
- View 关闭 tab 后选择第一个
- ViewModel 关闭 tab 后选择相邻的
- 用户体验不一致

## 正确做法

### ✅ 方案 1：View 调用 ViewModel（推荐）

```swift
// TabBarView.swift
struct TabBarView: View {
    @Bindable var viewModel: RepositoryViewModel
    
    var body: some View {
        ForEach(viewModel.tabs) { tab in
            TabItemView(
                tab: tab,
                isSelected: tab.id == viewModel.selectedTabID,
                onClose: { viewModel.closeTab(tab.id) }  // 调用 ViewModel
            )
        }
    }
}

// RepositoryViewModel.swift - 唯一实现
class RepositoryViewModel {
    func closeTab(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs.remove(at: index)
        
        if selectedTabID == tabID {
            if !tabs.isEmpty {
                let newIndex = min(index, tabs.count - 1)
                selectedTabID = tabs[newIndex].id
            } else {
                selectedTabID = nil
            }
        }
    }
}
```

### ✅ 方案 2：提取共享逻辑

如果 View 确实需要独立实现（如通用组件），提取共享逻辑：

```swift
// TabLogic.swift - 共享逻辑
enum TabLogic {
    /// 关闭 tab 后选择的 tab ID
    static func selectAfterClose(
        closedIndex: Int,
        remainingTabs: [TabItem],
        currentSelection: UUID?
    ) -> UUID? {
        guard !remainingTabs.isEmpty else { return nil }
        let newIndex = min(closedIndex, remainingTabs.count - 1)
        return remainingTabs[newIndex].id
    }
}

// 两处都使用相同逻辑
let newSelection = TabLogic.selectAfterClose(
    closedIndex: index,
    remainingTabs: tabs,
    currentSelection: selectedTabID
)
```

### ✅ 方案 3：通过 Binding 闭包

```swift
struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTab: UUID?
    var onCloseTab: (UUID) -> Void  // 由父级提供实现
    
    var body: some View {
        ForEach(tabs) { tab in
            TabItemView(
                tab: tab,
                onClose: { onCloseTab(tab.id) }
            )
        }
    }
}

// 使用时
TabBarView(
    tabs: $viewModel.tabs,
    selectedTab: $viewModel.selectedTabID,
    onCloseTab: { viewModel.closeTab($0) }
)
```

## 检查清单

- [ ] View 中是否有与 ViewModel 重复的逻辑？
- [ ] 如果有，两处的行为是否完全一致？
- [ ] 是否可以让 View 直接调用 ViewModel 方法？
- [ ] 如果必须分开实现，是否提取了共享逻辑？
