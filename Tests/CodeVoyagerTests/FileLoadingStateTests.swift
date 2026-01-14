import XCTest
@testable import CodeVoyager

final class FileLoadingStateTests: XCTestCase {
    // MARK: - All Case Coverage Tests

    func testIdleState() {
        let state = FileLoadingState.idle
        XCTAssertEqual(state, .idle)
    }

    func testLoadingState() {
        let state = FileLoadingState.loading
        XCTAssertEqual(state, .loading)
    }

    func testLoadedState() {
        let state = FileLoadingState.loaded
        XCTAssertEqual(state, .loaded)
    }

    func testBinaryFileState() {
        let state = FileLoadingState.binaryFile
        XCTAssertEqual(state, .binaryFile)
    }

    func testLargeFileState() {
        let size: Int64 = 100 * 1024 * 1024  // 100MB
        let state = FileLoadingState.largeFile(size: size)

        if case .largeFile(let actualSize) = state {
            XCTAssertEqual(actualSize, size)
        } else {
            XCTFail("Expected largeFile state")
        }
    }

    func testErrorState() {
        let errorMessage = "File not found"
        let state = FileLoadingState.error(errorMessage)

        if case .error(let message) = state {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Equatable Tests

    func testEquality() {
        XCTAssertEqual(FileLoadingState.idle, FileLoadingState.idle)
        XCTAssertEqual(FileLoadingState.loading, FileLoadingState.loading)
        XCTAssertEqual(FileLoadingState.loaded, FileLoadingState.loaded)
        XCTAssertEqual(FileLoadingState.binaryFile, FileLoadingState.binaryFile)
        XCTAssertEqual(
            FileLoadingState.largeFile(size: 50_000_000),
            FileLoadingState.largeFile(size: 50_000_000)
        )
        XCTAssertEqual(
            FileLoadingState.error("Error"),
            FileLoadingState.error("Error")
        )
    }

    func testInequality() {
        XCTAssertNotEqual(FileLoadingState.idle, FileLoadingState.loading)
        XCTAssertNotEqual(FileLoadingState.loaded, FileLoadingState.binaryFile)
        XCTAssertNotEqual(
            FileLoadingState.largeFile(size: 100),
            FileLoadingState.largeFile(size: 200)
        )
        XCTAssertNotEqual(
            FileLoadingState.error("Error 1"),
            FileLoadingState.error("Error 2")
        )
    }

    // MARK: - Edge Cases

    func testLargeFileSizeEdgeCases() {
        let zeroSize = FileLoadingState.largeFile(size: 0)
        if case .largeFile(let size) = zeroSize {
            XCTAssertEqual(size, 0)
        } else {
            XCTFail("Expected largeFile state")
        }

        let maxSize = FileLoadingState.largeFile(size: Int64.max)
        if case .largeFile(let size) = maxSize {
            XCTAssertEqual(size, Int64.max)
        } else {
            XCTFail("Expected largeFile state")
        }
    }

    func testErrorMessageEdgeCases() {
        let emptyError = FileLoadingState.error("")
        if case .error(let message) = emptyError {
            XCTAssertEqual(message, "")
        } else {
            XCTFail("Expected error state")
        }

        let longError = FileLoadingState.error(String(repeating: "x", count: 1000))
        if case .error(let message) = longError {
            XCTAssertEqual(message.count, 1000)
        } else {
            XCTFail("Expected error state")
        }
    }
}
