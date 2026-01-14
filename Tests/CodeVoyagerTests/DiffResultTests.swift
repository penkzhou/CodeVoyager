import Foundation
import Testing
@testable import CodeVoyager

@Suite("DiffResult Tests")
struct DiffResultTests {
    @Test("DiffResult extracts fileName from path")
    func fileName() {
        let diff = DiffResult(
            filePath: "src/components/Button.swift",
            hunks: []
        )
        #expect(diff.fileName == "Button.swift")
    }

    @Test("DiffResult calculates total additions correctly")
    func totalAdditions() {
        let diff = DiffResult(
            filePath: "test.swift",
            hunks: [
                makeHunk(additions: 5, deletions: 2),
                makeHunk(additions: 3, deletions: 1),
                makeHunk(additions: 2, deletions: 0)
            ]
        )
        #expect(diff.totalAdditions == 10)
    }

    @Test("DiffResult calculates total deletions correctly")
    func totalDeletions() {
        let diff = DiffResult(
            filePath: "test.swift",
            hunks: [
                makeHunk(additions: 5, deletions: 2),
                makeHunk(additions: 3, deletions: 1),
                makeHunk(additions: 2, deletions: 4)
            ]
        )
        #expect(diff.totalDeletions == 7)
    }

    @Test("DiffResult handles empty hunks")
    func emptyHunks() {
        let diff = DiffResult(filePath: "test.swift", hunks: [])
        #expect(diff.totalAdditions == 0)
        #expect(diff.totalDeletions == 0)
    }

    // MARK: - Helper

    private func makeHunk(additions: Int, deletions: Int) -> DiffHunk {
        var lines: [DiffLine] = []
        for _ in 0..<additions {
            lines.append(DiffLine(content: "+added", type: .addition))
        }
        for _ in 0..<deletions {
            lines.append(DiffLine(content: "-deleted", type: .deletion))
        }
        return DiffHunk(
            oldStart: 1,
            oldCount: deletions,
            newStart: 1,
            newCount: additions,
            lines: lines
        )
    }
}

@Suite("DiffHunk Tests")
struct DiffHunkTests {
    @Test("DiffHunk counts additions correctly")
    func additions() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 5,
            newStart: 1,
            newCount: 8,
            lines: [
                DiffLine(content: " context", type: .context),
                DiffLine(content: "+added1", type: .addition),
                DiffLine(content: "+added2", type: .addition),
                DiffLine(content: "-deleted", type: .deletion),
                DiffLine(content: " context", type: .context)
            ]
        )
        #expect(hunk.additions == 2)
    }

    @Test("DiffHunk counts deletions correctly")
    func deletions() {
        let hunk = DiffHunk(
            oldStart: 1,
            oldCount: 5,
            newStart: 1,
            newCount: 3,
            lines: [
                DiffLine(content: "-deleted1", type: .deletion),
                DiffLine(content: "-deleted2", type: .deletion),
                DiffLine(content: "-deleted3", type: .deletion),
                DiffLine(content: "+added", type: .addition)
            ]
        )
        #expect(hunk.deletions == 3)
    }
}

@Suite("DiffDisplayMode Tests")
struct DiffDisplayModeTests {
    @Test("DiffDisplayMode has correct icons")
    func icons() {
        #expect(DiffDisplayMode.sideBySide.icon == "rectangle.split.2x1")
        #expect(DiffDisplayMode.unified.icon == "rectangle")
    }

    @Test("DiffDisplayMode has correct raw values")
    func rawValues() {
        #expect(DiffDisplayMode.sideBySide.rawValue == "Side by Side")
        #expect(DiffDisplayMode.unified.rawValue == "Unified")
    }
}
