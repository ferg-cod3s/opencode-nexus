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

    func testHandleSyncSessionStatusIdleReloadsMessagesAndSessions() async throws {
        let session = try decodeSession(id: "ses_sync_idle", title: "Sync Idle", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.projects = [try decodeProject(worktree: "/project")]
        viewModel.selectedSessionId = session.id
        viewModel.isSending = true

        let optimisticId = "msg_ios_sync_idle"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        viewModel.messages = [makeOptimisticMessage(id: optimisticId, text: "hello")]
        viewModel.pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId,
            sessionID: session.id,
            text: "hello",
            created: now
        )

        let messagesReloaded = expectation(description: "messages reloaded")
        let sessionsReloaded = expectation(description: "sessions reloaded")

        configureWithMockClient { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            switch components.path {
            case "/session/ses_sync_idle/message":
                messagesReloaded.fulfill()
                return testRespondJSON("""
                [{"info":{"id":"srv_user","sessionID":"ses_sync_idle","role":"user","isUser":true,"time":{"created":\(now)}},"parts":[{"id":"part_srv_user","messageID":"srv_user","sessionID":"ses_sync_idle","type":"text","text":"hello"}]},{"info":{"id":"srv_assistant","sessionID":"ses_sync_idle","role":"assistant","time":{"created":\(now + 1),"completed":\(now + 2)}},"parts":[{"id":"part_srv_assistant","messageID":"srv_assistant","sessionID":"ses_sync_idle","type":"text","text":"Done"}]}]
                """)
            case "/session":
                sessionsReloaded.fulfill()
                return testRespondJSON("""
                [{"id":"ses_sync_idle","slug":"sync-idle","version":"1.0.0","projectID":"project","directory":"/project","title":"Sync Idle","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":2}}]
                """)
            default:
                XCTFail("Unexpected path: \(components.path)")
                return testRespondJSON("[]", statusCode: 404)
            }
        }

        let eventData = Data(
            """
            {"payload":{"type":"session.status.1","id":"evt_sync_idle","aggregateID":"ses_sync_idle","data":{"status":{"type":"idle"}}}}
            """.utf8)
        let event = try JSONDecoder().decode(SSEEvent.self, from: eventData)

        viewModel.handleEvent(event)

        await fulfillment(of: [messagesReloaded, sessionsReloaded], timeout: 1.0)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.sessionStatuses[session.id]?.status, "idle")
        XCTAssertFalse(viewModel.isSending)
        XCTAssertNil(viewModel.pendingOptimisticMessages[optimisticId])
        XCTAssertEqual(viewModel.messages.map(\.id), ["srv_user", "srv_assistant"])
        XCTAssertEqual(viewModel.sessions.map(\.id), [session.id])
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

    func testLoadSessionsSeparatesArchivedSessionsAndCachesDirectoryLookup() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
        let sessionJSON = """
        [
          {"id":"ses_active","slug":"active","version":"1.0.0","projectID":"project","directory":"/project","title":"Active","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":3}},
          {"id":"ses_archived","slug":"archived","version":"1.0.0","projectID":"project","directory":"/project","title":"Archived","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":2,"archived":4}}
        ]
        """

        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if components.path == "/session" {
                let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                XCTAssertEqual(query["directory"], "/project")
                XCTAssertEqual(query["roots"], "true")
                XCTAssertEqual(query["limit"], "50")
                XCTAssertEqual(query["archived"], "true")
                return testRespondJSON(sessionJSON)
            }
            XCTFail("Unexpected path: \(components.path)")
            return testRespondJSON("[]", statusCode: 404)
        }

        viewModel.configure(with: client)
        viewModel.projects = [try decodeProject(worktree: "/project")]

        await viewModel.loadSessions()

        XCTAssertEqual(viewModel.sessions.map(\.id), ["ses_active"])
        XCTAssertEqual(viewModel.archivedSessions.map(\.id), ["ses_archived"])
        XCTAssertEqual(viewModel.directory(for: "ses_archived"), "/project")
    }

    func testLoadSessionsMovesArchivedSelectionOutOfActiveList() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
        let sessionJSON = """
        [{"id":"ses_target","slug":"target","version":"1.0.0","projectID":"project","directory":"/project","title":"Target","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":3,"archived":5}}]
        """

        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            if components.path == "/session" {
                return testRespondJSON(sessionJSON)
            }
            XCTFail("Unexpected path: \(components.path)")
            return testRespondJSON("[]", statusCode: 404)
        }

        viewModel.configure(with: client)
        viewModel.projects = [try decodeProject(worktree: "/project")]
        viewModel.sessions = [try decodeSession(id: "ses_target", title: "Target", directory: "/project", updated: 1)]
        viewModel.selectedSessionId = "ses_target"
        viewModel.messages = [makeMessageEnvelope(id: "msg_1")]
        viewModel.todos = [Todo(id: "todo_1", content: "Todo", status: "pending", priority: "high")]
        viewModel.fileDiffs = [FileDiff(file: "file.swift", before: "a", after: "b", additions: 1, deletions: 0)]

        await viewModel.loadSessions()

        XCTAssertNil(viewModel.selectedSessionId)
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertEqual(viewModel.archivedSessions.map(\.id), ["ses_target"])
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.todos.isEmpty)
        XCTAssertTrue(viewModel.fileDiffs.isEmpty)
    }

    func testArchiveSessionMovesSessionToArchivedAndClearsSelectionState() async throws {
        let session = try decodeSession(id: "ses_archive", title: "Archive Me", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = session.id
        viewModel.messages = [makeMessageEnvelope(id: "msg_1")]
        viewModel.todos = [Todo(id: "todo_1", content: "Todo", status: "pending", priority: "high")]
        viewModel.fileDiffs = [FileDiff(file: "file.swift", before: "a", after: "b", additions: 1, deletions: 0)]

        configureWithMockClient { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            switch (request.httpMethod, components.path) {
            case ("POST", "/session/ses_archive/archive"):
                let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                XCTAssertEqual(query["directory"], "/project")
                return testRespondJSON("{}", statusCode: 204)
            case ("GET", "/session/ses_archive"):
                return testRespondJSON("""
                {"id":"ses_archive","slug":"ses_archive","version":"1.0.0","projectID":"project","directory":"/project","title":"Archive Me","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":2,"archived":3}}
                """)
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(components.path)")
                return testRespondJSON("{}", statusCode: 404)
            }
        }

        await viewModel.archiveSession(session.id)

        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertEqual(viewModel.archivedSessions.map(\.id), ["ses_archive"])
        XCTAssertNil(viewModel.selectedSessionId)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.todos.isEmpty)
        XCTAssertTrue(viewModel.fileDiffs.isEmpty)
        XCTAssertEqual(viewModel.directory(for: session.id), "/project")
    }

    func testUnarchiveSessionRestoresSessionAbsentFromActiveList() async throws {
        let archivedJSON = """
        {"id":"ses_restore","slug":"ses_restore","version":"1.0.0","projectID":"project","directory":"/project","title":"Restore Me","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":2,"archived":3}}
        """
        let archivedSession = try JSONDecoder().decode(Session.self, from: Data(archivedJSON.utf8))
        viewModel.archivedSessions = [archivedSession]

        configureWithMockClient { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            switch (request.httpMethod, components.path) {
            case ("POST", "/session/ses_restore/unarchive"):
                let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                XCTAssertEqual(query["directory"], "/project")
                return testRespondJSON("{}", statusCode: 204)
            case ("GET", "/session/ses_restore"):
                return testRespondJSON("""
                {"id":"ses_restore","slug":"ses_restore","version":"1.0.0","projectID":"project","directory":"/project","title":"Restore Me","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":4}}
                """)
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(components.path)")
                return testRespondJSON("{}", statusCode: 404)
            }
        }

        await viewModel.unarchiveSession("ses_restore")

        XCTAssertEqual(viewModel.sessions.map(\.id), ["ses_restore"])
        XCTAssertTrue(viewModel.archivedSessions.isEmpty)
        XCTAssertEqual(viewModel.directory(for: "ses_restore"), "/project")
    }

    func testArchiveSessionFailureLeavesCollectionsUnchanged() async throws {
        let session = try decodeSession(id: "ses_fail", title: "Keep Me", directory: "/project", updated: 1)
        viewModel.sessions = [session]

        configureWithMockClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("archive failed".utf8))
        }

        await viewModel.archiveSession(session.id)

        XCTAssertEqual(viewModel.sessions.map(\.id), ["ses_fail"])
        XCTAssertTrue(viewModel.archivedSessions.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
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
            var payload: [String: Any] = ["type": type]
            if let properties {
                payload["properties"] = properties.mapValues { value in
                    encodeJSONValue(value)
                }
            }
            return ["payload": payload]
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

    private func makeMockClient(handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> OpenCodeClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.setRequestHandler(handler)
        return OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
    }

    private func configureWithMockClient(_ handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
        let client = makeMockClient(handler: handler)
        viewModel.configure(with: client)
    }

    // MARK: - loadProviders()

    func testLoadProvidersSetsAvailableProvidersAndDefaults() async {
        configureWithMockClient { request in
            if request.url?.path == "/config/providers" {
                return testRespondJSON("""
                {"providers":[{"id":"openai","name":"OpenAI","models":{"gpt-4o":{"id":"gpt-4o","name":"GPT-4o"}}}],"default":{"openai":"gpt-4o"}}
                """)
            }
            if request.url?.path == "/agent" {
                return testRespondJSON("[]")
            }
            if request.url?.path == "/vcs" {
                return testRespondJSON("{}")
            }
            if request.url?.path == "/config/command" {
                return testRespondJSON("[]")
            }
            return testRespondJSON("[]")
        }
        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.availableProviders.count, 1)
        XCTAssertEqual(viewModel.availableProviders.first?.id, "openai")
        XCTAssertEqual(viewModel.providerDefaults["openai"], "gpt-4o")
    }

    func testLoadProvidersSetsAutoSelectedModel() async {
        viewModel.selectedModel = nil
        configureWithMockClient { _ in
            testRespondJSON("""
            {"providers":[],"default":{"anthropic":"claude-3","openai":"gpt-4o"}}
            """)
        }
        await viewModel.loadServerInfo()
        XCTAssertNotNil(viewModel.selectedModel)
        XCTAssertEqual(viewModel.selectedModel?.providerID, "anthropic")
        XCTAssertEqual(viewModel.selectedModel?.modelID, "claude-3")
    }

    func testLoadProvidersPopulatesAvailableModels() async {
        configureWithMockClient { _ in
            testRespondJSON("""
            {"providers":[{"id":"openai","name":"OpenAI","models":{"gpt-4o":{"id":"gpt-4o","name":"GPT-4o"},"old-model":{"id":"old","name":"Old","status":"deprecated"}}}],"default":{}}
            """)
        }
        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.availableModels.count, 1)
        XCTAssertEqual(viewModel.availableModels.first?.modelID, "gpt-4o")
    }

    func testLoadProvidersNoOpWithoutClient() async {
        viewModel.configure(with: nil)
        await viewModel.loadServerInfo()
        XCTAssertTrue(viewModel.availableProviders.isEmpty)
    }

    // MARK: - loadAgents()

    func testLoadAgentsFiltersBuiltInAndSelectsPrimary() async {
        configureWithMockClient { request in
            if request.url?.path == "/agent" {
                return testRespondJSON("""
                [{"name":"build","description":"Build agent","mode":"primary","builtIn":true},{"name":"coder","description":"Coder","mode":"primary","builtIn":false},{"name":"reviewer","description":"Reviewer","mode":"secondary","builtIn":false},{"name":"helper","description":"Helper","mode":"all","builtIn":false}]
                """)
            }
            return testRespondJSON("{\"providers\":[],\"default\":{}}")
        }
        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.availableAgents.count, 2)
        let names = Set(viewModel.availableAgents.map(\.name))
        XCTAssertTrue(names.contains("coder"))
        XCTAssertTrue(names.contains("helper"))
    }

    // MARK: - loadVcs()

    func testLoadVcsSetsBranch() async {
        configureWithMockClient { request in
            if request.url?.path == "/vcs" {
                return testRespondJSON("{\"branch\":\"feature/test\"}")
            }
            return testRespondJSON("{\"providers\":[],\"default\":{}}")
        }
        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.vcsBranch, "feature/test")
    }

    func testLoadVcsHandlesNilBranch() async {
        configureWithMockClient { request in
            if request.url?.path == "/vcs" {
                return testRespondJSON("{}")
            }
            return testRespondJSON("{\"providers\":[],\"default\":{}}")
        }
        await viewModel.loadServerInfo()
        XCTAssertNil(viewModel.vcsBranch)
    }

    // MARK: - loadCommands()

    func testLoadCommandsSetsAvailableCommands() async {
        configureWithMockClient { request in
            if request.url?.path == "/command" {
                return testRespondJSON("""
                [{"name":"commit","description":"Create a commit"},{"name":"plan","description":"Plan changes"}]
                """)
            }
            return testRespondJSON("{\"providers\":[],\"default\":{}}")
        }
        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.availableCommands.count, 2)
        XCTAssertEqual(viewModel.availableCommands.first?.name, "commit")
    }

    // MARK: - loadMoreSessions()

    func testLoadMoreSessionsIncreasesPageLimit() async {
        let sessionJSON = """
        [{"id":"ses_\(UUID().uuidString)","slug":"s","version":"1.0.0","projectID":"p","directory":"/project","title":"S","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}]
        """
        configureWithMockClient { request in
            if request.url?.path == "/session" {
                return testRespondJSON(sessionJSON)
            }
            if request.url?.path == "/project/current" {
                return testRespondJSON("{\"id\":\"p\",\"worktree\":\"/project\",\"time\":{\"created\":1}}")
            }
            if request.url?.path == "/project" {
                return testRespondJSON("[{\"id\":\"p\",\"worktree\":\"/project\",\"time\":{\"created\":1}}]")
            }
            return testRespondJSON("[]")
        }

        viewModel.hasMoreSessions = true
        await viewModel.loadMoreSessions()
        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testLoadMoreSessionsNoOpWhenNoMore() async {
        viewModel.hasMoreSessions = false
        await viewModel.loadMoreSessions()
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }

    // MARK: - selectSession(_:)

    func testSelectSessionLoadsMessagesAndSetsId() async throws {
        let msgJSON = """
        [{"info":{"id":"msg_1","role":"user","time":{"created":1}},"parts":[{"type":"text","text":"hello"}]}]
        """
        configureWithMockClient { request in
            if request.url?.path == "/session/ses_target/message" {
                return testRespondJSON(msgJSON)
            }
            if request.url?.path == "/session/ses_target/todo" {
                return testRespondJSON("[]")
            }
            if request.url?.path == "/session/ses_target/diff" {
                return testRespondJSON("[]")
            }
            if request.url?.path == "/permission" {
                return testRespondJSON("[]")
            }
            if request.url?.path == "/question" {
                return testRespondJSON("[]")
            }
            if request.url?.path == "/tui/control/next" {
                throw NSError(domain: "test", code: -1)
            }
            return testRespondJSON("[]")
        }

        let session = try decodeSession(id: "ses_target", title: "Target", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedDirectory = "/project"

        await viewModel.selectSession("ses_target")

        XCTAssertEqual(viewModel.selectedSessionId, "ses_target")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.id, "msg_1")
    }

    // MARK: - createSession()

    func testCreateSessionSuccess() async throws {
        let newID = "ses_created_\(UUID().uuidString)"
        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/session")
            return testRespondJSON("""
            {"id":"\(newID)","slug":"new","version":"1.0.0","projectID":"global","directory":"/project","title":"My Chat","time":{"created":1,"updated":1}}
            """)
        }
        viewModel.selectedDirectory = "/project"
        viewModel.newSessionTitle = "My Chat"

        await viewModel.createSession()

        XCTAssertEqual(viewModel.selectedSessionId, newID)
        XCTAssertEqual(viewModel.sessions.first?.id, newID)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.newSessionTitle, "")
    }

    func testCreateSessionRequiresTitle() async {
        viewModel.selectedDirectory = "/project"
        viewModel.newSessionTitle = "   "
        await viewModel.createSession()
        XCTAssertNil(viewModel.selectedSessionId)
    }

    func testCreateSessionRequiresDirectory() async {
        configureWithMockClient { _ in testRespondJSON("[]") }
        viewModel.newSessionTitle = "Test"
        viewModel.selectedDirectory = nil
        await viewModel.createSession()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCreateSessionHandlesError() async {
        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }
        viewModel.selectedDirectory = "/project"
        viewModel.newSessionTitle = "Test"
        await viewModel.createSession()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - renameSession(_:title:)

    func testRenameSessionUpdatesSessionInList() async throws {
        let session = try decodeSession(id: "ses_rename", title: "Old Title", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedDirectory = "/project"

        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/session/ses_rename")
            return testRespondJSON("""
            {"id":"ses_rename","slug":"s","version":"1.0.0","projectID":"p","directory":"/project","title":"New Title","time":{"created":1,"updated":2}}
            """)
        }

        await viewModel.renameSession("ses_rename", title: "New Title")
        XCTAssertEqual(viewModel.sessions.first?.title, "New Title")
    }

    func testRenameSessionHandlesError() async throws {
        let session = try decodeSession(id: "ses_err", title: "Keep", directory: "/project", updated: 1)
        viewModel.sessions = [session]

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.renameSession("ses_err", title: "Broken")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.sessions.first?.title, "Keep")
    }

    // MARK: - deleteSession(_:)

    func testDeleteSessionRemovesFromList() async throws {
        let s1 = try decodeSession(id: "ses_del", title: "Delete Me", directory: "/project", updated: 1)
        let s2 = try decodeSession(id: "ses_keep", title: "Keep", directory: "/project", updated: 2)
        viewModel.sessions = [s1, s2]
        viewModel.selectedSessionId = "ses_del"

        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/session/ses_del")
            return testRespondJSON("true")
        }

        await viewModel.deleteSession("ses_del")
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions.first?.id, "ses_keep")
        XCTAssertNil(viewModel.selectedSessionId)
    }

    func testDeleteSessionDoesNotRemoveOnFailure() async throws {
        let s1 = try decodeSession(id: "ses_fail", title: "Fail", directory: "/project", updated: 1)
        viewModel.sessions = [s1]

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.deleteSession("ses_fail")
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - forkSession(at:)

    func testForkSessionCreatesForkedSession() async throws {
        let parent = try decodeSession(id: "ses_parent", title: "Parent", directory: "/project", updated: 1)
        viewModel.sessions = [parent]
        viewModel.selectedSessionId = "ses_parent"

        let forkedID = "ses_forked_\(UUID().uuidString)"
        configureWithMockClient { request in
            XCTAssertEqual(request.url?.path, "/session/ses_parent/fork")
            XCTAssertEqual(request.httpMethod, "POST")
            return testRespondJSON("""
            {"id":"\(forkedID)","slug":"fork","version":"1.0.0","projectID":"p","directory":"/project","title":"Forked","time":{"created":2,"updated":2}}
            """)
        }

        await viewModel.forkSession(at: "msg_1")
        XCTAssertEqual(viewModel.selectedSessionId, forkedID)
        XCTAssertEqual(viewModel.sessions.first?.id, forkedID)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testForkSessionRequiresSelectedSession() async {
        viewModel.selectedSessionId = nil
        await viewModel.forkSession()
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }

    func testForkSessionHandlesError() async throws {
        let parent = try decodeSession(id: "ses_parent2", title: "P", directory: "/project", updated: 1)
        viewModel.sessions = [parent]
        viewModel.selectedSessionId = "ses_parent2"

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.forkSession()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - shareSession(_:)

    func testShareSessionUpdatesSessionWithShareURL() async throws {
        let session = try decodeSession(id: "ses_share", title: "Share Me", directory: "/project", updated: 1)
        viewModel.sessions = [session]

        configureWithMockClient { request in
            if request.httpMethod == "POST" && request.url?.path == "/session/ses_share/share" {
                return testRespondJSON("true")
            }
            if request.url?.path == "/session/ses_share" {
                return testRespondJSON("""
                {"id":"ses_share","slug":"s","version":"1.0.0","projectID":"p","directory":"/project","title":"Share Me","share":{"url":"https://share.example.com/abc"},"time":{"created":1,"updated":1}}
                """)
            }
            XCTFail("Unexpected request: \(request.url?.path ?? "nil")")
            return testRespondJSON("{}")
        }

        await viewModel.shareSession("ses_share")
        let shared = viewModel.sessions.first
        XCTAssertNotNil(shared?.share?.url)
        XCTAssertEqual(shared?.share?.url, "https://share.example.com/abc")
    }

    // MARK: - revertMessage(_:partID:)

    func testRevertMessageCallsRevertAndReloads() async throws {
        let session = try decodeSession(id: "ses_revert", title: "Revert", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_revert"

        nonisolated(unsafe) var revertCalled = false
        configureWithMockClient { request in
            if request.url?.path == "/session/ses_revert/revert" {
                revertCalled = true
                return testRespondJSON("true")
            }
            if request.url?.path == "/session/ses_revert/message" {
                return testRespondJSON("[]")
            }
            return testRespondJSON("[]")
        }

        await viewModel.revertMessage("msg_1", partID: "part_1")
        XCTAssertTrue(revertCalled)
    }

    func testRevertMessageHandlesError() async throws {
        let session = try decodeSession(id: "ses_revert2", title: "R", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_revert2"

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.revertMessage("msg_1")
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - loadMessages()

    func testLoadMessagesForSelectedSession() async throws {
        let session = try decodeSession(id: "ses_msgs", title: "Msgs", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_msgs"

        configureWithMockClient { request in
            XCTAssertEqual(request.url?.path, "/session/ses_msgs/message")
            return testRespondJSON("""
            [{"info":{"id":"msg_a","role":"user","time":{"created":1}},"parts":[{"type":"text","text":"hi"}]},{"info":{"id":"msg_b","role":"assistant","time":{"created":2}},"parts":[{"type":"text","text":"hello"}]}]
            """)
        }

        await viewModel.loadMessages()
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertFalse(viewModel.isLoadingMessages)
    }

    func testLoadMessagesSetsHasMoreWhenFullPage() async throws {
        let session = try decodeSession(id: "ses_full", title: "Full", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_full"

        let messages = (0..<50).map { i -> String in
            """
            {"info":{"id":"msg_\(i)","role":"user","time":{"created":\(i)}},"parts":[{"type":"text","text":"m\(i)"}]}
            """
        }.joined(separator: ",")
        configureWithMockClient { _ in testRespondJSON("[\(messages)]") }

        await viewModel.loadMessages()
        XCTAssertTrue(viewModel.hasMoreMessages)
    }

    func testLoadMessagesHandlesError() async throws {
        let session = try decodeSession(id: "ses_merr", title: "Err", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_merr"

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.loadMessages()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoadMessagesNoOpWithoutClientOrSession() async {
        viewModel.configure(with: nil)
        await viewModel.loadMessages()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - loadMoreMessages()

    func testLoadMoreMessagesAppendsOlderMessages() async throws {
        let session = try decodeSession(id: "ses_pag", title: "Pag", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_pag"
        viewModel.hasMoreMessages = true

        let existingMsg = makeMessageEnvelope(id: "msg_new")
        viewModel.messages = [existingMsg]

        let olderMessages = (0..<10).map { i -> String in
            """
            {"info":{"id":"msg_old_\(i)","role":"user","time":{"created":\(i)}},"parts":[{"type":"text","text":"old\(i)"}]}
            """
        }.joined(separator: ",")

        configureWithMockClient { _ in testRespondJSON("[\(olderMessages)]") }

        await viewModel.loadMoreMessages()
        XCTAssertEqual(viewModel.messages.count, 11)
        XCTAssertEqual(viewModel.messages.first?.id, "msg_old_0")
    }

    func testLoadMoreMessagesNoOpWhenNoMore() async {
        viewModel.hasMoreMessages = false
        await viewModel.loadMoreMessages()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - sendCommand(text:)

    func testSendCommandSendsSlashCommand() async throws {
        let session = try decodeSession(id: "ses_cmd", title: "Cmd", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_cmd"

        configureWithMockClient { request in
            if request.url?.path == "/session/ses_cmd/command" {
                return testRespondJSON("""
                {"info":{"id":"msg_cmd","role":"assistant","time":{"created":1}},"parts":[{"type":"text","text":"committed"}]}
                """)
            }
            return testRespondJSON("[]")
        }

        await viewModel.sendCommand(text: "/commit changes")
        XCTAssertFalse(viewModel.isSending)
    }

    func testSendCommandRequiresClientAndSession() async {
        let client = makeMockClient { _ in testRespondJSON("[]") }
        viewModel.configure(with: client)
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendCommand(text: "not a slash command")
    }

    func testSendCommandEmptyNameShowsError() async {
        let client = makeMockClient { _ in testRespondJSON("[]") }
        viewModel.configure(with: client)
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendCommand(text: "/")
        XCTAssertEqual(viewModel.errorMessage, "Enter a slash command name.")
    }

    // MARK: - loadPendingRequests

    func testLoadPendingRequestsMergesPermissionsAndQuestions() async {
        let session = try! decodeSession(id: "ses_pending", title: "P", directory: "/project", updated: 1)
        viewModel.sessions = [session]

        configureWithMockClient { request in
            if request.url?.path == "/permission" {
                return testRespondJSON("""
                [{"id":"perm_1","sessionID":"ses_pending","type":"edit","messageID":"msg_1","title":"Edit","time":{"created":1}}]
                """)
            }
            if request.url?.path == "/question" {
                return testRespondJSON("""
                [{"id":"que_1","sessionID":"ses_pending","messageID":"msg_1","title":"Q","questions":[{"header":"Q","question":"?","options":[],"multiple":false,"custom":true}]}]
                """)
            }
            return testRespondJSON("[]")
        }

        await viewModel.loadPendingRequests(for: "ses_pending")
        XCTAssertEqual(viewModel.pendingPermissions.count, 1)
        XCTAssertEqual(viewModel.pendingQuestions.count, 1)
    }

    // MARK: - loadTodos

    func testLoadTodosPopulatesTodos() async throws {
        let session = try decodeSession(id: "ses_todos", title: "T", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_todos"

        configureWithMockClient { request in
            XCTAssertEqual(request.url?.path, "/session/ses_todos/todo")
            return testRespondJSON("""
            [{"id":"todo_1","content":"Fix bug","status":"pending","priority":"high"},{"id":"todo_2","content":"Write tests","status":"completed","priority":"medium"}]
            """)
        }

        await viewModel.loadTodos()
        XCTAssertEqual(viewModel.todos.count, 2)
        XCTAssertEqual(viewModel.todos.first?.content, "Fix bug")
    }

    // MARK: - loadSessionDiffs

    func testLoadSessionDiffsPopulatesFileDiffs() async throws {
        let session = try decodeSession(id: "ses_diff", title: "D", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_diff"

        configureWithMockClient { request in
            XCTAssertEqual(request.url?.path, "/session/ses_diff/diff")
            return testRespondJSON("""
            [{"file":"main.swift","before":"","after":"code","additions":10,"deletions":2}]
            """)
        }

        await viewModel.loadSessionDiffs()
        XCTAssertEqual(viewModel.fileDiffs.count, 1)
        XCTAssertEqual(viewModel.fileDiffs.first?.file, "main.swift")
    }

    // MARK: - projectDirectories

    func testProjectDirectoriesIncludesSandboxes() async throws {
        _ = try decodeProject(worktree: "/main")
        let projectJSON = """
        [{"id":"p2","worktree":"/main","sandboxes":["/sandbox1","/sandbox2"],"time":{"created":1}}]
        """
        configureWithMockClient { request in
            if request.url?.path == "/project/current" {
                return testRespondJSON("{\"id\":\"p2\",\"worktree\":\"/main\",\"time\":{\"created\":1}}")
            }
            if request.url?.path == "/project" {
                return testRespondJSON(projectJSON)
            }
            return testRespondJSON("[]")
        }

        await viewModel.loadProjectInfo()
        let dirs = viewModel.projectDirectories
        let paths = Set(dirs.map(\.path))
        XCTAssertTrue(paths.contains("/main"))
        XCTAssertTrue(paths.contains("/sandbox1"))
        XCTAssertTrue(paths.contains("/sandbox2"))
    }

    // MARK: - sendShellCommand

    func testSendShellCommandSendsAndReloads() async throws {
        let session = try decodeSession(id: "ses_shell", title: "Shell", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_shell"

        configureWithMockClient { request in
            if request.url?.path == "/session/ses_shell/shell" {
                return testRespondJSON("""
                {"info":{"id":"msg_shell","role":"assistant","time":{"created":1}},"parts":[{"type":"text","text":"output"}]}
                """)
            }
            if request.url?.path == "/session/ses_shell/message" {
                return testRespondJSON("[]")
            }
            return testRespondJSON("[]")
        }

        await viewModel.sendShellCommand("ls -la")
        XCTAssertFalse(viewModel.isSending)
        XCTAssertTrue(viewModel.sentMessageHistory.contains("! ls -la"))
    }

    func testSendShellCommandHandlesError() async throws {
        let session = try decodeSession(id: "ses_shell2", title: "S", directory: "/project", updated: 1)
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_shell2"

        configureWithMockClient { _ in
            let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("error".utf8))
        }

        await viewModel.sendShellCommand("bad command")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSending)
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

private func testRespondError(_ statusCode: Int = 500) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    return (response, Data("error".utf8))
}
