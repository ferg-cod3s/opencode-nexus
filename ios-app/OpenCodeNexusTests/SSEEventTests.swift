import XCTest
@testable import OpenCodeNexus

final class SSEEventTests: XCTestCase {

    // MARK: - JSONValue String Parsing

    func testJSONValueStringParsing() throws {
        let json = """
        "hello world"
        """
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value.stringValue, "hello world")
    }

    func testJSONValueStringNilForNonString() throws {
        let json = "42"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertNil(value.stringValue)
    }

    // MARK: - JSONValue Object Parsing

    func testJSONValueObjectParsing() throws {
        let json = """
        {"type": "busy", "count": 5}
        """
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let object = value.objectValue
        XCTAssertNotNil(object)
        XCTAssertEqual(object?["type"]?.stringValue, "busy")
        XCTAssertEqual(object?["count"]?.intValue, 5)
    }

    func testJSONValueObjectNilForNonObject() throws {
        let json = "\"not an object\""
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertNil(value.objectValue)
    }

    func testJSONValueNestedObject() throws {
        let json = """
        {"outer": {"inner": "value"}}
        """
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let outer = value.objectValue
        let inner = outer?["outer"]?.objectValue
        XCTAssertEqual(inner?["inner"]?.stringValue, "value")
    }

    // MARK: - JSONValue Int/Double/Bool/Null Parsing

    func testJSONValueIntParsing() throws {
        let json = "42"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value.intValue, 42)
    }

    func testJSONValueDoubleParsing() throws {
        let json = "3.14"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(Double.self, from: encoded)
        XCTAssertEqual(decoded, 3.14, accuracy: 0.001)
    }

    func testJSONValueBoolTrueParsing() throws {
        let json = "true"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value.boolValue, true)
    }

    func testJSONValueBoolFalseParsing() throws {
        let json = "false"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value.boolValue, false)
    }

    func testJSONValueNullParsing() throws {
        let json = "null"
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value.displayText, "")
    }

    func testJSONValueArrayParsing() throws {
        let json = """
        ["a", "b", "c"]
        """
        let data = json.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode([JSONValue].self, from: encoded)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].stringValue, "a")
        XCTAssertEqual(decoded[1].stringValue, "b")
        XCTAssertEqual(decoded[2].stringValue, "c")
    }

    // MARK: - JSONValue Encoding Roundtrip

    func testJSONValueEncodingRoundtrip() throws {
        let original = JSONValue.object([
            "name": .string("test"),
            "count": .int(10),
            "rate": .double(1.5),
            "active": .bool(true),
            "empty": .null,
            "tags": .array([.string("a"), .string("b")])
        ])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        XCTAssertEqual(decoded.objectValue?["name"]?.stringValue, "test")
        XCTAssertEqual(decoded.objectValue?["count"]?.intValue, 10)
        XCTAssertEqual(decoded.objectValue?["active"]?.boolValue, true)
    }

    // MARK: - SSEEvent Decoding

    func testSSEEventDecodingBasic() throws {
        let json = """
        {"type": "session.created", "properties": {"sessionID": "ses_abc123"}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.eventType, "session.created")
        XCTAssertEqual(event.sessionID, "ses_abc123")
    }

    func testSSEEventDecodingWithNestedStatusObject() throws {
        let json = """
        {"type": "session.status", "properties": {"sessionID": "ses_123", "status": {"type": "busy"}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.eventType, "session.status")
        XCTAssertEqual(event.sessionID, "ses_123")

        let statusObj = event.properties?["status"]?.objectValue
        XCTAssertNotNil(statusObj)
        XCTAssertEqual(statusObj?["type"]?.stringValue, "busy")
    }

    func testSSEEventDecodingWithIdleStatus() throws {
        let json = """
        {"type": "session.status", "properties": {"sessionID": "ses_456", "status": {"type": "idle"}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        let statusObj = event.properties?["status"]?.objectValue
        XCTAssertEqual(statusObj?["type"]?.stringValue, "idle")
    }

    func testSSEEventDecodingWithoutProperties() throws {
        let json = """
        {"type": "server.heartbeat"}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.eventType, "server.heartbeat")
        XCTAssertNil(event.properties)
        XCTAssertNil(event.sessionID)
        XCTAssertNil(event.messageID)
    }

    // MARK: - Server Payload Wrapper Format

    func testSSEEventDecodingWithPayloadWrapper() throws {
        let json = """
        {"directory": "/project", "project": "proj_123", "workspace": "wrk_456", "payload": {"type": "message.part.delta", "properties": {"sessionID": "ses_123", "messageID": "msg_456", "partID": "prt_789", "field": "text", "delta": "Hello"}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.eventType, "message.part.delta")
        XCTAssertEqual(event.directory, "/project")
        XCTAssertEqual(event.project, "proj_123")
        XCTAssertEqual(event.workspace, "wrk_456")
        XCTAssertEqual(event.sessionID, "ses_123")
        XCTAssertEqual(event.messageID, "msg_456")
        XCTAssertEqual(event.properties?["partID"]?.stringValue, "prt_789")
        XCTAssertEqual(event.properties?["delta"]?.stringValue, "Hello")
    }

    func testSSEEventDecodingSyncEvent() throws {
        let json = """
        {"directory": "/project", "payload": {"type": "sync", "syncEvent": {"type": "message.updated.1", "id": "evt_123", "seq": 42, "aggregateID": "sessionID", "data": {"sessionID": "ses_123", "info": {"id": "msg_456"}}}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.eventType, "message.updated.1")
        XCTAssertEqual(event.directory, "/project")
        XCTAssertEqual(event.sessionID, "ses_123")
        XCTAssertEqual(event.properties?["info"]?.objectValue?["id"]?.stringValue, "msg_456")
    }

    func testSSEEventDecodingDirectSyncPayloadPreservesSessionAndMessageIDs() throws {
        let json = """
        {"payload": {"type": "message.updated.1", "id": "evt_sync_123", "seq": 42, "aggregateID": "ses_sync_123", "data": {"info": {"id": "msg_sync_456"}}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)

        XCTAssertEqual(event.eventType, "message.updated.1")
        XCTAssertEqual(event.sessionID, "ses_sync_123")
        XCTAssertEqual(event.messageID, "msg_sync_456")
    }

    func testSSEEventDecodingDirectSyncPayloadFallsBackToSyncEventIDForMessageID() throws {
        let json = """
        {"payload": {"type": "message.updated.1", "id": "evt_sync_message", "aggregateID": "ses_sync_fallback", "data": {}}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)

        XCTAssertEqual(event.sessionID, "ses_sync_fallback")
        XCTAssertEqual(event.messageID, "evt_sync_message")
    }

    // MARK: - SSEEvent sessionID Extraction

    func testSSEEventSessionIDExtraction() throws {
        let json = """
        {"type": "message.updated", "properties": {"sessionID": "ses_xyz789", "messageID": "msg_001"}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.sessionID, "ses_xyz789")
        XCTAssertEqual(event.messageID, "msg_001")
    }

    func testSSEEventSessionIDNilWhenMissing() throws {
        let json = """
        {"type": "session.created", "properties": {}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertNil(event.sessionID)
        XCTAssertNil(event.messageID)
    }

    func testSSEEventSessionIDNilWhenNotString() throws {
        let json = """
        {"type": "test", "properties": {"sessionID": 12345}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertNil(event.sessionID)
    }

    // MARK: - SSEEvent messageID Extraction

    func testSSEEventMessageIDExtraction() throws {
        let json = """
        {"type": "message.removed", "properties": {"sessionID": "ses_abc", "messageID": "msg_removed"}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertEqual(event.messageID, "msg_removed")
    }

    func testSSEEventMessageIDNilWhenNotString() throws {
        let json = """
        {"type": "test", "properties": {"messageID": true}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        XCTAssertNil(event.messageID)
    }
}
