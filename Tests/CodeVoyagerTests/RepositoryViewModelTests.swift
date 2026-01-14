import Foundation
import Testing
@testable import CodeVoyager

@Suite("RepositoryViewModel Load Tests")
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
struct RepositoryViewModelTabTests {
    @Test("Opening a file creates a new tab")
    func openFileCreatesTab() {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/src/main.swift", name: "main.swift")

        viewModel.openFile(fileNode)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.tabs.first?.title == "main.swift")
        #expect(viewModel.tabs.first?.filePath == "/repo/src/main.swift")
    }

    @Test("Opening a file selects the new tab")
    func openFileSelectsTab() {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        viewModel.openFile(fileNode)

        #expect(viewModel.selectedTabID == viewModel.tabs.first?.id)
        #expect(viewModel.selectedTab?.title == "main.swift")
    }

    @Test("Opening the same file twice does not create duplicate tabs")
    func openSameFileTwice() {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        viewModel.openFile(fileNode)
        viewModel.openFile(fileNode)

        #expect(viewModel.tabs.count == 1)
    }

    @Test("Opening different files creates multiple tabs")
    func openDifferentFiles() {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/main.swift", name: "main.swift")
        let file2 = makeFileNode(path: "/repo/app.swift", name: "app.swift")

        viewModel.openFile(file1)
        viewModel.openFile(file2)

        #expect(viewModel.tabs.count == 2)
    }

    @Test("Closing a tab removes it from the list")
    func closeTabRemovesIt() {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/main.swift", name: "main.swift")
        let file2 = makeFileNode(path: "/repo/app.swift", name: "app.swift")

        viewModel.openFile(file1)
        viewModel.openFile(file2)

        let tabToClose = viewModel.tabs.first!.id
        viewModel.closeTab(tabToClose)

        #expect(viewModel.tabs.count == 1)
        #expect(viewModel.tabs.first?.title == "app.swift")
    }

    @Test("Closing the selected tab selects an adjacent tab")
    func closeSelectedTabSelectsAdjacent() {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/file1.swift", name: "file1.swift")
        let file2 = makeFileNode(path: "/repo/file2.swift", name: "file2.swift")
        let file3 = makeFileNode(path: "/repo/file3.swift", name: "file3.swift")

        viewModel.openFile(file1)
        viewModel.openFile(file2)
        viewModel.openFile(file3)

        // Select and close the middle tab
        viewModel.selectedTabID = viewModel.tabs[1].id
        viewModel.closeTab(viewModel.tabs[1].id)

        #expect(viewModel.selectedTabID != nil)
        #expect(viewModel.tabs.count == 2)
    }

    @Test("Closing the last tab sets selectedTabID to nil")
    func closeLastTabClearsSelection() {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        viewModel.openFile(fileNode)
        viewModel.closeTab(viewModel.tabs.first!.id)

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
        #expect(viewModel.selectedTab == nil)
    }

    @Test("Closing all tabs clears everything")
    func closeAllTabs() {
        let viewModel = makeViewModel()
        viewModel.openFile(makeFileNode(path: "/repo/f1.swift", name: "f1.swift"))
        viewModel.openFile(makeFileNode(path: "/repo/f2.swift", name: "f2.swift"))
        viewModel.openFile(makeFileNode(path: "/repo/f3.swift", name: "f3.swift"))

        viewModel.closeAllTabs()

        #expect(viewModel.tabs.isEmpty)
        #expect(viewModel.selectedTabID == nil)
    }

    @Test("Closing non-existent tab does nothing")
    func closeNonExistentTab() {
        let viewModel = makeViewModel()
        viewModel.openFile(makeFileNode(path: "/repo/main.swift", name: "main.swift"))

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

    @Test("TabItem has unique IDs")
    func uniqueIDs() {
        let tab1 = TabItem(type: .file, title: "test")
        let tab2 = TabItem(type: .file, title: "test")

        #expect(tab1.id != tab2.id)
    }
}
