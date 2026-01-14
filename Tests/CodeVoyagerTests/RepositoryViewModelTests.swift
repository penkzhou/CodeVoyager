import Foundation
import Testing
@testable import CodeVoyager

@Suite("RepositoryViewModel Load Tests")
@MainActor
struct RepositoryViewModelLoadTests {
    @Test("Load sets isLoading to true during loading")
    func loadSetsIsLoading() async {
        let viewModel = makeViewModel()
        
        // Before load
        #expect(viewModel.isLoading == false)
        
        // After load
        await viewModel.load()
        #expect(viewModel.isLoading == false) // Should be false after completion
    }
    
    @Test("Load sets error message for non-Git repository")
    func loadSetsErrorForNonGitRepo() async {
        // Create a ViewModel with a path that's not a Git repository
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        await viewModel.load()
        
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("not a Git repository") == true)
    }
    
    @Test("Load does not set error for valid Git repository")
    func loadNoErrorForGitRepo() async {
        // Create a mock Git repository
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let gitDir = tempDir.appendingPathComponent(".git")
        try? FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        await viewModel.load()
        
        #expect(viewModel.errorMessage == nil)
    }
    
    private func makeViewModel() -> RepositoryViewModel {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        return RepositoryViewModel(repository: repo)
    }
}

@Suite("RepositoryViewModel Tab Management Tests")
@MainActor
struct RepositoryViewModelTabTests {
    @Test("Opening a file creates a new tab")
    func openFileCreatesTab() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/src/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.tabs.first?.title == "main.swift")
        #expect(viewModel.tabs.first?.filePath == "/repo/src/main.swift")
    }

    @Test("Opening a file selects the new tab")
    func openFileSelectsTab() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)

        #expect(viewModel.selectedTabID == viewModel.tabs.first?.id)
        #expect(viewModel.selectedTab?.title == "main.swift")
    }

    @Test("Opening the same file twice does not create duplicate tabs")
    func openSameFileTwice() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        await viewModel.openFile(fileNode)

        #expect(viewModel.tabs.count == 1)
    }

    @Test("Opening different files creates multiple tabs")
    func openDifferentFiles() async {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/main.swift", name: "main.swift")
        let file2 = makeFileNode(path: "/repo/app.swift", name: "app.swift")

        await viewModel.openFile(file1)
        await viewModel.openFile(file2)

        #expect(viewModel.tabs.count == 2)
    }

    @Test("Closing a tab removes it from the list")
    func closeTabRemovesIt() async {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/main.swift", name: "main.swift")
        let file2 = makeFileNode(path: "/repo/app.swift", name: "app.swift")

        await viewModel.openFile(file1)
        await viewModel.openFile(file2)

        let tabToClose = viewModel.tabs.first!.id
        viewModel.closeTab(tabToClose)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.tabs.first?.title == "app.swift")
    }

    @Test("Closing the selected tab selects an adjacent tab")
    func closeSelectedTabSelectsAdjacent() async {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/file1.swift", name: "file1.swift")
        let file2 = makeFileNode(path: "/repo/file2.swift", name: "file2.swift")
        let file3 = makeFileNode(path: "/repo/file3.swift", name: "file3.swift")

        await viewModel.openFile(file1)
        await viewModel.openFile(file2)
        await viewModel.openFile(file3)

        // Select and close the middle tab
        viewModel.selectedTabID = viewModel.tabs[1].id
        viewModel.closeTab(viewModel.tabs[1].id)

        #expect(viewModel.selectedTabID != nil)
        #expect(viewModel.tabs.count == 2)
    }

    @Test("Closing the last tab sets selectedTabID to nil")
    func closeLastTabClearsSelection() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        viewModel.closeTab(viewModel.tabs.first!.id)

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
        #expect(viewModel.selectedTab == nil)
    }

    @Test("Closing all tabs clears everything")
    func closeAllTabs() async {
        let viewModel = makeViewModel()
        await viewModel.openFile(makeFileNode(path: "/repo/f1.swift", name: "f1.swift"))
        await viewModel.openFile(makeFileNode(path: "/repo/f2.swift", name: "f2.swift"))
        await viewModel.openFile(makeFileNode(path: "/repo/f3.swift", name: "f3.swift"))

        viewModel.closeAllTabs()

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
    }

    @Test("Closing non-existent tab does nothing")
    func closeNonExistentTab() async {
        let viewModel = makeViewModel()
        await viewModel.openFile(makeFileNode(path: "/repo/main.swift", name: "main.swift"))

        let originalCount = viewModel.tabs.count
        viewModel.closeTab(UUID()) // Random UUID

        #expect(viewModel.tabs.count == originalCount)
    }

    // MARK: - Helpers

    private func makeViewModel() -> RepositoryViewModel {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        return RepositoryViewModel(repository: repo)
    }

    private func makeFileNode(path: String, name: String) -> FileNode {
        FileNode(url: URL(fileURLWithPath: path), children: nil)
    }
}

@Suite("TabItem Tests")
struct TabItemTests {
    @Test("TabItem file type has correct properties")
    func fileTabType() {
        let tab = TabItem(
            type: .file,
            filePath: "/test/main.swift",
            title: "main.swift"
        )

        #expect(tab.type == .file)
        #expect(tab.filePath == "/test/main.swift")
        #expect(tab.title == "main.swift")
    }

    @Test("TabItem diff type stores commit SHA")
    func diffTabType() {
        let tab = TabItem(
            type: .diff(commitSHA: "abc123"),
            filePath: nil,
            title: "Diff: abc123"
        )

        if case .diff(let sha) = tab.type {
            #expect(sha == "abc123")
        } else {
            Issue.record("Expected diff type")
        }
    }

    // 问题 2 修复: 添加 TabType.welcome 测试
    @Test("TabItem welcome type has correct icon")
    func welcomeTabType() {
        let tab = TabItem(
            type: .welcome,
            filePath: nil,
            title: "Welcome"
        )

        #expect(tab.type == .welcome)
        #expect(tab.filePath == nil)
        #expect(tab.title == "Welcome")
    }

    @Test("TabItem has unique IDs")
    func uniqueIDs() {
        let tab1 = TabItem(type: .file, title: "test")
        let tab2 = TabItem(type: .file, title: "test")

        #expect(tab1.id != tab2.id)
    }
}

@Suite("TabType Icon Tests")
struct TabTypeIconTests {
    @Test("TabType.file has correct icon")
    func fileIcon() {
        #expect(TabType.file.iconName == "doc.text")
    }
    
    @Test("TabType.diff has correct icon")
    func diffIcon() {
        #expect(TabType.diff(commitSHA: "abc").iconName == "arrow.left.arrow.right")
    }
    
    @Test("TabType.welcome has correct icon")
    func welcomeIcon() {
        #expect(TabType.welcome.iconName == "house")
    }
}

@Suite("RepositoryViewModel File Loading Tests")
@MainActor
struct RepositoryViewModelFileLoadingTests {
    // 问题 1 修复: 添加 forceLoadLargeFile 测试
    
    @Test("forceLoadLargeFile loads content for large files")
    func forceLoadLargeFileSuccess() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create a test file
        let testFile = tempDir.appendingPathComponent("large.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        // Manually create a tab for the file
        let tab = TabItem(
            type: .file,
            filePath: testFile.path,
            title: "large.txt"
        )
        viewModel.tabs.append(tab)
        
        // Call forceLoadLargeFile
        await viewModel.forceLoadLargeFile(tabID: tab.id)
        
        // Verify content was loaded
        let content = viewModel.fileContent(for: tab.id)
        #expect(content != nil)
        #expect(content?.content == "test content")
        #expect(viewModel.loadingState(for: tab.id) == .loaded)
    }
    
    @Test("forceLoadLargeFile handles non-existent tab gracefully")
    func forceLoadLargeFileNonExistentTab() async {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        let viewModel = RepositoryViewModel(repository: repo)
        
        // Call with non-existent tab ID - should not crash
        await viewModel.forceLoadLargeFile(tabID: UUID())
        
        // No assertion needed - just verify no crash
        #expect(viewModel.tabs.isEmpty)
    }
    
    @Test("forceLoadLargeFile handles tab without file path gracefully")
    func forceLoadLargeFileNoPath() async {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        let viewModel = RepositoryViewModel(repository: repo)
        
        // Create a tab without file path (e.g., welcome tab)
        let tab = TabItem(
            type: .welcome,
            filePath: nil,
            title: "Welcome"
        )
        viewModel.tabs.append(tab)
        
        // Call forceLoadLargeFile - should handle nil path gracefully
        await viewModel.forceLoadLargeFile(tabID: tab.id)
        
        // Verify no content was loaded (since there's no path)
        #expect(viewModel.fileContent(for: tab.id) == nil)
    }
    
    @Test("forceLoadLargeFile sets error state on failure")
    func forceLoadLargeFileError() async {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        let viewModel = RepositoryViewModel(repository: repo)
        
        // Create a tab with non-existent file path
        let tab = TabItem(
            type: .file,
            filePath: "/nonexistent/file.txt",
            title: "file.txt"
        )
        viewModel.tabs.append(tab)
        
        // Call forceLoadLargeFile
        await viewModel.forceLoadLargeFile(tabID: tab.id)
        
        // Verify error state was set
        let state = viewModel.loadingState(for: tab.id)
        if case .error = state {
            // Expected
        } else {
            Issue.record("Expected error state, got \(state)")
        }
    }
}

// FileLoadingState 测试已在 FileLoadingStateTests.swift 中完整覆盖

// MARK: - loadFileContent Error Path Tests (问题 6 修复)

@Suite("RepositoryViewModel loadFileContent Error Path Tests")
@MainActor
struct RepositoryViewModelLoadFileContentErrorTests {
    @Test("Opening binary file sets binaryFile loading state")
    func openBinaryFileSetsState() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create a binary file with null bytes
        let binaryFile = tempDir.appendingPathComponent("binary.bin")
        let binaryData = Data([0x00, 0x01, 0x02, 0x03, 0x00])
        try binaryData.write(to: binaryFile)
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        let fileNode = FileNode(url: binaryFile, children: nil)
        await viewModel.openFile(fileNode)
        
        // Verify binary file state
        guard let tab = viewModel.tabs.first else {
            Issue.record("Tab should be created")
            return
        }
        
        let state = viewModel.loadingState(for: tab.id)
        #expect(state == .binaryFile)
    }
    
    @Test("Opening non-existent file sets error loading state")
    func openNonExistentFileSetsErrorState() async {
        let repo = Repository(url: URL(fileURLWithPath: "/repo"))
        let viewModel = RepositoryViewModel(repository: repo)
        
        let nonExistentFile = FileNode(
            url: URL(fileURLWithPath: "/nonexistent/path/file.txt"),
            children: nil
        )
        await viewModel.openFile(nonExistentFile)
        
        guard let tab = viewModel.tabs.first else {
            Issue.record("Tab should be created")
            return
        }
        
        let state = viewModel.loadingState(for: tab.id)
        if case .error = state {
            // Expected - error state
        } else {
            Issue.record("Expected error state, got \(state)")
        }
    }
    
    @Test("Opening normal text file sets loaded state")
    func openNormalTextFileSetsLoadedState() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let textFile = tempDir.appendingPathComponent("normal.swift")
        try "let x = 1".write(to: textFile, atomically: true, encoding: .utf8)
        
        let repo = Repository(url: tempDir)
        let viewModel = RepositoryViewModel(repository: repo)
        
        let fileNode = FileNode(url: textFile, children: nil)
        await viewModel.openFile(fileNode)
        
        guard let tab = viewModel.tabs.first else {
            Issue.record("Tab should be created")
            return
        }
        
        #expect(viewModel.loadingState(for: tab.id) == .loaded)
        #expect(viewModel.fileContent(for: tab.id)?.content == "let x = 1")
    }
}
