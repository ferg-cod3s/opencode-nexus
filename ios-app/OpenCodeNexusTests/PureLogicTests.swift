import XCTest
@testable import OpenCodeNexus

final class PureLogicTests: XCTestCase {

    // MARK: - DiffParser Tests
    
    func testParseEmptyString() {
        let result = DiffParser.parse("")
        XCTAssertTrue(result.isEmpty)
    }
    
    func testParseContextLines() {
        let input = "  line one\n  line two\n  line three"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0.type == .context })
    }
    
    func testParseAdditionsAndDeletions() {
        let input = "+ added line\n- deleted line\n  context line"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].type, .addition)
        XCTAssertEqual(result[0].content, "added line")
        XCTAssertEqual(result[1].type, .deletion)
        XCTAssertEqual(result[1].content, "deleted line")
        XCTAssertEqual(result[2].type, .context)
        XCTAssertEqual(result[2].content, "context line")
    }
    
    func testParseHunkHeaders() {
        let input = "@@ -10,5 +15,7 @@"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .header)
        XCTAssertEqual(result[0].content, "@@ -10,5 +15,7 @@")
        XCTAssertEqual(result[0].oldLineNumber, 10)
        XCTAssertEqual(result[0].newLineNumber, 15)
    }
    
    func testParseNoNewline() {
        let input = "\\ No newline at end of file"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .noNewline)
        XCTAssertEqual(result[0].content, "\\ No newline at end of file")
    }
    
    func testParseMixedContent() {
        let input = "@@ -5,3 +5,4 @@\n  line one\n+added line\n  line two\n-deleted line\n  line three"
        let result = DiffParser.parse(input)
        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result[0].type, .header)
        XCTAssertEqual(result[1].type, .context)
        XCTAssertEqual(result[2].type, .addition)
        XCTAssertEqual(result[3].type, .context)
        XCTAssertEqual(result[4].type, .deletion)
        XCTAssertEqual(result[5].type, .context)
    }
    
    func testParseHunksFromModel() {
        let hunk = FilePatchHunk(oldStart: 10, oldLines: 5, newStart: 15, newLines: 7, lines: ["  context", "+added", "-removed"])
        let result = DiffParser.parseHunks([hunk])
        XCTAssertEqual(result.count, 4) // header + 3 lines
        XCTAssertEqual(result[0].type, .header)
        XCTAssertEqual(result[1].type, .context)
        XCTAssertEqual(result[2].type, .addition)
        XCTAssertEqual(result[3].type, .deletion)
    }
    
    // MARK: - Date+Relative Tests
    
    func testRelativeStringReturnsNonEmpty() {
        let date = Date()
        XCTAssertFalse(date.relativeString.isEmpty)
    }
    
    func testRelativeStringForPastDate() {
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let relative = pastDate.relativeString
        XCTAssertFalse(relative.isEmpty)
        // Should contain time unit like "h" or "hr"
        XCTAssertTrue(relative.contains("h") || relative.contains("hr"))
    }
    
    // MARK: - SessionStatus Tests
    
    func testIsBusyWhenStatusIsBusy() {
        let status = SessionStatus(status: "busy")
        XCTAssertTrue(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }
    
    func testIsIdleWhenStatusIsIdle() {
        let status = SessionStatus(status: "idle")
        XCTAssertFalse(status.isBusy)
        XCTAssertTrue(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }
    
    func testIsRetryWhenStatusIsRetry() {
        let status = SessionStatus(status: "retry")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertTrue(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }
    
    func testIsWaitingForInputWhenStatusIsWaitingForInput() {
        let status = SessionStatus(status: "waiting-for-input")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertTrue(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertTrue(status.needsAttention) // waiting-for-input needs attention
    }
    
    func testIsFailedWhenStatusIsError() {
        let status = SessionStatus(status: "error")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertTrue(status.isFailed)
        XCTAssertTrue(status.needsAttention) // failed needs attention
    }
    
    func testIsFailedWhenStatusIsFailed() {
        let status = SessionStatus(status: "failed")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertTrue(status.isFailed)
        XCTAssertTrue(status.needsAttention) // failed needs attention
    }
    
    func testNeedsAttentionForFailedAndWaiting() {
        XCTAssertTrue(SessionStatus(status: "failed").needsAttention)
        XCTAssertTrue(SessionStatus(status: "waiting-for-input").needsAttention)
        XCTAssertFalse(SessionStatus(status: "idle").needsAttention)
        XCTAssertFalse(SessionStatus(status: "busy").needsAttention)
    }
    
    // MARK: - Pty Tests
    
    func testIsRunningWhenStatusIsRunning() {
        let pty = Pty(id: "1", title: "Test", command: "test", args: nil, cwd: nil, status: "running", pid: 123)
        XCTAssertTrue(pty.isRunning)
        XCTAssertFalse(pty.hasExited)
    }
    
    func testHasExitedWhenStatusIsExited() {
        let pty = Pty(id: "1", title: "Test", command: "test", args: nil, cwd: nil, status: "exited", pid: 123)
        XCTAssertFalse(pty.isRunning)
        XCTAssertTrue(pty.hasExited)
    }
    
    // MARK: - Theme Tests
    
    func testBorderOverlayReturnsView() {
        let overlay = Theme.borderOverlay(radius: 8)
        // Just verify it doesn't crash when accessed
        XCTAssertNotNil(overlay)
    }
    
    func testThemeColorsExist() {
        _ = Theme.interactiveBlue
        _ = Theme.textStrong
        _ = Theme.textBase
        _ = Theme.textWeak
        _ = Theme.backgroundBase
        _ = Theme.surfaceRaised
        _ = Theme.border
        _ = Theme.borderWeak
        _ = Theme.buttonPrimaryBG
        _ = Theme.buttonPrimaryText
        _ = Theme.errorCritical
        _ = Theme.success
        _ = Theme.brandYuzu
    }
}