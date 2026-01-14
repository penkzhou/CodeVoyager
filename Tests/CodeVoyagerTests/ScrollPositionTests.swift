import Foundation
import Testing
@testable import CodeVoyager

// MARK: - TabItem Scroll Position Tests

@Suite("TabItem Scroll Position Tests")
struct TabItemScrollPositionTests {

    @Test("TabItem has default scrollOffset of zero")
    func defaultScrollOffset() {
        let tab = TabItem(type: .file, filePath: "/test.swift", title: "test.swift")

        #expect(tab.scrollOffset == 0)
    }

    @Test("TabItem scrollOffset can be modified")
    func modifyScrollOffset() {
        var tab = TabItem(type: .file, filePath: "/test.swift", title: "test.swift")

        tab.scrollOffset = 150.5

        #expect(tab.scrollOffset == 150.5)
    }

    @Test("TabItem scrollOffset does not affect equality")
    func scrollOffsetNotAffectEquality() {
        var tab1 = TabItem(id: UUID(), type: .file, filePath: "/test.swift", title: "test.swift")
        var tab2 = tab1 // Same ID

        tab1.scrollOffset = 100
        tab2.scrollOffset = 200

        // Equality should still hold since scrollOffset is not part of == implementation
        #expect(tab1 == tab2)
    }

    @Test("TabItem scrollOffset does not affect hash")
    func scrollOffsetNotAffectHash() {
        let id = UUID()
        var tab1 = TabItem(id: id, type: .file, filePath: "/test.swift", title: "test.swift")
        var tab2 = TabItem(id: id, type: .file, filePath: "/test.swift", title: "test.swift")

        tab1.scrollOffset = 100
        tab2.scrollOffset = 200

        #expect(tab1.hashValue == tab2.hashValue)
    }

    @Test("TabItem has default hasBeenViewed of false")
    func defaultHasBeenViewed() {
        let tab = TabItem(type: .file, filePath: "/test.swift", title: "test.swift")

        #expect(tab.hasBeenViewed == false)
    }

    @Test("TabItem hasBeenViewed can be modified")
    func modifyHasBeenViewed() {
        var tab = TabItem(type: .file, filePath: "/test.swift", title: "test.swift")

        tab.hasBeenViewed = true

        #expect(tab.hasBeenViewed == true)
    }

    @Test("TabItem hasBeenViewed does not affect equality")
    func hasBeenViewedNotAffectEquality() {
        var tab1 = TabItem(id: UUID(), type: .file, filePath: "/test.swift", title: "test.swift")
        var tab2 = tab1 // Same ID

        tab1.hasBeenViewed = true
        tab2.hasBeenViewed = false

        // Equality should still hold since hasBeenViewed is not part of == implementation
        #expect(tab1 == tab2)
    }

    @Test("TabItem hasBeenViewed does not affect hash")
    func hasBeenViewedNotAffectHash() {
        let id = UUID()
        var tab1 = TabItem(id: id, type: .file, filePath: "/test.swift", title: "test.swift")
        var tab2 = TabItem(id: id, type: .file, filePath: "/test.swift", title: "test.swift")

        tab1.hasBeenViewed = true
        tab2.hasBeenViewed = false

        #expect(tab1.hashValue == tab2.hashValue)
    }
}

// MARK: - RepositoryViewModel Scroll Position Tests

@Suite("RepositoryViewModel Scroll Position Management Tests")
@MainActor
struct RepositoryViewModelScrollPositionTests {

    @Test("updateScrollOffset updates tab scroll position")
    func updateScrollOffset() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        viewModel.updateScrollOffset(for: tabID, offset: 250.0)

        let tab = viewModel.tabs.first { $0.id == tabID }
        #expect(tab?.scrollOffset == 250.0)
    }

    @Test("updateScrollOffset does nothing for non-existent tab")
    func updateScrollOffsetNonExistentTab() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)

        // Update scroll for non-existent tab
        viewModel.updateScrollOffset(for: UUID(), offset: 100.0)

        // Original tab should be unaffected
        #expect(viewModel.tabs.first?.scrollOffset == 0)
    }

    @Test("getScrollOffset returns saved scroll position")
    func getScrollOffset() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        viewModel.updateScrollOffset(for: tabID, offset: 300.0)

        let offset = viewModel.getScrollOffset(for: tabID)
        #expect(offset == 300.0)
    }

    @Test("getScrollOffset returns zero for non-existent tab")
    func getScrollOffsetNonExistentTab() {
        let viewModel = makeViewModel()

        let offset = viewModel.getScrollOffset(for: UUID())
        #expect(offset == 0)
    }

    @Test("scroll position is preserved when switching tabs")
    func scrollPositionPreservedOnSwitch() async {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/file1.swift", name: "file1.swift")
        let file2 = makeFileNode(path: "/repo/file2.swift", name: "file2.swift")

        // Open first file
        await viewModel.openFile(file1)
        let tab1ID = viewModel.tabs.first!.id

        // Set scroll position for first file
        viewModel.updateScrollOffset(for: tab1ID, offset: 500.0)

        // Open second file (switches to it)
        await viewModel.openFile(file2)

        // Switch back to first file
        viewModel.selectedTabID = tab1ID

        // Scroll position should be preserved
        let offset = viewModel.getScrollOffset(for: tab1ID)
        #expect(offset == 500.0)
    }

    @Test("closing tab cleans up scroll position data")
    func closeTabCleansScrollPosition() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        viewModel.updateScrollOffset(for: tabID, offset: 100.0)
        viewModel.closeTab(tabID)

        // Tab should be removed, so no scroll offset should be retrievable
        let offset = viewModel.getScrollOffset(for: tabID)
        #expect(offset == 0)
    }

    @Test("new file opens with scroll position at top (zero)")
    func newFileOpensAtTop() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)

        let offset = viewModel.getScrollOffset(for: viewModel.tabs.first!.id)
        #expect(offset == 0)
    }

    @Test("new tab has hasBeenViewed set to false")
    func newTabHasNotBeenViewed() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        #expect(viewModel.hasTabBeenViewed(tabID) == false)
    }

    @Test("markTabAsViewed sets hasBeenViewed to true")
    func markTabAsViewedWorks() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        viewModel.markTabAsViewed(tabID)

        #expect(viewModel.hasTabBeenViewed(tabID) == true)
    }

    @Test("hasTabBeenViewed returns false for non-existent tab")
    func hasTabBeenViewedNonExistentTab() {
        let viewModel = makeViewModel()

        #expect(viewModel.hasTabBeenViewed(UUID()) == false)
    }

    @Test("markTabAsViewed does nothing for non-existent tab")
    func markTabAsViewedNonExistentTab() async {
        let viewModel = makeViewModel()
        let fileNode = makeFileNode(path: "/repo/main.swift", name: "main.swift")

        await viewModel.openFile(fileNode)
        let tabID = viewModel.tabs.first!.id

        // Try to mark a non-existent tab
        viewModel.markTabAsViewed(UUID())

        // Original tab should still be unviewed
        #expect(viewModel.hasTabBeenViewed(tabID) == false)
    }

    @Test("hasBeenViewed is preserved when switching tabs")
    func hasBeenViewedPreservedOnSwitch() async {
        let viewModel = makeViewModel()
        let file1 = makeFileNode(path: "/repo/file1.swift", name: "file1.swift")
        let file2 = makeFileNode(path: "/repo/file2.swift", name: "file2.swift")

        // Open first file and mark as viewed
        await viewModel.openFile(file1)
        let tab1ID = viewModel.tabs.first!.id
        viewModel.markTabAsViewed(tab1ID)

        // Open second file (switches to it)
        await viewModel.openFile(file2)

        // Switch back to first file
        viewModel.selectedTabID = tab1ID

        // hasBeenViewed should still be true
        #expect(viewModel.hasTabBeenViewed(tab1ID) == true)
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

// MARK: - ScrollableTextView Configuration Tests

@Suite("ScrollableTextView Configuration Tests")
struct ScrollableTextViewConfigurationTests {

    @Test("ScrollPosition has correct initial values")
    func initialScrollPosition() {
        let position = ScrollPosition()

        #expect(position.offset == 0)
    }

    @Test("ScrollPosition can be updated")
    func updateScrollPosition() {
        var position = ScrollPosition()

        position.offset = 123.5

        #expect(position.offset == 123.5)
    }

    @Test("ScrollPosition equality")
    func scrollPositionEquality() {
        var pos1 = ScrollPosition()
        var pos2 = ScrollPosition()

        pos1.offset = 100
        pos2.offset = 100

        #expect(pos1 == pos2)

        pos2.offset = 200
        #expect(pos1 != pos2)
    }
}
