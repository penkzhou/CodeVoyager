# 测试指南

## 覆盖率原则

1. **所有 enum case 必须测试** - 每个 case 的属性和行为
2. **所有 async 方法必须测试** - 包括正常路径和错误路径
3. **所有公开 API 必须测试** - public/internal 方法和属性
4. **边界条件必须测试** - 空集合、nil、极值等

## Enum 测试

### ❌ 不完整

```swift
@Suite("ChangeStatus Tests")
struct ChangeStatusTests {
    @Test("display names")
    func displayNames() {
        #expect(ChangeStatus.added.displayName == "Added")
        #expect(ChangeStatus.modified.displayName == "Modified")
        #expect(ChangeStatus.deleted.displayName == "Deleted")
        // 遗漏了 .copied 和 .untracked
    }
}
```

### ✅ 完整覆盖

```swift
@Suite("ChangeStatus Tests")
struct ChangeStatusTests {
    @Test("all cases have correct display names")
    func displayNames() {
        #expect(ChangeStatus.added.displayName == "Added")
        #expect(ChangeStatus.modified.displayName == "Modified")
        #expect(ChangeStatus.deleted.displayName == "Deleted")
        #expect(ChangeStatus.renamed.displayName == "Renamed")
        #expect(ChangeStatus.copied.displayName == "Copied")
        #expect(ChangeStatus.untracked.displayName == "Untracked")
    }
    
    @Test("all cases have correct symbols")
    func symbols() {
        #expect(ChangeStatus.added.symbol == "+")
        #expect(ChangeStatus.modified.symbol == "~")
        #expect(ChangeStatus.deleted.symbol == "-")
        #expect(ChangeStatus.renamed.symbol == "→")
        #expect(ChangeStatus.copied.symbol == "⧉")
        #expect(ChangeStatus.untracked.symbol == "?")
    }
    
    @Test("raw values match Git status codes")
    func rawValues() {
        #expect(ChangeStatus.added.rawValue == "A")
        #expect(ChangeStatus.modified.rawValue == "M")
        #expect(ChangeStatus.deleted.rawValue == "D")
        #expect(ChangeStatus.renamed.rawValue == "R")
        #expect(ChangeStatus.copied.rawValue == "C")
        #expect(ChangeStatus.untracked.rawValue == "?")
    }
}
```

## Async 方法测试

### 正常路径 + 错误路径

```swift
@Suite("RepositoryViewModel Load Tests")
struct RepositoryViewModelLoadTests {
    
    @Test("load sets isLoading correctly")
    func loadingState() async {
        let viewModel = makeViewModel()
        
        #expect(viewModel.isLoading == false)
        await viewModel.load()
        #expect(viewModel.isLoading == false)
    }
    
    @Test("load sets error for non-Git repository")
    func errorPath() async {
        // 创建非 Git 目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDir, 
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        await viewModel.load()
        
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("not a Git repository") == true)
    }
    
    @Test("load succeeds for valid Git repository")
    func successPath() async {
        // 创建带 .git 的目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let gitDir = tempDir.appendingPathComponent(".git")
        try? FileManager.default.createDirectory(
            at: gitDir, 
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        await viewModel.load()
        
        #expect(viewModel.errorMessage == nil)
    }
}
```

## 边界条件测试

```swift
@Suite("Tab Management Edge Cases")
struct TabEdgeCaseTests {
    
    @Test("close tab on empty list does nothing")
    func closeOnEmpty() {
        let viewModel = makeViewModel()
        #expect(viewModel.tabs.isEmpty)
        
        viewModel.closeTab(UUID())  // 不应崩溃
        
        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
    }
    
    @Test("close non-existent tab does nothing")
    func closeNonExistent() {
        let viewModel = makeViewModel()
        viewModel.openFile(makeFile("test.swift"))
        
        let originalCount = viewModel.tabs.count
        viewModel.closeTab(UUID())  // 不存在的 ID
        
        #expect(viewModel.tabs.count == originalCount)
    }
    
    @Test("close last tab clears selection")
    func closeLastTab() {
        let viewModel = makeViewModel()
        viewModel.openFile(makeFile("test.swift"))
        
        viewModel.closeTab(viewModel.tabs.first!.id)
        
        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
    }
}
```

## 测试命名规范

```swift
// 格式：<方法/属性>_<场景>_<预期结果>
func testLoad_withInvalidPath_setsErrorMessage() { }
func testCloseTab_whenLastTab_clearsSelection() { }
func testOpenFile_withExistingTab_selectsExisting() { }

// 或使用 Swift Testing 的描述性字符串
@Test("Opening an already open file selects the existing tab")
func openExistingFile() { }
```

## 测试辅助方法

```swift
@Suite("Repository Tests")
struct RepositoryTests {
    
    // MARK: - Test Helpers
    
    private func makeViewModel() -> RepositoryViewModel {
        let repo = Repository(url: URL(fileURLWithPath: "/test"))
        return RepositoryViewModel(repository: repo)
    }
    
    private func makeFile(_ name: String) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: "/test/\(name)"),
            children: nil
        )
    }
    
    private func makeTempGitRepo() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(
            at: gitDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }
}
```

## 检查清单

- [ ] 所有 enum case 都有测试吗？
- [ ] 所有 async 方法都测试了正常和错误路径吗？
- [ ] 边界条件（空、nil、极值）都测试了吗？
- [ ] 测试名称是否清晰描述了测试场景？
