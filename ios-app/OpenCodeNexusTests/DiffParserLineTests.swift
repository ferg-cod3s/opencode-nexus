import XCTest
@testable import OpenCodeNexus

final class DiffParserLineTests: XCTestCase {

    func testContextLinesIncrementBoth() {
        let input = "  line one\n  line two"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].oldLineNumber, 0)
        XCTAssertEqual(result[0].newLineNumber, 0)
        XCTAssertEqual(result[1].oldLineNumber, 1)
        XCTAssertEqual(result[1].newLineNumber, 1)
    }

    func testAdditionOnlyIncrementsNewLine() {
        let input = "+added"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result[0].oldLineNumber)
        XCTAssertEqual(result[0].newLineNumber, 0)
    }

    func testDeletionOnlyIncrementsOldLine() {
        let input = "-removed"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].oldLineNumber, 0)
        XCTAssertNil(result[0].newLineNumber)
    }

    func testHunkHeaderResetsLineCounters() {
        let input = "@@ -10,3 +20,5 @@\n  context"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].type, .header)
        XCTAssertNil(result[0].oldLineNumber)
        XCTAssertNil(result[0].newLineNumber)
        XCTAssertEqual(result[1].oldLineNumber, 10)
        XCTAssertEqual(result[1].newLineNumber, 20)
    }

    func testMultipleHunksMaintainSeparateCounters() {
        let input = "@@ -1,2 +1,2 @@\n  ctx1\n+add1\n@@ -10,3 +11,3 @@\n  ctx2\n-del2"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 6)

        XCTAssertEqual(result[0].type, .header)
        XCTAssertEqual(result[1].oldLineNumber, 1)
        XCTAssertEqual(result[1].newLineNumber, 1)

        XCTAssertEqual(result[2].type, .addition)
        XCTAssertNil(result[2].oldLineNumber)
        XCTAssertEqual(result[2].newLineNumber, 2)

        XCTAssertEqual(result[3].type, .header)

        XCTAssertEqual(result[4].oldLineNumber, 10)
        XCTAssertEqual(result[4].newLineNumber, 11)

        XCTAssertEqual(result[5].type, .deletion)
        XCTAssertEqual(result[5].oldLineNumber, 11)
        XCTAssertNil(result[5].newLineNumber)
    }

    func testLineNumbersAfterAddition() {
        let input = "@@ -1,1 +1,2 @@\n  ctx\n+added\n  after"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result[1].oldLineNumber, 1)
        XCTAssertEqual(result[1].newLineNumber, 1)
        XCTAssertEqual(result[2].newLineNumber, 2)
        XCTAssertNil(result[2].oldLineNumber)
        XCTAssertEqual(result[3].oldLineNumber, 2)
        XCTAssertEqual(result[3].newLineNumber, 3)
    }

    func testLineNumbersAfterDeletion() {
        let input = "@@ -1,2 +1,1 @@\n  ctx\n-deleted\n  after"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result[1].oldLineNumber, 1)
        XCTAssertEqual(result[1].newLineNumber, 1)
        XCTAssertEqual(result[2].oldLineNumber, 2)
        XCTAssertNil(result[2].newLineNumber)
        XCTAssertEqual(result[3].oldLineNumber, 3)
        XCTAssertEqual(result[3].newLineNumber, 2)
    }

    func testParseHunksFromModelLineNumbers() {
        let hunk = FilePatchHunk(oldStart: 5, oldLines: 3, newStart: 5, newLines: 4, lines: ["  context", "+added", "-removed", "  after"])
        let result = DiffParser.parseHunks([hunk])
        XCTAssertEqual(result.count, 5)

        XCTAssertEqual(result[0].type, .header)
        XCTAssertNil(result[0].oldLineNumber)

        XCTAssertEqual(result[1].oldLineNumber, 5)
        XCTAssertEqual(result[1].newLineNumber, 5)

        XCTAssertEqual(result[2].newLineNumber, 6)
        XCTAssertNil(result[2].oldLineNumber)

        XCTAssertEqual(result[3].oldLineNumber, 6)
        XCTAssertNil(result[3].newLineNumber)

        XCTAssertEqual(result[4].oldLineNumber, 7)
        XCTAssertEqual(result[4].newLineNumber, 7)
    }

    func testNoNewlineMarkerHasNoLineNumbers() {
        let input = "\\ No newline at end of file"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .noNewline)
        XCTAssertNil(result[0].oldLineNumber)
        XCTAssertNil(result[0].newLineNumber)
    }

    func testParseHunksNoNewlineMarker() {
        let hunk = FilePatchHunk(oldStart: 1, oldLines: 1, newStart: 1, newLines: 1, lines: ["+added", "\\ No newline"])
        let result = DiffParser.parseHunks([hunk])
        XCTAssertEqual(result[2].type, .noNewline)
        XCTAssertNil(result[2].oldLineNumber)
        XCTAssertNil(result[2].newLineNumber)
    }
}
