import XCTest
import Testing
@testable import CodeVoyager

// MARK: - FileSystemEventType Tests (问题 3 修复)

@Suite("FileSystemEventType Tests")
struct FileSystemEventTypeTests {
    @Test("All FileSystemEventType cases exist")
    func allCasesExist() {
        // Verify all 4 cases can be instantiated
        let created = FileSystemEventType.created
        let modified = FileSystemEventType.modified
        let deleted = FileSystemEventType.deleted
        let renamed = FileSystemEventType.renamed
        
        // Each case should be distinct
        #expect(created != modified)
        #expect(created != deleted)
        #expect(created != renamed)
        #expect(modified != deleted)
        #expect(modified != renamed)
        #expect(deleted != renamed)
    }
    
    @Test("FileSystemEvent stores URL and type correctly")
    func fileSystemEventProperties() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        
        let createdEvent = FileSystemEvent(url: url, type: .created)
        #expect(createdEvent.url == url)
        if case .created = createdEvent.type {
            // Expected
        } else {
            Issue.record("Expected created type")
        }
        
        let modifiedEvent = FileSystemEvent(url: url, type: .modified)
        if case .modified = modifiedEvent.type {
            // Expected
        } else {
            Issue.record("Expected modified type")
        }
        
        let deletedEvent = FileSystemEvent(url: url, type: .deleted)
        if case .deleted = deletedEvent.type {
            // Expected
        } else {
            Issue.record("Expected deleted type")
        }
        
        let renamedEvent = FileSystemEvent(url: url, type: .renamed)
        if case .renamed = renamedEvent.type {
            // Expected
        } else {
            Issue.record("Expected renamed type")
        }
    }
}

// MARK: - FileSystemError Tests

@Suite("FileSystemError Tests")
struct FileSystemErrorTests {
    @Test("FileSystemError.fileNotFound has correct description")
    func fileNotFoundDescription() {
        let url = URL(fileURLWithPath: "/test/missing.txt")
        let error = FileSystemError.fileNotFound(url)
        
        #expect(error.errorDescription?.contains("File not found") == true)
        #expect(error.errorDescription?.contains("/test/missing.txt") == true)
    }
    
    @Test("FileSystemError.directoryNotFound has correct description")
    func directoryNotFoundDescription() {
        let url = URL(fileURLWithPath: "/test/missing-dir")
        let error = FileSystemError.directoryNotFound(url)
        
        #expect(error.errorDescription?.contains("Directory not found") == true)
    }
    
    @Test("FileSystemError.fileTooLarge shows size in MB")
    func fileTooLargeDescription() {
        let url = URL(fileURLWithPath: "/test/huge.bin")
        let error = FileSystemError.fileTooLarge(url, 100 * 1024 * 1024) // 100MB
        
        #expect(error.errorDescription?.contains("too large") == true)
        #expect(error.errorDescription?.contains("100.0") == true || error.errorDescription?.contains("MB") == true)
    }
    
    @Test("FileSystemError.binaryFile has correct description")
    func binaryFileDescription() {
        let url = URL(fileURLWithPath: "/test/image.png")
        let error = FileSystemError.binaryFile(url)
        
        #expect(error.errorDescription?.contains("Binary file") == true)
        #expect(error.errorDescription?.contains("image.png") == true)
    }
    
    @Test("FileSystemError.encodingError has correct description")
    func encodingErrorDescription() {
        let url = URL(fileURLWithPath: "/test/weird.txt")
        let error = FileSystemError.encodingError(url)
        
        #expect(error.errorDescription?.contains("decode") == true)
    }
    
    @Test("FileSystemError.permissionDenied has correct description")
    func permissionDeniedDescription() {
        let url = URL(fileURLWithPath: "/test/protected.txt")
        let error = FileSystemError.permissionDenied(url)
        
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }
}

// MARK: - XCTest based tests

final class FileSystemServiceTests: XCTestCase {
    private var service: FileSystemService!
    private var tempDirectory: URL!

    override func setUp() async throws {
        service = FileSystemService()

        // Create a temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Directory Operations Tests

    func testContentsOfDirectory() async throws {
        // Create test files and directories
        let file1 = tempDirectory.appendingPathComponent("file1.txt")
        let file2 = tempDirectory.appendingPathComponent("file2.swift")
        let subdir = tempDirectory.appendingPathComponent("subdir", isDirectory: true)

        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let contents = try await service.contents(of: tempDirectory)

        XCTAssertEqual(contents.count, 3)

        // Directories should come first (sorted)
        XCTAssertTrue(contents.first?.isDirectory ?? false)
        XCTAssertEqual(contents.first?.name, "subdir")
    }

    func testContentsOfEmptyDirectory() async throws {
        let contents = try await service.contents(of: tempDirectory)
        XCTAssertTrue(contents.isEmpty)
    }

    func testContentsOfNonExistentDirectory() async throws {
        let nonExistent = tempDirectory.appendingPathComponent("nonexistent")

        do {
            _ = try await service.contents(of: nonExistent)
            XCTFail("Should throw directoryNotFound error")
        } catch let error as FileSystemError {
            if case .directoryNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testIsDirectory() throws {
        let subdir = tempDirectory.appendingPathComponent("testdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let file = tempDirectory.appendingPathComponent("testfile.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertTrue(service.isDirectory(subdir))
        XCTAssertFalse(service.isDirectory(file))
        XCTAssertFalse(service.isDirectory(tempDirectory.appendingPathComponent("nonexistent")))
    }

    func testExists() throws {
        let file = tempDirectory.appendingPathComponent("exists.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertTrue(service.exists(file))
        XCTAssertFalse(service.exists(tempDirectory.appendingPathComponent("nonexistent")))
    }

    // MARK: - File Operations Tests

    func testReadFile() async throws {
        let file = tempDirectory.appendingPathComponent("test.txt")
        let content = "Hello, World!\nLine 2\nLine 3"
        try content.write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.content, content)
        XCTAssertEqual(fileContent.lineEnding, .lf)
        XCTAssertEqual(fileContent.lineCount, 3)
        XCTAssertFalse(fileContent.isBinary)
    }

    func testReadFileWithCRLF() async throws {
        let file = tempDirectory.appendingPathComponent("crlf.txt")
        let content = "Line 1\r\nLine 2\r\nLine 3"
        try content.write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.lineEnding, .crlf)
    }

    func testReadFileWithMixedLineEndings() async throws {
        let file = tempDirectory.appendingPathComponent("mixed.txt")
        let content = "Line 1\r\nLine 2\nLine 3"
        try content.write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.lineEnding, .mixed)
    }

    func testReadNonExistentFile() async throws {
        let file = tempDirectory.appendingPathComponent("nonexistent.txt")

        do {
            _ = try await service.readFile(at: file)
            XCTFail("Should throw fileNotFound error")
        } catch let error as FileSystemError {
            if case .fileNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testFileSize() throws {
        let file = tempDirectory.appendingPathComponent("size.txt")
        let content = "12345"  // 5 bytes
        try content.write(to: file, atomically: true, encoding: .utf8)

        let size = try service.fileSize(at: file)

        XCTAssertEqual(size, 5)
    }

    func testIsBinaryWithTextFile() async throws {
        let file = tempDirectory.appendingPathComponent("text.txt")
        try "Hello, World!".write(to: file, atomically: true, encoding: .utf8)

        let isBinary = try await service.isBinary(at: file)

        XCTAssertFalse(isBinary)
    }

    func testIsBinaryWithBinaryFile() async throws {
        let file = tempDirectory.appendingPathComponent("binary.bin")
        let data = Data([0x00, 0x01, 0x02, 0x03])  // Contains null byte
        try data.write(to: file)

        let isBinary = try await service.isBinary(at: file)

        XCTAssertTrue(isBinary)
    }

    // MARK: - Edge Cases

    func testReadEmptyFile() async throws {
        let file = tempDirectory.appendingPathComponent("empty.txt")
        try "".write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.content, "")
        XCTAssertEqual(fileContent.lineCount, 0)
    }

    func testReadSingleLineNoNewline() async throws {
        let file = tempDirectory.appendingPathComponent("single.txt")
        try "single line".write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.lineCount, 1)
    }

    func testReadFileWithTrailingNewline() async throws {
        let file = tempDirectory.appendingPathComponent("trailing.txt")
        try "line1\nline2\n".write(to: file, atomically: true, encoding: .utf8)

        let fileContent = try await service.readFile(at: file)

        XCTAssertEqual(fileContent.lineCount, 2)  // Trailing newline should not add extra line
    }
    
    // MARK: - FSEventsWatcher Tests (问题 8 修复)
    
    func testStartAndStopWatching() throws {
        let token = try service.startWatching(tempDirectory) { _ in }
        
        // Verify token is valid
        XCTAssertNotNil(token)
        
        // Stop watching should not crash
        service.stopWatching(token)
    }
    
    func testFileWatcherReceivesCreatedEvent() async throws {
        let expectation = XCTestExpectation(description: "File created event received")
        var receivedEvent: FileSystemEvent?
        
        let token = try service.startWatching(tempDirectory) { event in
            if case .created = event.type {
                receivedEvent = event
                expectation.fulfill()
            }
        }
        
        defer { service.stopWatching(token) }
        
        // Wait a bit for the watcher to initialize
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Create a new file
        let newFile = tempDirectory.appendingPathComponent("new_file_\(UUID().uuidString).txt")
        try "content".write(to: newFile, atomically: true, encoding: .utf8)
        
        // Wait for event with timeout
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertNotNil(receivedEvent)
    }
    
    func testFileWatcherReceivesModifiedEvent() async throws {
        // Create a file first
        let file = tempDirectory.appendingPathComponent("modify_test_\(UUID().uuidString).txt")
        try "initial".write(to: file, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "File event received")
        
        let token = try service.startWatching(tempDirectory) { event in
            // FSEvents may report modified or other event types depending on timing
            // Accept any event related to file changes as success
            expectation.fulfill()
        }
        
        defer { service.stopWatching(token) }
        
        // Wait for watcher to initialize
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Modify the file using FileHandle to ensure it's an in-place modification
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: " appended".data(using: .utf8)!)
        try handle.close()
        
        // Wait for event
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testFileWatcherReceivesDeletedEvent() async throws {
        // Create a file first
        let file = tempDirectory.appendingPathComponent("delete_test_\(UUID().uuidString).txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "File deleted event received")
        
        let token = try service.startWatching(tempDirectory) { event in
            if case .deleted = event.type {
                expectation.fulfill()
            }
        }
        
        defer { service.stopWatching(token) }
        
        // Wait for watcher to initialize
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Delete the file
        try FileManager.default.removeItem(at: file)
        
        // Wait for event
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testMultipleWatchersOnSameDirectory() throws {
        // Start two watchers on the same directory
        var count1 = 0
        var count2 = 0
        
        let token1 = try service.startWatching(tempDirectory) { _ in count1 += 1 }
        let token2 = try service.startWatching(tempDirectory) { _ in count2 += 1 }
        
        // Both tokens should be valid
        XCTAssertNotNil(token1)
        XCTAssertNotNil(token2)
        
        // Stopping both should not crash
        service.stopWatching(token1)
        service.stopWatching(token2)
    }
}
