import XCTest
@testable import OpenCodeNexus

final class SSEStreamTests: XCTestCase {

    // MARK: - Parse Multi-Line SSE Data Stream

    func testParseMultiLineSSEStream() async throws {
        let lines = [
            "data: {\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_1\"}}",
            "data: {\"type\": \"message.updated\", \"properties\": {\"sessionID\": \"ses_1\", \"messageID\": \"msg_1\"}}",
            "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_1\", \"status\": {\"type\": \"busy\"}}}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].type, "session.created")
        XCTAssertEqual(events[1].type, "message.updated")
        XCTAssertEqual(events[2].type, "session.status")
    }

    // MARK: - Handle "data: " Prefixed Lines

    func testDataPrefixedLinesAreParsed() {
        let lines = [
            "data: {\"type\": \"server.heartbeat\"}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, "server.heartbeat")
    }

    // MARK: - Skip Non-Data Lines

    func testCommentsAreSkipped() {
        let lines: [String] = [
            ": this is a comment",
            "data: {\"type\": \"server.heartbeat\"}",
            ": another comment"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
    }

    func testEventLinesAreSkipped() {
        let lines: [String] = [
            "event: message",
            "data: {\"type\": \"session.created\"}",
            "id: 123",
            "retry: 5000"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, "session.created")
    }

    func testEmptyLinesAreSkipped() {
        let lines: [String] = [
            "",
            "data: {\"type\": \"test\"}",
            "",
            ""
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Handle Malformed JSON Gracefully

    func testMalformedJSONIsSkipped() {
        let lines: [String] = [
            "data: not valid json",
            "data: {\"type\": \"valid.event\"}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, "valid.event")
    }

    func testEmptyDataFieldIsSkipped() {
        let lines: [String] = [
            "data: ",
            "data: {\"type\": \"session.created\"}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
    }

    func testTruncatedJSONIsSkipped() {
        let lines: [String] = [
            "data: {\"type\": \"incomplete",
            "data: {\"type\": \"session.created\"}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Realistic Server Event Stream

    func testRealisticServerEventStream() {
        let lines: [String] = [
            ": OpenCode SSE Stream",
            "",
            "event: message",
            "data: {\"type\": \"server.connected\"}",
            "",
            "data: {\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_abc\"}}",
            "",
            "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_abc\", \"status\": {\"type\": \"busy\"}}}",
            "",
            "data: {\"type\": \"message.updated\", \"properties\": {\"sessionID\": \"ses_abc\", \"messageID\": \"msg_001\"}}",
            "",
            "data: {\"type\": \"message.part.updated\", \"properties\": {\"sessionID\": \"ses_abc\", \"messageID\": \"msg_001\"}}",
            "",
            "data: {\"type\": \"session.diff\", \"properties\": {\"sessionID\": \"ses_abc\"}}",
            "",
            "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_abc\", \"status\": {\"type\": \"idle\"}}}",
            "",
            "data: {\"type\": \"server.heartbeat\"}",
            "",
            ": keepalive",
            "data: {\"type\": \"server.heartbeat\"}"
        ]
        let events = parseSSELines(lines)

        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(events[0].type, "server.connected")
        XCTAssertEqual(events[1].type, "session.created")
        XCTAssertEqual(events[2].type, "session.status")
        XCTAssertEqual(events[2].properties?["status"]?.objectValue?["type"]?.stringValue, "busy")
        XCTAssertEqual(events[3].type, "message.updated")
        XCTAssertEqual(events[4].type, "message.part.updated")
        XCTAssertEqual(events[5].type, "session.diff")
        XCTAssertEqual(events[6].type, "session.status")
        XCTAssertEqual(events[6].properties?["status"]?.objectValue?["type"]?.stringValue, "idle")
        XCTAssertEqual(events[7].type, "server.heartbeat")
    }

    func testMultipleSessionsInStream() {
        let lines: [String] = [
            "data: {\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_1\"}}",
            "data: {\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_2\"}}",
            "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_1\", \"status\": {\"type\": \"busy\"}}}",
            "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_2\", \"status\": {\"type\": \"idle\"}}}"
        ]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0].sessionID, "ses_1")
        XCTAssertEqual(events[1].sessionID, "ses_2")
        XCTAssertEqual(events[2].properties?["status"]?.objectValue?["type"]?.stringValue, "busy")
        XCTAssertEqual(events[3].properties?["status"]?.objectValue?["type"]?.stringValue, "idle")
    }

    // MARK: - Permission Event Stream

    func testPermissionEventParsing() {
        let json = """
        {"type": "permission.asked", "properties": {"id": "perm_1", "type": "file_write", "pattern": "src/main.swift", "sessionID": "ses_1", "messageID": "msg_1", "title": "Write to file", "time": {"created": 1700000000000}}}
        """
        let lines = ["data: \(json)"]
        let events = parseSSELines(lines)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, "permission.asked")
        XCTAssertEqual(events[0].properties?["sessionID"]?.stringValue, "ses_1")
    }

    // MARK: - Helper

    private func parseSSELines(_ lines: [String]) -> [SSEEvent] {
        var events: [SSEEvent] = []
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                guard !jsonString.isEmpty,
                      let jsonData = jsonString.data(using: .utf8),
                      let event = try? JSONDecoder().decode(SSEEvent.self, from: jsonData) else {
                    continue
                }
                events.append(event)
            }
        }
        return events
    }
}
