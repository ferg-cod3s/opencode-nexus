import XCTest
@testable import OpenCodeNexus

final class SSEParserTests: XCTestCase {

    // MARK: - Single-line events

    func testSingleLineEvent() {
        var parser = SSEParser()
        let json = "{\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_123\"}}"
        _ = parser.processLine("data: \(json)")
        let result = parser.processLine("")
        guard case .event(let event) = result else {
            XCTFail("Expected event, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(event.type, "session.created")
        XCTAssertEqual(event.sessionID, "ses_123")
    }

    func testEmptyLineBeforeEvent() {
        var parser = SSEParser()
        let result1 = parser.processLine("")
        XCTAssertEqual(result1, .none)

        let json = "{\"type\": \"server.heartbeat\"}"
        let result2 = parser.processLine("data: \(json)")
        XCTAssertEqual(result2, .none)

        let result3 = parser.processLine("")
        guard case .event(let event) = result3 else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(event.type, "server.heartbeat")
    }

    // MARK: - Multi-line data fields

    func testMultiLineDataConcatenation() {
        var parser = SSEParser()
        _ = parser.processLine("data: {\"type\": \"test\", \"properties\": {")
        _ = parser.processLine("data: \"key\": \"value\"")
        _ = parser.processLine("data: }}")
        let result = parser.processLine("")
        guard case .event(let event) = result else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(event.type, "test")
    }

    func testMultiLineWithNewlinesInValue() {
        var parser = SSEParser()
        _ = parser.processLine("data: line1")
        _ = parser.processLine("data: line2")
        let result = parser.processLine("")
        guard case .malformed = result else {
            XCTFail("Expected malformed because concatenated plain text is not valid JSON")
            return
        }
    }

    // MARK: - Comments

    func testCommentsAreIgnored() {
        var parser = SSEParser()
        _ = parser.processLine(": heartbeat")
        _ = parser.processLine(": another comment")
        let json = "{\"type\": \"message.updated\"}"
        _ = parser.processLine("data: \(json)")
        let result = parser.processLine("")
        guard case .event(let event) = result else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(event.type, "message.updated")
    }

    // MARK: - Malformed events

    func testMalformedJSON() {
        var parser = SSEParser()
        let result = parser.processLine("data: not json at all")
        XCTAssertEqual(result, .none)

        let result2 = parser.processLine("")
        guard case .malformed(let data) = result2 else {
            XCTFail("Expected malformed")
            return
        }
        XCTAssertEqual(data, "not json at all")
    }

    func testEmptyDataField() {
        var parser = SSEParser()
        let result = parser.processLine("data: ")
        XCTAssertEqual(result, .none)

        let result2 = parser.processLine("")
        XCTAssertEqual(result2, .none)
    }

    // MARK: - Flush at stream end

    func testFlushReturnsBufferedEvent() {
        var parser = SSEParser()
        let json = "{\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_456\", \"status\": {\"type\": \"idle\"}}}"
        _ = parser.processLine("data: \(json)")
        let result = parser.flush()
        guard case .event(let event) = result else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(event.type, "session.status")
        XCTAssertEqual(event.sessionID, "ses_456")
    }

    func testFlushReturnsNoneWhenEmpty() {
        var parser = SSEParser()
        let result = parser.flush()
        XCTAssertEqual(result, .none)
    }

    func testFlushReturnsMalformedForInvalidJSON() {
        var parser = SSEParser()
        _ = parser.processLine("data: bad json")
        let result = parser.flush()
        guard case .malformed(let data) = result else {
            XCTFail("Expected malformed")
            return
        }
        XCTAssertEqual(data, "bad json")
    }

    // MARK: - Done event

    func testDoneEventParsesCorrectly() {
        var parser = SSEParser()
        let json = "{\"type\": \"done\"}"
        _ = parser.processLine("data: \(json)")
        let result = parser.processLine("")
        guard case .event(let event) = result else {
            XCTFail("Expected event")
            return
        }
        XCTAssertEqual(event.type, "done")
    }
}
