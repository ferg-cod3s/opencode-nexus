import XCTest
@testable import OpenCodeNexus

@MainActor
final class ChatViewModelTests: XCTestCase {

    private var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
        viewModel.configure(with: nil)
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - session.status Event (Nested Object Parsing)

    func testHandleEventSessionStatusParsesBusyObject() {
        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_123"),
                "status": .object(["type": .string("busy")])
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.sessionStatuses["ses_123"]?.status, "busy")
    }

    func testHandleEventSessionStatusParsesIdleObject() {
        viewModel.isSending = true

        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_abc"),
                "status": .object(["type": .string("idle")])
            ]
        )
        viewModel.selectedSessionId = "ses_abc"
        viewModel.handleEvent(event)

        XCTAssertEqual(viewModel.sessionStatuses["ses_abc"]?.status, "idle")
        XCTAssertFalse(viewModel.isSending)
    }

    func testHandleEventSessionStatusWithStatusStringNotObject() {
        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_1"),
                "status": .string("busy")
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertNil(viewModel.sessionStatuses["ses_1"])
    }

    // MARK: - isSending Set to False on Idle

    func testIsSendingSetToFalseWhenSessionGoesIdle() {
        viewModel.selectedSessionId = "ses_x"
        viewModel.isSending = true

        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_x"),
                "status": .object(["type": .string("idle")])
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertFalse(viewModel.isSending)
    }

    func testIsSendingNotChangedForOtherSessionIdle() {
        viewModel.selectedSessionId = "ses_selected"
        viewModel.isSending = true

        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_other"),
                "status": .object(["type": .string("idle")])
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertTrue(viewModel.isSending)
    }

    func testIsSendingNotChangedWhenStatusBusy() {
        viewModel.selectedSessionId = "ses_x"
        viewModel.isSending = false

        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_x"),
                "status": .object(["type": .string("busy")])
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertFalse(viewModel.isSending)
    }

    // MARK: - sessionStatuses Updates

    func testSessionStatusesUpdatedFromSessionStatusEvent() {
        let event = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_1"),
                "status": .object(["type": .string("busy")])
            ]
        )
        viewModel.handleEvent(event)

        let event2 = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_2"),
                "status": .object(["type": .string("idle")])
            ]
        )
        viewModel.handleEvent(event2)

        XCTAssertEqual(viewModel.sessionStatuses["ses_1"]?.status, "busy")
        XCTAssertEqual(viewModel.sessionStatuses["ses_2"]?.status, "idle")
    }

    func testSessionStatusOverwrittenOnUpdate() {
        let event1 = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_1"),
                "status": .object(["type": .string("busy")])
            ]
        )
        viewModel.handleEvent(event1)
        XCTAssertEqual(viewModel.sessionStatuses["ses_1"]?.status, "busy")

        let event2 = makeEvent(
            type: "session.status",
            properties: [
                "sessionID": .string("ses_1"),
                "status": .object(["type": .string("idle")])
            ]
        )
        viewModel.handleEvent(event2)
        XCTAssertEqual(viewModel.sessionStatuses["ses_1"]?.status, "idle")
    }

    // MARK: - session.created/updated/deleted Triggers

    func testSessionCreatedEventDoesNotCrash() {
        let event = makeEvent(
            type: "session.created",
            properties: nil
        )
        viewModel.handleEvent(event)
    }

    func testSessionUpdatedEventDoesNotCrash() {
        let event = makeEvent(
            type: "session.updated",
            properties: ["sessionID": .string("ses_1")]
        )
        viewModel.handleEvent(event)
    }

    func testSessionDeletedEventDoesNotCrash() {
        let event = makeEvent(
            type: "session.deleted",
            properties: ["sessionID": .string("ses_1")]
        )
        viewModel.handleEvent(event)
    }

    // MARK: - message.updated Events

    func testMessageUpdatedForSelectedSessionDoesNotCrash() {
        viewModel.selectedSessionId = "ses_1"
        let event = makeEvent(
            type: "message.updated",
            properties: [
                "sessionID": .string("ses_1"),
                "messageID": .string("msg_1")
            ]
        )
        viewModel.handleEvent(event)
    }

    // MARK: - message.updated for Other Sessions Ignored

    func testMessageUpdatedForOtherSessionIsIgnored() {
        viewModel.selectedSessionId = "ses_selected"
        viewModel.messages = [makeMessageEnvelope(id: "msg_1")]

        let event = makeEvent(
            type: "message.updated",
            properties: [
                "sessionID": .string("ses_other"),
                "messageID": .string("msg_1")
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.messages.count, 1)
    }

    func testPermissionAskedAddsCurrentPermissionRequestShape() {
        let event = makeEvent(
            type: "permission.asked",
            properties: [
                "id": .string("perm_1"),
                "sessionID": .string("ses_1"),
                "permission": .string("edit"),
                "patterns": .array([.string("/tmp/file.txt")]),
                "metadata": .object(["file": .string("/tmp/file.txt")]),
                "always": .array([]),
                "tool": .object([
                    "messageID": .string("msg_1"),
                    "callID": .string("call_1")
                ])
            ]
        )

        viewModel.handleEvent(event)

        XCTAssertEqual(viewModel.pendingPermissions.count, 1)
        XCTAssertEqual(viewModel.pendingPermissions.first?.id, "perm_1")
        XCTAssertEqual(viewModel.pendingPermissions.first?.sessionID, "ses_1")
        XCTAssertEqual(viewModel.pendingPermissions.first?.type, "edit")
        XCTAssertEqual(viewModel.pendingPermissions.first?.messageID, "msg_1")
        XCTAssertEqual(viewModel.pendingPermissions.first?.callID, "call_1")
    }

    func testSlashCommandDetectionIgnoresAttachmentsState() {
        XCTAssertTrue(viewModel.isSlashCommandInput("/commit changes"))
        XCTAssertTrue(viewModel.isSlashCommandInput("  /commit changes"))
        XCTAssertFalse(viewModel.isSlashCommandInput("please /commit changes"))
    }

    func testSendAsyncMessageIncludesStableMessageID() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let expectedID = "msg_ios_test"
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/prompt_async")
            let body = try chatViewModelTestRequestBody(from: request)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["messageID"] as? String, expectedID)
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)

        try await client.sendAsyncMessage(sessionId: "ses_1", text: "hello", messageID: expectedID)
    }

    func testGetMessagesAddsLimitAndBeforeQuery() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/session/ses_1/message")
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(query["limit"], "50")
            XCTAssertEqual(query["before"], "msg_old")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)

        let messages = try await client.getMessages(sessionId: "ses_1", limit: 50, before: "msg_old")

        XCTAssertTrue(messages.isEmpty)
    }

    func testLoadSessionsFallsBackToUnscopedSessionQueryWhenProjectsUnavailable() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
        let sessionJSON = """
        [{"id":"ses_fallback","slug":"fallback","version":"1.0.0","projectID":"global","directory":"/fallback","title":"Fallback","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}]
        """

        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if components.path == "/session" {
                let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                XCTAssertNil(query["directory"])
                XCTAssertEqual(query["roots"], "true")
                XCTAssertEqual(query["limit"], "50")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(sessionJSON.utf8))
            }
            if components.path == "/project" || components.path == "/project/current" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data("error".utf8))
            }
            XCTFail("Unexpected path: \(components.path)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        viewModel.configure(with: client)
        await viewModel.loadSessions()

        XCTAssertEqual(viewModel.sessions.map(\.id), ["ses_fallback"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadSessionsPreservesSelectedSessionOmittedDuringActiveSend() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
        let activeSession = try decodeSession(id: "ses_active", title: "Active", directory: "/project", updated: 2)
        let otherSessionJSON = """
        [{"id":"ses_other","slug":"other","version":"1.0.0","projectID":"project","directory":"/project","title":"Other","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}]
        """

        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if components.path == "/session" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(otherSessionJSON.utf8))
            }
            XCTFail("Unexpected path: \(components.path)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        viewModel.configure(with: client)
        viewModel.projects = [try decodeProject(worktree: "/project")]
        viewModel.sessions = [activeSession]
        viewModel.selectedSessionId = activeSession.id
        viewModel.isSending = true

        await viewModel.loadSessions()

        XCTAssertEqual(viewModel.selectedSession?.id, "ses_active")
        XCTAssertEqual(Set(viewModel.sessions.map(\.id)), Set(["ses_active", "ses_other"]))
    }

    func testNilSelectionDuringActiveSendRestoresSelectionWithoutClearingState() {
        viewModel.selectedSessionId = "ses_active"
        viewModel.messages = [makeMessageEnvelope(id: "msg_1")]
        viewModel.todos = [Todo(id: "todo_1", content: "Keep", status: "pending", priority: "high")]
        viewModel.isSending = true

        viewModel.selectedSessionId = nil

        XCTAssertEqual(viewModel.selectedSessionId, "ses_active")
        XCTAssertEqual(viewModel.messages.map(\.id), ["msg_1"])
        XCTAssertEqual(viewModel.todos.map(\.id), ["todo_1"])
        XCTAssertTrue(viewModel.isSending)
    }

    // MARK: - session.error Sets isSending to False

    func testSessionErrorSetsIsSendingFalse() {
        viewModel.selectedSessionId = "ses_err"
        viewModel.isSending = true

        let event = makeEvent(
            type: "session.error",
            properties: ["sessionID": .string("ses_err")]
        )
        viewModel.handleEvent(event)
        XCTAssertFalse(viewModel.isSending)
    }

    func testSessionErrorDoesNotAffectOtherSession() {
        viewModel.selectedSessionId = "ses_other"
        viewModel.isSending = true

        let event = makeEvent(
            type: "session.error",
            properties: ["sessionID": .string("ses_err")]
        )
        viewModel.handleEvent(event)
        XCTAssertTrue(viewModel.isSending)
    }

    // MARK: - message.removed Removes Message

    func testMessageRemovedRemovesMessage() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.messages = [
            makeMessageEnvelope(id: "msg_1"),
            makeMessageEnvelope(id: "msg_2"),
            makeMessageEnvelope(id: "msg_3")
        ]

        let event = makeEvent(
            type: "message.removed",
            properties: [
                "sessionID": .string("ses_1"),
                "messageID": .string("msg_2")
            ]
        )
        viewModel.handleEvent(event)

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].id, "msg_1")
        XCTAssertEqual(viewModel.messages[1].id, "msg_3")
    }

    func testMessageRemovedIgnoredForOtherSession() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.messages = [
            makeMessageEnvelope(id: "msg_1"),
            makeMessageEnvelope(id: "msg_2")
        ]

        let event = makeEvent(
            type: "message.removed",
            properties: [
                "sessionID": .string("ses_other"),
                "messageID": .string("msg_1")
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.messages.count, 2)
    }

    // MARK: - Unknown Event Types

    func testUnknownEventTypeDoesNotCrash() {
        let event = makeEvent(type: "unknown.event", properties: nil)
        viewModel.handleEvent(event)
    }

    func testServerHeartbeatDoesNotCrash() {
        let event = makeEvent(type: "server.heartbeat", properties: nil)
        viewModel.handleEvent(event)
    }

    func testServerConnectedDoesNotCrash() {
        let event = makeEvent(type: "server.connected", properties: nil)
        viewModel.handleEvent(event)
    }

    // MARK: - isSessionBusy

    func testIsSessionBusyWhenBusy() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.sessionStatuses = ["ses_1": SessionStatus(status: "busy")]
        XCTAssertTrue(viewModel.isSessionBusy)
    }

    func testIsSessionBusyWhenIdle() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.sessionStatuses = ["ses_1": SessionStatus(status: "idle")]
        XCTAssertFalse(viewModel.isSessionBusy)
    }

    func testIsSessionBusyWhenNoStatus() {
        viewModel.selectedSessionId = "ses_1"
        XCTAssertFalse(viewModel.isSessionBusy)
    }

    func testIsSessionBusyWhenNoSelectedSession() {
        viewModel.sessionStatuses = ["ses_1": SessionStatus(status: "busy")]
        XCTAssertFalse(viewModel.isSessionBusy)
    }

    func testDraftRestoresPerSessionIncludingAttachments() {
        let firstSession = "ses_draft_\(UUID().uuidString)"
        let secondSession = "ses_draft_\(UUID().uuidString)"
        viewModel.selectedSessionId = firstSession
        viewModel.inputText = "draft one"
        viewModel.attachedParts = [MessagePartBody(type: "file", mime: "image/png", url: "data:image/png;base64,abc", filename: "one.png")]

        viewModel.selectedSessionId = secondSession
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertEqual(viewModel.attachedParts, [])

        viewModel.inputText = "draft two"
        viewModel.selectedSessionId = firstSession

        XCTAssertEqual(viewModel.inputText, "draft one")
        XCTAssertEqual(viewModel.attachedParts.first?.filename, "one.png")
    }

    func testPermissionAndQuestionStateDoesNotLeakBetweenSessions() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(makeEvent(type: "permission.asked", properties: [
            "id": .string("perm_1"),
            "sessionID": .string("ses_1"),
            "type": .string("edit"),
            "messageID": .string("msg_1"),
            "title": .string("Edit")
        ]))
        viewModel.handleEvent(makeEvent(type: "question.asked", properties: [
            "id": .string("que_2"),
            "sessionID": .string("ses_2"),
            "messageID": .string("msg_2"),
            "title": .string("Question")
        ]))

        XCTAssertEqual(viewModel.selectedPendingPermissions.count, 1)
        XCTAssertTrue(viewModel.selectedPendingQuestions.isEmpty)

        viewModel.selectedSessionId = "ses_2"

        XCTAssertTrue(viewModel.selectedPendingPermissions.isEmpty)
        XCTAssertEqual(viewModel.selectedPendingQuestions.count, 1)
    }

    func testQuestionAskedAddsPendingQuestion() {
        viewModel.handleEvent(questionAskedEvent(id: "que_1", sessionID: "ses_1"))

        XCTAssertEqual(viewModel.pendingQuestions.count, 1)
        XCTAssertEqual(viewModel.pendingQuestions.first?.id, "que_1")
        XCTAssertEqual(viewModel.pendingQuestions.first?.sessionID, "ses_1")
        XCTAssertEqual(viewModel.pendingQuestions.first?.title, "Confirm")
        XCTAssertEqual(viewModel.pendingQuestions.first?.description, "Proceed?")
    }

    func testQuestionRepliedRemovesPendingQuestionForMatchingSession() {
        viewModel.handleEvent(questionAskedEvent(id: "que_1", sessionID: "ses_1"))
        viewModel.handleEvent(makeEvent(type: "question.replied", properties: [
            "requestID": .string("que_1"),
            "sessionID": .string("ses_1")
        ]))

        XCTAssertTrue(viewModel.pendingQuestions.isEmpty)
    }

    func testQuestionRejectedRemovesPendingQuestionForMatchingSession() {
        viewModel.handleEvent(questionAskedEvent(id: "que_1", sessionID: "ses_1"))
        viewModel.handleEvent(makeEvent(type: "question.rejected", properties: [
            "requestID": .string("que_1"),
            "sessionID": .string("ses_1")
        ]))

        XCTAssertTrue(viewModel.pendingQuestions.isEmpty)
    }

    func testQuestionResolutionForOneSessionDoesNotRemoveQuestionInAnotherSession() {
        viewModel.handleEvent(questionAskedEvent(id: "shared_request", sessionID: "ses_1"))
        viewModel.handleEvent(questionAskedEvent(id: "shared_request", sessionID: "ses_2"))
        viewModel.handleEvent(questionAskedEvent(id: "other_request", sessionID: "ses_2"))

        viewModel.handleEvent(makeEvent(type: "question.replied", properties: [
            "requestID": .string("shared_request"),
            "sessionID": .string("ses_1")
        ]))

        XCTAssertEqual(viewModel.pendingQuestions.map(\.id).sorted(), ["other_request", "shared_request"])
        XCTAssertFalse(viewModel.pendingQuestions.contains { $0.id == "shared_request" && $0.sessionID == "ses_1" })
        XCTAssertTrue(viewModel.pendingQuestions.contains { $0.id == "shared_request" && $0.sessionID == "ses_2" })
    }

    func testBufferedDeltaAppliesAfterMessageArrives() {
        viewModel.selectedSessionId = "ses_1"
        let event = makeEvent(type: "message.part.delta", properties: [
            "sessionID": .string("ses_1"),
            "messageID": .string("msg_1"),
            "partID": .string("part_1"),
            "delta": .string(" world")
        ])

        viewModel.handleEvent(event)
        viewModel.messages = [makeMessageEnvelope(id: "msg_1", partID: "part_1", text: "hello")]
        viewModel.applyBufferedDeltas(for: "ses_1")

        XCTAssertEqual(viewModel.messages.first?.parts.first?.text, "hello world")
    }

    // MARK: - /new and /clear Command Interception

    func testNewCommandCreatesSessionClientSide() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)

        let newSessionID = "ses_new_\(UUID().uuidString)"
        let createdSessionJSON = """
        {"id":"\(newSessionID)","slug":"test-session","version":"1.14.29","projectID":"global","directory":"/","path":"","title":"Test","time":{"created":1,"updated":1}}
        """

        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session")
            XCTAssertEqual(request.httpMethod, "POST")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(createdSessionJSON.utf8))
        }

        viewModel.selectedDirectory = "/"
        viewModel.selectedSessionId = "ses_old"

        let mockClient: OpenCodeClient? = client
        viewModel.configure(with: mockClient)

        await viewModel.handleNewSessionCommand()

        XCTAssertEqual(viewModel.selectedSessionId, newSessionID)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.sessions.first?.id, newSessionID)
    }

    func testClearCommandAliasCreatesSession() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)

        let newSessionID = "ses_clear_\(UUID().uuidString)"
        let createdSessionJSON = """
        {"id":"\(newSessionID)","slug":"test-session","version":"1.14.29","projectID":"global","directory":"/","path":"","title":"Test","time":{"created":1,"updated":1}}
        """

        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(createdSessionJSON.utf8))
        }

        viewModel.selectedDirectory = "/"
        viewModel.selectedSessionId = "ses_old"

        let mockClient: OpenCodeClient? = client
        viewModel.configure(with: mockClient)

        await viewModel.handleNewSessionCommand()

        XCTAssertEqual(viewModel.selectedSessionId, newSessionID)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testNewCommandShowsErrorWithoutDirectory() async {
        viewModel.selectedDirectory = nil
        await viewModel.handleNewSessionCommand()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSlashCommandInputDetectsNewAndClear() {
        XCTAssertTrue(viewModel.isSlashCommandInput("/new"))
        XCTAssertTrue(viewModel.isSlashCommandInput("/clear"))
        XCTAssertTrue(viewModel.isSlashCommandInput("  /new"))
        XCTAssertFalse(viewModel.isSlashCommandInput("hello /new"))
    }

    // MARK: - Bug Fix Regression Tests

    func testSendMessageGuardPreventsDoubleSend() async {
        viewModel.isSending = true
        viewModel.inputText = "hello"
        viewModel.selectedSessionId = "sess-1"
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        viewModel.configure(with: client)
        let before = viewModel.messages.count
        await viewModel.sendMessage()
        XCTAssertEqual(viewModel.messages.count, before)
    }

    func testSessionErrorRemovesOptimisticMessage() {
        viewModel.selectedSessionId = "sess-1"
        let optimisticId = "msg_ios_test123"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.messages = [makeOptimisticMessage(id: optimisticId, text: "hello")]
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello", created: now)
        viewModel.isSending = true

        let event = makeEvent(type: "session.error", properties: [
            "sessionID": .string("sess-1"),
            "error": .string("Something went wrong")
        ])
        viewModel.handleEvent(event)

        XCTAssertFalse(viewModel.isSending)
        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertFalse(viewModel.messages.contains(where: { $0.id == optimisticId }))
    }

    func testSessionErrorSetsErrorMessage() {
        viewModel.selectedSessionId = "sess-1"
        viewModel.isSending = true

        let event = makeEvent(type: "session.error", properties: [
            "sessionID": .string("sess-1"),
            "error": .string("Model failed")
        ])
        viewModel.handleEvent(event)

        XCTAssertEqual(viewModel.errorMessage, "Model failed")
    }

    func testSessionErrorDoesNotAffectOtherSessionOptimistic() {
        viewModel.selectedSessionId = "sess-1"
        let optimisticId = "msg_ios_other"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.messages = [makeOptimisticMessage(id: optimisticId, text: "hello")]
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-2", text: "hello", created: now)
        viewModel.isSending = true

        let event = makeEvent(type: "session.error", properties: [
            "sessionID": .string("sess-1"),
            "error": .string("Error")
        ])
        viewModel.handleEvent(event)

        XCTAssertNotNil(viewModel.pendingOptimisticMessages[optimisticId])
    }

    func testSessionErrorFallsBackToDefaultMessage() {
        viewModel.selectedSessionId = "sess-1"
        viewModel.isSending = true

        let event = makeEvent(type: "session.error", properties: [
            "sessionID": .string("sess-1")
        ])
        viewModel.handleEvent(event)

        XCTAssertEqual(viewModel.errorMessage, "Session error occurred")
    }

    func testReconciliationMatchesByExactText() {
        let optimisticId = "msg_ios_exact"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello", created: now)

        let serverMessage = makeUserMessage(id: "srv-1", text: "hello", createdMs: now)
        let result = viewModel.reconciledMessages(
            loaded: [serverMessage], existing: [makeOptimisticMessage(id: optimisticId, text: "hello")], sessionId: "sess-1")

        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertTrue(result.contains(where: { $0.id == "srv-1" }))
    }

    func testReconciliationMatchesByTimestampProximity() {
        let optimisticId = "msg_ios_ts"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello world", created: now)

        let serverMessage = makeUserMessage(id: "srv-2", text: "different text", createdMs: now + 30_000)
        let result = viewModel.reconciledMessages(
            loaded: [serverMessage], existing: [makeOptimisticMessage(id: optimisticId, text: "hello world")], sessionId: "sess-1")

        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertTrue(result.allSatisfy { $0.id != optimisticId })
    }

    func testReconciliationDoesNotMatchDistantTimestamps() {
        let optimisticId = "msg_ios_far"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello", created: now)

        let serverMessage = makeUserMessage(id: "srv-3", text: "different", createdMs: now + 120_000)
        let result = viewModel.reconciledMessages(
            loaded: [serverMessage], existing: [makeOptimisticMessage(id: optimisticId, text: "hello")], sessionId: "sess-1")

        XCTAssertNotNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertTrue(result.contains(where: { $0.id == optimisticId }))
    }

    func testReconciliationExpiresOldPendingEntries() {
        let optimisticId = "msg_ios_old"
        let fiveMinutesAgo = Int64(Date().timeIntervalSince1970 * 1000) - 301_000
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "old message", created: fiveMinutesAgo)

        _ = viewModel.reconciledMessages(
            loaded: [], existing: [makeOptimisticMessage(id: optimisticId, text: "old message")], sessionId: "sess-1")

        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
    }

    func testReconciledMessagesClearsExactServerIdMatch() {
        let optimisticId = "msg_ios_match"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello", created: now)

        let serverMessage = makeUserMessage(id: optimisticId, text: "hello", createdMs: now)
        _ = viewModel.reconciledMessages(loaded: [serverMessage], existing: [], sessionId: "sess-1")

        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
    }

    func testReconciledMessagesPreservesPendingNotOnServer() {
        let optimisticId = "msg_ios_pending"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "pending msg", created: now)

        let serverMessage = makeAssistantMessage(id: "srv-assist", createdMs: now)
        let result = viewModel.reconciledMessages(
            loaded: [serverMessage],
            existing: [makeOptimisticMessage(id: optimisticId, text: "pending msg")],
            sessionId: "sess-1")

        XCTAssertNotNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertTrue(result.contains(where: { $0.id == optimisticId }))
    }

    func testSessionSwitchCleansUpStaleOptimisticMessages() {
        let optimisticId = "msg_ios_stale"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.selectedSessionId = "sess-1"
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: "sess-1", text: "hello", created: now)

        viewModel.selectedSessionId = "sess-2"

        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
    }

    func testFilteredSessionsWithSearchText() {
        let s1 = try! decodeSession(id: "1", title: "Bug fix", directory: "/a", updated: 1)
        let s2 = try! decodeSession(id: "2", title: "Feature add", directory: "/b", updated: 2)
        viewModel.sessions = [s1, s2]
        viewModel.sessionSearchText = "Bug"
        XCTAssertEqual(viewModel.filteredSessions.count, 1)
        XCTAssertEqual(viewModel.filteredSessions[0].id, "1")
    }

    func testFilteredSessionsEmptySearchReturnsAll() {
        let s1 = try! decodeSession(id: "1", title: "Bug fix", directory: "/a", updated: 1)
        viewModel.sessions = [s1]
        viewModel.sessionSearchText = ""
        XCTAssertEqual(viewModel.filteredSessions.count, 1)
    }

    func testAvailableDirectories() {
        let s1 = try! decodeSession(id: "1", title: "A", directory: "/project-a", updated: 1)
        let s2 = try! decodeSession(id: "2", title: "B", directory: "/project-b", updated: 2)
        let s3 = try! decodeSession(id: "3", title: "C", directory: "/project-a", updated: 3)
        viewModel.sessions = [s1, s2, s3]
        let dirs = viewModel.availableDirectories
        XCTAssertEqual(Set(dirs.map(\.path)), ["/project-a", "/project-b"])
    }

    func testHasQuestionForSelectedSession() {
        viewModel.selectedSessionId = "sess-1"
        let question = makeQuestionFromJSON(id: "q-1", sessionID: "sess-1")
        viewModel.mergeQuestions([question])
        XCTAssertTrue(viewModel.hasQuestion)
    }

    func testHasQuestionFalseForOtherSession() {
        viewModel.selectedSessionId = "sess-2"
        let question = makeQuestionFromJSON(id: "q-1", sessionID: "sess-1")
        viewModel.mergeQuestions([question])
        XCTAssertFalse(viewModel.hasQuestion)
    }

    func testSelectedPendingPermissionsFiltersBySession() {
        viewModel.selectedSessionId = "sess-1"
        let perm = makePermissionFromJSON(id: "p-1", sessionID: "sess-1")
        viewModel.mergePermissions([perm])
        XCTAssertEqual(viewModel.selectedPendingPermissions.count, 1)

        viewModel.selectedSessionId = "sess-2"
        XCTAssertTrue(viewModel.selectedPendingPermissions.isEmpty)
    }

    // MARK: - Helpers

    private func makeEvent(type: String, properties: [String: JSONValue]?) -> SSEEvent {
        let json: [String: Any] = {
            var dict: [String: Any] = ["type": type]
            if let properties {
                dict["properties"] = properties.mapValues { value in
                    encodeJSONValue(value)
                }
            }
            return dict
        }()
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(SSEEvent.self, from: data)
    }

    private func questionAskedEvent(id: String, sessionID: String) -> SSEEvent {
        makeEvent(type: "question.asked", properties: [
            "id": .string(id),
            "sessionID": .string(sessionID),
            "messageID": .string("msg_\(id)"),
            "questions": .array([
                .object([
                    "header": .string("Confirm"),
                    "question": .string("Proceed?"),
                    "options": .array([]),
                    "multiple": .bool(false),
                    "custom": .bool(true)
                ])
            ])
        ])
    }

    private func encodeJSONValue(_ value: JSONValue) -> Any {
        let encoded = try! JSONEncoder().encode(value)
        return try! JSONSerialization.jsonObject(with: encoded, options: .fragmentsAllowed)
    }

    private func makeMessageEnvelope(id: String) -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "role": "user", "time": {"created": 0}},
            "parts": [{"type": "text", "text": "hello"}]
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(MessageEnvelope.self, from: data)
    }

    private func makeMessageEnvelope(id: String, partID: String, text: String) -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "sessionID": "ses_1", "role": "assistant", "time": {"created": 0}},
            "parts": [{"id": "\(partID)", "messageID": "\(id)", "sessionID": "ses_1", "type": "text", "text": "\(text)"}]
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(MessageEnvelope.self, from: data)
    }

    private func decodeSession(id: String, title: String, directory: String, updated: Int64) throws -> Session {
        let json = """
        {"id":"\(id)","slug":"\(id)","version":"1.0.0","projectID":"project","directory":"\(directory)","title":"\(title)","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":\(updated)}}
        """
        return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
    }

    private func decodeProject(worktree: String) throws -> Project {
        let json = """
        {"id":"project","worktree":"\(worktree)","time":{"created":1,"updated":1}}
        """
        return try JSONDecoder().decode(Project.self, from: Data(json.utf8))
    }

    private func makeOptimisticMessage(id: String, text: String) -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "role": "user", "isUser": true, "time": {"created": \(Int64(Date().timeIntervalSince1970 * 1000))}},
            "parts": [{"id": "part-\(id)", "type": "text", "text": "\(text)"}]
        }
        """
        return try! JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
    }

    private func makeUserMessage(id: String, text: String, createdMs: Int64) -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "role": "user", "isUser": true, "time": {"created": \(createdMs)}},
            "parts": [{"id": "part-\(id)", "type": "text", "text": "\(text)"}]
        }
        """
        return try! JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
    }

    private func makeAssistantMessage(id: String, createdMs: Int64) -> MessageEnvelope {
        let json = """
        {
            "info": {"id": "\(id)", "role": "assistant", "isAssistant": true, "time": {"created": \(createdMs)}},
            "parts": [{"id": "part-\(id)", "type": "text", "text": "response"}]
        }
        """
        return try! JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
    }

    private func makePermissionFromJSON(id: String, sessionID: String) -> Permission {
        let json = """
        {"id":"\(id)","sessionID":"\(sessionID)","messageID":"msg-\(id)","type":"confirm","title":"Permission","time":{"created":1}}
        """
        return try! JSONDecoder().decode(Permission.self, from: Data(json.utf8))
    }

    private func makeQuestionFromJSON(id: String, sessionID: String) -> Question {
        let json = """
        {"id":"\(id)","sessionID":"\(sessionID)","messageID":"msg-\(id)","title":"Confirm","description":"Proceed?","questions":[{"header":"Confirm","question":"Proceed?","options":[],"multiple":false,"custom":true}]}
        """
        return try! JSONDecoder().decode(Question.self, from: Data(json.utf8))
    }
}

private func chatViewModelTestRequestBody(from request: URLRequest) throws -> Data {
    if let httpBody = request.httpBody { return httpBody }
    if let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data = Data()
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
    return Data()
}
