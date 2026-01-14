import XCTest
@testable import CodeVoyager

final class FileTreeViewModelTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() async throws {
        // Create a temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create a mock .git directory to simulate a Git repository
        let gitDir = tempDirectory.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Path Truncation Tests

    func testTruncateShortPath() {
        let path = "src/file.txt"
        let result = PathDisplayHelper.truncatePath(path, maxLength: 40)

        XCTAssertEqual(result, path)
    }

    func testTruncateLongPath() {
        let path = "src/components/deeply/nested/folder/structure/Button.tsx"
        let result = PathDisplayHelper.truncatePath(path, maxLength: 20)

        XCTAssertTrue(result.contains("..."))
        XCTAssertTrue(result.hasPrefix("src/"))
        XCTAssertTrue(result.hasSuffix("Button.tsx"))
    }

    func testTruncatePathWithDefaultMaxLength() {
        let shortPath = "short.txt"
        XCTAssertEqual(PathDisplayHelper.truncatePath(shortPath), shortPath)

        let longPath = String(repeating: "a/", count: 30) + "file.txt"
        let truncated = PathDisplayHelper.truncatePath(longPath)
        XCTAssertTrue(truncated.count <= 40 || truncated.contains("..."))
    }

    func testTruncateEmptyPath() {
        let result = PathDisplayHelper.truncatePath("")
        XCTAssertEqual(result, "")
    }

    func testTruncatePathWithTwoComponents() {
        let path = "src/file.txt"
        let result = PathDisplayHelper.truncatePath(path, maxLength: 5)

        // Two-component paths should remain unchanged
        XCTAssertEqual(result, path)
    }

    // MARK: - ViewModel Loading Tests

    @MainActor
    func testLoadRootLevel() async throws {
        // Create test files
        let file1 = tempDirectory.appendingPathComponent("file1.txt")
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)

        try "content".write(to: file1, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.rootNodes.count, 2)

        // Directories should come first
        XCTAssertTrue(viewModel.rootNodes.first?.isDirectory ?? false)
    }

    @MainActor
    func testToggleExpansion() async throws {
        // Create a directory with content
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let file = subdir.appendingPathComponent("file.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        guard let dirNode = viewModel.rootNodes.first(where: { $0.isDirectory }) else {
            XCTFail("No directory node found")
            return
        }

        XCTAssertFalse(viewModel.isExpanded(dirNode))

        await viewModel.toggleExpansion(dirNode)

        XCTAssertTrue(viewModel.isExpanded(dirNode))

        await viewModel.toggleExpansion(dirNode)

        XCTAssertFalse(viewModel.isExpanded(dirNode))
    }

    @MainActor
    func testSelectNode() async throws {
        let file = tempDirectory.appendingPathComponent("test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        guard let fileNode = viewModel.rootNodes.first else {
            XCTFail("No node found")
            return
        }

        XCTAssertNil(viewModel.selectedNode)

        viewModel.selectNode(fileNode)

        XCTAssertEqual(viewModel.selectedNode?.id, fileNode.id)
    }

    @MainActor
    func testRefresh() async throws {
        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()
        XCTAssertTrue(viewModel.rootNodes.isEmpty)

        // Add a file
        let file = tempDirectory.appendingPathComponent("new.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.rootNodes.count, 1)
    }
    
    // MARK: - 问题 6 修复测试: 子目录加载失败时更新 UI 状态
    
    @MainActor
    func testHasLoadErrorReturnsFalseByDefault() async throws {
        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)
        
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        
        await viewModel.loadRootLevel()
        
        guard let dirNode = viewModel.rootNodes.first(where: { $0.isDirectory }) else {
            XCTFail("No directory node found")
            return
        }
        
        // By default, no load error
        XCTAssertFalse(viewModel.hasLoadError(dirNode))
    }
    
    @MainActor
    func testFailedToLoadIDsInitiallyEmpty() async {
        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        // Initially no failed loads
        XCTAssertTrue(viewModel.failedToLoadIDs.isEmpty)
    }

    // MARK: - findNode Tests

    @MainActor
    func testFindNodeAtRootLevel() async throws {
        let file = tempDirectory.appendingPathComponent("test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        guard let fileNode = viewModel.rootNodes.first else {
            XCTFail("No node found")
            return
        }

        let foundNode = viewModel.findNode(by: fileNode.id)

        XCTAssertNotNil(foundNode)
        XCTAssertEqual(foundNode?.id, fileNode.id)
        XCTAssertEqual(foundNode?.url, fileNode.url)
    }

    @MainActor
    func testFindNodeInNestedDirectory() async throws {
        // Create nested structure: subdir/nested.txt
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let nestedFile = subdir.appendingPathComponent("nested.txt")
        try "nested content".write(to: nestedFile, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        // Find and expand the directory
        guard let dirNode = viewModel.rootNodes.first(where: { $0.isDirectory }) else {
            XCTFail("No directory node found")
            return
        }

        await viewModel.toggleExpansion(dirNode)

        // Find the updated directory node and get child
        guard let updatedDirNode = viewModel.findNode(by: dirNode.id),
              let children = updatedDirNode.children,
              let childNode = children.first else {
            XCTFail("No child node found after expansion")
            return
        }

        // Now find the child node by its ID
        let foundChild = viewModel.findNode(by: childNode.id)

        XCTAssertNotNil(foundChild)
        XCTAssertEqual(foundChild?.name, "nested.txt")
    }

    @MainActor
    func testFindNodeReturnsNilForNonexistentID() async throws {
        let file = tempDirectory.appendingPathComponent("test.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        let nonexistentID = UUID()
        let foundNode = viewModel.findNode(by: nonexistentID)

        XCTAssertNil(foundNode)
    }

    @MainActor
    func testFindNodeReturnsUpdatedNodeAfterChildrenLoaded() async throws {
        // Create directory structure
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let nestedFile = subdir.appendingPathComponent("nested.txt")
        try "content".write(to: nestedFile, atomically: true, encoding: .utf8)

        let repository = Repository(url: tempDirectory)
        let viewModel = FileTreeViewModel(repository: repository)

        await viewModel.loadRootLevel()

        guard let dirNode = viewModel.rootNodes.first(where: { $0.isDirectory }) else {
            XCTFail("No directory node found")
            return
        }

        // Before expansion, children should be empty
        XCTAssertTrue(dirNode.children?.isEmpty ?? true)
        XCTAssertFalse(dirNode.isLoaded)

        // Expand to trigger loading
        await viewModel.toggleExpansion(dirNode)

        // Find the node again - should have updated children
        guard let updatedNode = viewModel.findNode(by: dirNode.id) else {
            XCTFail("Could not find node after expansion")
            return
        }

        XCTAssertTrue(updatedNode.isLoaded)
        XCTAssertFalse(updatedNode.children?.isEmpty ?? true)
        XCTAssertEqual(updatedNode.children?.count, 1)
    }
}
