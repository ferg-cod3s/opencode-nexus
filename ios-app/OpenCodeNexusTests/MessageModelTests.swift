import XCTest
@testable import OpenCodeNexus

final class MessageModelTests: XCTestCase {

    // MARK: - MessageEnvelope Decoding

    func testMessageEnvelopeDecoding() throws {
        let json = """
        {
            "info": {
                "id": "msg_001",
                "role": "user",
                "time": {"created": 1700000000000}
            },
            "parts": [
                {"type": "text", "text": "Hello, world!"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
        XCTAssertEqual(envelope.id, "msg_001")
        XCTAssertEqual(envelope.parts.count, 1)
        XCTAssertEqual(envelope.info.role, .user)
    }

    func testMessageEnvelopeIDMatchesInfoID() throws {
        let envelope = try makeMessageEnvelope(id: "msg_abc")
        XCTAssertEqual(envelope.id, "msg_abc")
        XCTAssertEqual(envelope.id, envelope.info.id)
    }

    // MARK: - MessageRole

    func testMessageRoleUser() throws {
        let json = """
        {"id": "m1", "role": "user", "time": {"created": 0}}
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(MessageInfo.self, from: data)
        XCTAssertEqual(info.role, .user)
        XCTAssertTrue(info.isUser)
        XCTAssertFalse(info.isAssistant)
    }

    func testMessageRoleAssistant() throws {
        let json = """
        {"id": "m2", "role": "assistant", "time": {"created": 0}}
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(MessageInfo.self, from: data)
        XCTAssertEqual(info.role, .assistant)
        XCTAssertFalse(info.isUser)
        XCTAssertTrue(info.isAssistant)
    }

    // MARK: - MessageInfo Computed Properties

    func testMessageInfoIsUser() throws {
        let info = try makeMessageInfo(role: "user")
        XCTAssertTrue(info.isUser)
        XCTAssertFalse(info.isAssistant)
    }

    func testMessageInfoIsAssistant() throws {
        let info = try makeMessageInfo(role: "assistant")
        XCTAssertFalse(info.isUser)
        XCTAssertTrue(info.isAssistant)
    }

    func testMessageInfoAllFields() throws {
        let json = """
        {
            "id": "msg_full",
            "sessionID": "ses_123",
            "role": "assistant",
            "time": {"created": 1700000000000, "completed": 1700000001000},
            "parentID": "msg_parent",
            "modelID": "gpt-4o",
            "providerID": "openai",
            "agent": "coder",
            "model": {"providerID": "openai", "modelID": "gpt-4o"},
            "system": "You are helpful",
            "mode": "code",
            "cost": 0.003,
            "tokens": {"input": 100, "output": 50, "reasoning": 10, "cache": {"read": 20, "write": 30}},
            "error": {"name": "RateLimitError", "data": {"message": "Too many requests", "statusCode": 429}},
            "summary": {"title": "Summary", "body": "Did stuff"},
            "path": {"cwd": "/home", "root": "/"}
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(MessageInfo.self, from: data)

        XCTAssertEqual(info.id, "msg_full")
        XCTAssertEqual(info.sessionID, "ses_123")
        XCTAssertEqual(info.parentID, "msg_parent")
        XCTAssertEqual(info.modelID, "gpt-4o")
        XCTAssertEqual(info.providerID, "openai")
        XCTAssertEqual(info.agent, "coder")
        XCTAssertEqual(info.model?.providerID, "openai")
        XCTAssertEqual(info.system, "You are helpful")
        XCTAssertEqual(info.mode, "code")
        XCTAssertEqual(info.cost, 0.003)
        XCTAssertEqual(info.tokens?.input, 100)
        XCTAssertEqual(info.tokens?.output, 50)
        XCTAssertEqual(info.tokens?.reasoning, 10)
        XCTAssertEqual(info.tokens?.cache?.read, 20)
        XCTAssertEqual(info.error?.name, "RateLimitError")
        XCTAssertEqual(info.error?.displayMessage, "Too many requests")
        XCTAssertEqual(info.summary?.title, "Summary")
        XCTAssertEqual(info.path?.cwd, "/home")
    }

    // MARK: - Part Type Checking

    func testPartIsText() throws {
        let part = try makePart(type: "text")
        XCTAssertTrue(part.isText)
        XCTAssertFalse(part.isTool)
    }

    func testPartIsTool() throws {
        let part = try makePart(type: "tool")
        XCTAssertTrue(part.isTool)
        XCTAssertFalse(part.isText)
    }

    func testPartIsReasoning() throws {
        let part = try makePart(type: "reasoning")
        XCTAssertTrue(part.isReasoning)
    }

    func testPartIsStepStart() throws {
        let part = try makePart(type: "step-start")
        XCTAssertTrue(part.isStepStart)
    }

    func testPartIsStepFinish() throws {
        let part = try makePart(type: "step-finish")
        XCTAssertTrue(part.isStepFinish)
    }

    func testPartIsPatch() throws {
        let part = try makePart(type: "patch")
        XCTAssertTrue(part.isPatch)
    }

    func testPartIsSnapshot() throws {
        let part = try makePart(type: "snapshot")
        XCTAssertTrue(part.isSnapshot)
    }

    func testPartIsAgent() throws {
        let part = try makePart(type: "agent")
        XCTAssertTrue(part.isAgent)
    }

    func testPartIsFile() throws {
        let part = try makePart(type: "file")
        XCTAssertTrue(part.isFile)
    }

    func testPartIsCompaction() throws {
        let part = try makePart(type: "compaction")
        XCTAssertTrue(part.isCompaction)
    }

    func testPartIsRetry() throws {
        let part = try makePart(type: "retry")
        XCTAssertTrue(part.isRetry)
    }

    func testPartIsSubtask() throws {
        let part = try makePart(type: "subtask")
        XCTAssertTrue(part.isSubtask)
    }

    func testPartDisplayText() throws {
        let part = try makePart(type: "text", text: "Hello!")
        XCTAssertEqual(part.displayText, "Hello!")
    }

    func testPartDisplayTextWhenNil() throws {
        let part = try makePart(type: "tool")
        XCTAssertEqual(part.displayText, "")
    }

    // MARK: - ToolState Status Checks

    func testToolStateIsPending() throws {
        let state = try makeToolState(status: "pending")
        XCTAssertTrue(state.isPending)
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.isCompleted)
        XCTAssertFalse(state.isError)
    }

    func testToolStateIsRunning() throws {
        let state = try makeToolState(status: "running")
        XCTAssertTrue(state.isRunning)
    }

    func testToolStateIsCompleted() throws {
        let state = try makeToolState(status: "completed")
        XCTAssertTrue(state.isCompleted)
    }

    func testToolStateIsError() throws {
        let state = try makeToolState(status: "error")
        XCTAssertTrue(state.isError)
    }

    func testToolStateAllFields() throws {
        let json = """
        {
            "status": "completed",
            "input": {"path": "/tmp/file"},
            "output": "Done",
            "title": "Read file",
            "error": null,
            "time": {"start": 1700000000000, "end": 1700000001000},
            "metadata": {"key": "value"},
            "attachments": [{"mime": "image/png", "filename": "screenshot.png", "url": "https://example.com/img.png"}]
        }
        """
        let data = json.data(using: .utf8)!
        let state = try JSONDecoder().decode(ToolState.self, from: data)

        XCTAssertEqual(state.status, "completed")
        XCTAssertEqual(state.output, "Done")
        XCTAssertEqual(state.title, "Read file")
        XCTAssertNotNil(state.input)
        XCTAssertNotNil(state.time)
        XCTAssertEqual(state.time?.start, 1_700_000_000_000)
        XCTAssertEqual(state.attachments?.count, 1)
        XCTAssertEqual(state.attachments?.first?.filename, "screenshot.png")
    }

    // MARK: - TokenInfo

    func testTokenInfoDecoding() throws {
        let json = """
        {"input": 500, "output": 200, "reasoning": 50, "cache": {"read": 100, "write": 80}}
        """
        let data = json.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(TokenInfo.self, from: data)
        XCTAssertEqual(tokens.input, 500)
        XCTAssertEqual(tokens.output, 200)
        XCTAssertEqual(tokens.reasoning, 50)
        XCTAssertEqual(tokens.cache?.read, 100)
        XCTAssertEqual(tokens.cache?.write, 80)
    }

    func testTokenInfoMinimalDecoding() throws {
        let json = """
        {}
        """
        let data = json.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(TokenInfo.self, from: data)
        XCTAssertNil(tokens.input)
        XCTAssertNil(tokens.output)
        XCTAssertNil(tokens.reasoning)
        XCTAssertNil(tokens.cache)
    }

    // MARK: - MessageError displayMessage

    func testMessageErrorDisplayMessageFromData() throws {
        let json = """
        {"name": "APIError", "data": {"message": "Rate limited", "statusCode": 429}}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(MessageError.self, from: data)
        XCTAssertEqual(error.displayMessage, "Rate limited")
    }

    func testMessageErrorDisplayMessageFallbackToName() throws {
        let json = """
        {"name": "TimeoutError"}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(MessageError.self, from: data)
        XCTAssertEqual(error.displayMessage, "TimeoutError")
    }

    func testMessageErrorDisplayMessageFallbackToDefault() throws {
        let json = """
        {}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(MessageError.self, from: data)
        XCTAssertEqual(error.displayMessage, "Unknown error")
    }

    func testMessageErrorDataFields() throws {
        let json = """
        {"name": "Test", "data": {"message": "msg", "providerID": "openai", "statusCode": 500, "isRetryable": true}}
        """
        let data = json.data(using: .utf8)!
        let error = try JSONDecoder().decode(MessageError.self, from: data)
        XCTAssertEqual(error.data?.providerID, "openai")
        XCTAssertEqual(error.data?.statusCode, 500)
        XCTAssertEqual(error.data?.isRetryable, true)
    }

    // MARK: - MessageTimeInfo

    func testMessageTimeInfoCreatedDate() throws {
        let json = """
        {"created": 1700000000000, "completed": 1700000005000}
        """
        let data = json.data(using: .utf8)!
        let timeInfo = try JSONDecoder().decode(MessageTimeInfo.self, from: data)
        XCTAssertEqual(timeInfo.createdDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(timeInfo.completedDate, Date(timeIntervalSince1970: 1_700_000_005))
    }

    // MARK: - Helpers

    private func makeMessageEnvelope(id: String, role: String = "user") throws -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "role": "\(role)", "time": {"created": 0}},
            "parts": []
        }
        """
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(MessageEnvelope.self, from: data)
    }

    private func makeMessageInfo(role: String) throws -> MessageInfo {
        let json = """
        {"id": "msg_test", "role": "\(role)", "time": {"created": 0}}
        """
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(MessageInfo.self, from: data)
    }

    private func makePart(type: String, text: String? = nil) throws -> Part {
        var json = """
        {"type": "\(type)"
        """
        if let text {
            json += ", \"text\": \"\(text)\""
        }
        json += "}"
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Part.self, from: data)
    }

    private func makeToolState(status: String) throws -> ToolState {
        let json = """
        {"status": "\(status)"}
        """
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(ToolState.self, from: data)
    }
}
