import XCTest
@testable import OpenCodeNexus

@MainActor
final class ChatViewModelExtendedTests: XCTestCase {

    private var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
        viewModel.configure(with: nil)
    }

    override func tearDown() {
        viewModel = nil
        MockURLProtocol.setRequestHandler(nil)
        super.tearDown()
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

    private func decodeSession(id: String, title: String, directory: String, updated: Int64 = 1) throws -> Session {
        let json = """
        {"id":"\(id)","slug":"\(id)","version":"1.0.0","projectID":"project","directory":"\(directory)","title":"\(title)","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":\(updated)}}
        """
        return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
    }

    // MARK: - deleteSession

    func testDeleteSessionRemovesFromList() async throws {
        let s1 = try decodeSession(id: "ses_del", title: "Delete", directory: "/p")
        let s2 = try decodeSession(id: "ses_keep", title: "Keep", directory: "/p")
        viewModel.sessions = [s1, s2]
        viewModel.selectedSessionId = "ses_del"

        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            return testRespondJSON("true")
        }

        await viewModel.deleteSession("ses_del")
        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions.first?.id, "ses_keep")
    }

    // MARK: - deleteMessage

    func testDeleteMessageRemovesFromList() async throws {
        let session = try decodeSession(id: "ses_1", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_1"
        let msgJSON = """
        {"info":{"id":"msg_1","role":"user","time":{"created":1}},"parts":[{"type":"text","text":"hi"}]}
        """
        viewModel.messages = [try JSONDecoder().decode(MessageEnvelope.self, from: Data(msgJSON.utf8))]

        configureWithMockClient { _ in testRespondJSON("true") }

        await viewModel.deleteMessage("msg_1")
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    // MARK: - abortSession

    func testAbortSessionCallsAbort() async throws {
        let session = try decodeSession(id: "ses_abort", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_abort"
        viewModel.isSending = true

        configureWithMockClient { request in
            XCTAssertTrue(request.url?.path.contains("abort") == true)
            return testRespondJSON("{}")
        }

        await viewModel.abortSession()
    }

    // MARK: - approvePermission

    func testApprovePermissionRemovesFromPending() async throws {
        let permJSON = """
        {"id":"perm_1","sessionID":"ses_1","type":"edit","messageID":"msg_1","title":"Edit","time":{"created":1}}
        """
        let perm = try JSONDecoder().decode(Permission.self, from: Data(permJSON.utf8))
        viewModel.pendingPermissions = [perm]

        configureWithMockClient { _ in testRespondJSON("true") }

        await viewModel.approvePermission(perm)
        XCTAssertTrue(viewModel.pendingPermissions.isEmpty)
    }

    // MARK: - rejectPermission

    func testRejectPermissionRemovesFromPending() async throws {
        let permJSON = """
        {"id":"perm_2","sessionID":"ses_1","type":"edit","messageID":"msg_1","title":"Edit","time":{"created":1}}
        """
        let perm = try JSONDecoder().decode(Permission.self, from: Data(permJSON.utf8))
        viewModel.pendingPermissions = [perm]

        configureWithMockClient { _ in testRespondJSON("true") }

        await viewModel.rejectPermission(perm)
        XCTAssertTrue(viewModel.pendingPermissions.isEmpty)
    }

    // MARK: - answerQuestion

    func testAnswerQuestionRemovesQuestion() async throws {
        let qJSON = """
        {"id":"q_1","sessionID":"ses_1","messageID":"msg_1","title":"Q","questions":[{"header":"H","question":"?","options":[],"multiple":false,"custom":true}]}
        """
        let question = try JSONDecoder().decode(Question.self, from: Data(qJSON.utf8))
        viewModel.pendingQuestions = [question]

        configureWithMockClient { _ in testRespondJSON("true") }

        await viewModel.answerQuestion(question, answers: [["yes"]])
        XCTAssertTrue(viewModel.pendingQuestions.isEmpty)
    }

    // MARK: - rejectQuestion

    func testRejectQuestionRemovesQuestion() async throws {
        let qJSON = """
        {"id":"q_2","sessionID":"ses_1","messageID":"msg_1","title":"Q","questions":[{"header":"H","question":"?","options":[],"multiple":false,"custom":true}]}
        """
        let question = try JSONDecoder().decode(Question.self, from: Data(qJSON.utf8))
        viewModel.pendingQuestions = [question]

        configureWithMockClient { _ in testRespondJSON("true") }

        await viewModel.rejectQuestion(question)
        XCTAssertTrue(viewModel.pendingQuestions.isEmpty)
    }

    // MARK: - sendShellCommand

    func testSendShellCommandWithoutClient() async {
        viewModel.configure(with: nil)
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendShellCommand("ls -la")
    }

    func testSendShellCommandWithoutSession() async {
        configureWithMockClient { _ in testRespondJSON("{}") }
        viewModel.selectedSessionId = nil
        await viewModel.sendShellCommand("ls -la")
    }

    // MARK: - loadServerInfo concurrency

    func testLoadServerInfoLoadsAllConcurrently() async {
        configureWithMockClient { request in
            switch request.url?.path {
            case "/config/providers":
                return testRespondJSON("{\"providers\":[{\"id\":\"openai\",\"name\":\"OpenAI\"}],\"default\":{}}")
            case "/agent":
                return testRespondJSON("[{\"name\":\"coder\",\"description\":\"code\",\"builtIn\":false}]")
            case "/vcs":
                return testRespondJSON("{\"branch\":\"main\"}")
            case "/command":
                return testRespondJSON("[{\"name\":\"commit\",\"description\":\"commit changes\"}]")
            default:
                return testRespondJSON("[]")
            }
        }

        await viewModel.loadServerInfo()
        XCTAssertEqual(viewModel.availableProviders.count, 1)
        XCTAssertEqual(viewModel.vcsBranch, "main")
        XCTAssertFalse(viewModel.availableAgents.isEmpty)
        XCTAssertFalse(viewModel.availableCommands.isEmpty)
    }

    // MARK: - loadMessages

    func testLoadMessagesPopulatesMessages() async throws {
        let session = try decodeSession(id: "ses_msg", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_msg"

        configureWithMockClient { _ in
            testRespondJSON("""
            [{"info":{"id":"msg_1","role":"user","time":{"created":1}},"parts":[{"type":"text","text":"hello"}]}]
            """)
        }

        await viewModel.loadMessages()
        XCTAssertEqual(viewModel.messages.count, 1)
    }

    // MARK: - session grouping

    func testSessionGroupsByDirectory() throws {
        let s1 = try decodeSession(id: "s1", title: "A", directory: "/project1")
        let s2 = try decodeSession(id: "s2", title: "B", directory: "/project1")
        let s3 = try decodeSession(id: "s3", title: "C", directory: "/project2")
        viewModel.sessions = [s1, s2, s3]

        let groups = viewModel.sessionGroups
        XCTAssertEqual(groups.count, 2)
    }

    // MARK: - slash command detection

    func testIsSlashCommandInput() {
        XCTAssertTrue(viewModel.isSlashCommandInput("/help"))
        XCTAssertTrue(viewModel.isSlashCommandInput("/new session"))
        XCTAssertFalse(viewModel.isSlashCommandInput("hello"))
        XCTAssertFalse(viewModel.isSlashCommandInput(""))
    }

    // MARK: - selectSession

    func testSelectSessionLoadsMessages() async throws {
        let s1 = try decodeSession(id: "ses_sel", title: "Select", directory: "/p")
        viewModel.sessions = [s1]

        configureWithMockClient { _ in
            testRespondJSON("[]")
        }

        viewModel.selectedSessionId = "ses_sel"
        await viewModel.selectSession(s1.id)
        XCTAssertEqual(viewModel.selectedSessionId, "ses_sel")
    }

    // MARK: - filteredSessions

    func testFilteredSessionsWithSearch() throws {
        let s1 = try decodeSession(id: "s1", title: "Hello World", directory: "/p")
        let s2 = try decodeSession(id: "s2", title: "Goodbye", directory: "/p")
        viewModel.sessions = [s1, s2]
        viewModel.sessionSearchText = "hello"
        XCTAssertEqual(viewModel.filteredSessions.count, 1)
        XCTAssertEqual(viewModel.filteredSessions.first?.id, "s1")
    }

    func testFilteredSessionsEmptySearch() throws {
        let s1 = try decodeSession(id: "s1", title: "A", directory: "/p")
        viewModel.sessions = [s1]
        viewModel.sessionSearchText = ""
        XCTAssertEqual(viewModel.filteredSessions.count, 1)
    }

    // MARK: - sendMessage

    func testSendMessageWithEmptyInput() async {
        viewModel.inputText = ""
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendMessage()
    }

    func testSendMessageWithoutSession() async {
        viewModel.inputText = "hello"
        viewModel.selectedSessionId = nil
        await viewModel.sendMessage()
    }

    func testSendMessageWithoutClient() async {
        viewModel.configure(with: nil)
        viewModel.inputText = "hello"
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendMessage()
    }

    func testSendMessageMainPath() async {
        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return testRespondJSON("{}", statusCode: 204)
        }
        viewModel.inputText = "hello"
        viewModel.selectedSessionId = "ses_1"
        viewModel.selectedModel = ModelRefBody(providerID: "openai", modelID: "gpt-4")
        viewModel.selectedAgent = "build"
        await viewModel.sendMessage()
        XCTAssertTrue(viewModel.isSending)
    }

    func testSendMessageSlashCommandNew() async {
        configureWithMockClient { request in
            return testRespondJSON("{}", statusCode: 204)
        }
        viewModel.inputText = "/new"
        viewModel.selectedSessionId = "ses_1"
        await viewModel.sendMessage()
    }

    func testSendMessageSlashCommandWithAttachments() async {
        configureWithMockClient { _ in
            return testRespondJSON("{}", statusCode: 204)
        }
        viewModel.selectedSessionId = "ses_1"
        viewModel.inputText = "/commit"
        viewModel.attachedParts = [MessagePartBody(type: "file", text: "code", mime: nil, url: nil, filename: "test.swift")]
        await viewModel.sendMessage()
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - handleEvent

    func testHandleEventMessageCreated() {
        let event = makeEvent(
            type: "message.created",
            properties: [
                "sessionID": .string("ses_1"),
                "message": .object([
                    "info": .object(["id": .string("2"), "sessionID": .string("ses_1"), "role": .string("assistant"), "time": .object(["created": .int(1000)])]),
                    "parts": .array([.object(["type": .string("text"), "text": .string("Hi")])])
                ])
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.messages = []
        viewModel.isSending = true
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertFalse(viewModel.isSending)
    }

    func testHandleEventToolCalled() {
        let event = makeEvent(
            type: "tool.called",
            properties: [
                "messageID": .string("1"),
                "partID": .string("p1"),
                "tool": .string("bash"),
                "state": .object(["isPending": .bool(true)])
            ]
        )
        let msg = MessageEnvelope(
            info: MessageInfo(id: "1", sessionID: "ses_1", role: .assistant, time: MessageTimeInfo(created: 1000)),
            parts: [Part(sessionID: "ses_1", messageID: "1", type: "tool", text: "", tool: "bash")]
        )
        viewModel.messages = [msg]
        viewModel.handleEvent(event)
    }

    func testHandleEventTUIRequest() {
        let event = makeEvent(
            type: "tui.request",
            properties: [
                "path": .string("/test"),
                "body": .object(["text": .string("hello")])
            ]
        )
        viewModel.handleEvent(event)
        XCTAssertNotNil(viewModel.nextTUIRequest)
    }

    func testHandleEventSessionError() {
        let event = makeEvent(
            type: "session.error",
            properties: [
                "sessionID": .string("ses_1"),
                "error": .object(["message": .string("Error")])
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.errorMessage, "Error")
    }

    // MARK: - createSession

    func testCreateSessionSucceeds() async throws {
        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return testRespondJSON("""
            {"id":"ses_new","slug":"ses_new","version":"1.0.0","projectID":"project","directory":"/p","title":"New Session","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}
            """)
        }

        viewModel.newSessionTitle = "New Session"
        viewModel.selectedDirectory = "/p"
        await viewModel.createSession()
        XCTAssertTrue(viewModel.sessions.contains(where: { $0.title == "New Session" }))
    }

    // MARK: - forkSession

    func testForkSessionSucceeds() async throws {
        let session = try decodeSession(id: "ses_fork", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_fork"

        configureWithMockClient { request in
            XCTAssertTrue(request.url?.path.contains("fork") == true)
            return testRespondJSON("""
            {"id":"ses_forked","slug":"ses_forked","version":"1.0.0","projectID":"project","directory":"/p","title":"Forked","summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}
            """)
        }

        await viewModel.forkSession(at: nil)
        XCTAssertTrue(viewModel.sessions.contains(where: { $0.id == "ses_forked" }))
    }

    // MARK: - shareSession

    func testShareSessionSucceeds() async throws {
        let session = try decodeSession(id: "ses_share", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_share"

        configureWithMockClient { request in
            XCTAssertTrue(request.url?.path.contains("share") == true)
            return testRespondJSON("""
            {"id":"ses_share","slug":"ses_share","version":"1.0.0","projectID":"project","directory":"/p","title":"T","share":{"url":"https://share.link"},"summary":{"additions":0,"deletions":0,"files":0},"time":{"created":1,"updated":1}}
            """)
        }

        await viewModel.shareSession()
    }

    // MARK: - loadMoreMessages

    func testLoadMoreMessages() async throws {
        let session = try decodeSession(id: "ses_more", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_more"
        viewModel.hasMoreMessages = true

        configureWithMockClient { _ in
            testRespondJSON("[]")
        }

        await viewModel.loadMoreMessages()
    }

    // MARK: - loadMoreSessions

    func testLoadMoreSessions() async throws {
        viewModel.hasMoreSessions = true

        configureWithMockClient { _ in
            testRespondJSON("[]")
        }

        await viewModel.loadMoreSessions()
    }

    // MARK: - handleEvent

    func testHandleEventMessageDelta() {
        let event = makeEvent(
            type: "message.delta",
            properties: [
                "messageID": .string("msg_1"),
                "text": .string(" delta")
            ]
        )
        let msgJSON = """
        {"info":{"id":"msg_1","role":"assistant","time":{"created":1}},"parts":[{"type":"text","text":"hello"}]}
        """
        viewModel.messages = [try! JSONDecoder().decode(MessageEnvelope.self, from: Data(msgJSON.utf8))]
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
    }

    func testHandleEventMessageUpdated() {
        let event = makeEvent(
            type: "message.updated",
            properties: [
                "messageID": .string("msg_1"),
                "sessionID": .string("ses_1")
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.isSending = true
        viewModel.handleEvent(event)
    }

    func testHandleEventSessionUpdated() {
        let event = makeEvent(
            type: "session.updated",
            properties: [
                "sessionID": .string("ses_1"),
                "title": .string("Updated Title")
            ]
        )
        let session = try! decodeSession(id: "ses_1", title: "Old", directory: "/p")
        viewModel.sessions = [session]
        viewModel.handleEvent(event)
    }

    func testHandleEventSessionDeleted() {
        let event = makeEvent(
            type: "session.deleted",
            properties: [
                "sessionID": .string("ses_del")
            ]
        )
        let session = try! decodeSession(id: "ses_del", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.handleEvent(event)
    }

    func testHandleEventPermissionAsked() {
        let event = makeEvent(
            type: "permission.asked",
            properties: [
                "id": .string("perm_1"),
                "sessionID": .string("ses_1"),
                "type": .string("edit"),
                "messageID": .string("msg_1"),
                "title": .string("Edit"),
                "time": .object(["created": .int(1)])
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.pendingPermissions.count, 1)
    }

    func testHandleEventQuestionAsked() {
        let event = makeEvent(
            type: "question.asked",
            properties: [
                "id": .string("q_1"),
                "sessionID": .string("ses_1"),
                "messageID": .string("msg_1"),
                "title": .string("Q"),
                "questions": .array([
                    .object([
                        "header": .string("H"),
                        "question": .string("?"),
                        "options": .array([]),
                        "multiple": .bool(false),
                        "custom": .bool(true)
                    ])
                ])
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.pendingQuestions.count, 1)
    }

    func testHandleEventUnknownType() {
        let event = makeEvent(
            type: "unknown.event",
            properties: [:]
        )
        viewModel.handleEvent(event)
    }

    // MARK: - drafts

    func testSaveAndRestoreDraft() {
        viewModel.selectedSessionId = "ses_1"
        viewModel.inputText = "draft text"
        viewModel.selectedSessionId = "ses_2"
        viewModel.inputText = ""
        viewModel.selectedSessionId = "ses_1"
        XCTAssertEqual(viewModel.inputText, "draft text")
    }

    // MARK: - sessionGroups caching

    func testSessionGroupsCached() throws {
        let s1 = try decodeSession(id: "s1", title: "A", directory: "/p")
        viewModel.sessions = [s1]
        let _ = viewModel.sessionGroups
        let _ = viewModel.sessionGroups
        XCTAssertEqual(viewModel.sessionGroups.count, 1)
    }

    // MARK: - directory

    func testDirectoryForSession() throws {
        let s1 = try decodeSession(id: "s1", title: "A", directory: "/project")
        viewModel.sessions = [s1]
        XCTAssertEqual(viewModel.directory(for: "s1"), "/project")
        XCTAssertNil(viewModel.directory(for: "unknown"))
        XCTAssertNil(viewModel.directory(for: nil))
    }

    // MARK: - navigateHistory

    func testNavigateHistoryUp() {
        viewModel.sentMessageHistory = ["msg1", "msg2", "msg3"]
        viewModel.historyIndex = 1
        viewModel.navigateHistory(.up)
        XCTAssertEqual(viewModel.historyIndex, 2)
        XCTAssertEqual(viewModel.inputText, "msg3")
    }

    func testNavigateHistoryDown() {
        viewModel.sentMessageHistory = ["msg1", "msg2"]
        viewModel.historyIndex = 1
        viewModel.navigateHistory(.down)
        XCTAssertEqual(viewModel.historyIndex, 0)
        XCTAssertEqual(viewModel.inputText, "msg1")
    }

    func testNavigateHistoryDownToNil() {
        viewModel.sentMessageHistory = ["msg1"]
        viewModel.historyIndex = 0
        viewModel.navigateHistory(.down)
        XCTAssertNil(viewModel.historyIndex)
        XCTAssertEqual(viewModel.inputText, "")
    }

    func testNavigateHistoryEmpty() {
        viewModel.sentMessageHistory = []
        viewModel.navigateHistory(.up)
        XCTAssertNil(viewModel.historyIndex)
    }

    // MARK: - queue / submit / clear

    func testQueueFollowUpPromptWithoutClient() async {
        viewModel.selectedSessionId = "ses_1"
        viewModel.inputText = "follow up"
        await viewModel.queueFollowUpPrompt()
    }

    func testSubmitQueuedPromptWithoutClient() async {
        viewModel.selectedSessionId = "ses_1"
        await viewModel.submitQueuedPrompt()
    }

    func testClearQueuedPromptWithoutClient() async {
        viewModel.selectedSessionId = "ses_1"
        await viewModel.clearQueuedPrompt()
    }

    // MARK: - respondToTUIRequest

    func testRespondToTUIRequest() async throws {
        configureWithMockClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return testRespondJSON("{}")
        }
        viewModel.selectedSessionId = "ses_1"
        await viewModel.respondToTUIRequest(["answer": .string("yes")])
    }

    func testRespondToTUIRequestWithoutClient() async {
        viewModel.selectedSessionId = nil
        await viewModel.respondToTUIRequest(["answer": .string("yes")])
    }

    // MARK: - prepareNewSession

    func testPrepareNewSession() {
        viewModel.selectedSessionId = nil
        viewModel.selectedDirectory = nil
        viewModel.prepareNewSession()
        XCTAssertNil(viewModel.selectedDirectory)
    }

    // MARK: - stopEventStream

    func testStopEventStream() {
        viewModel.stopEventStream()
    }

    // MARK: - applyDelta

    func testHandleEventMessagePartDeltaSuccess() {
        let event = makeEvent(
            type: "message.part.delta",
            properties: [
                "sessionID": .string("ses_1"),
                "messageID": .string("msg_1"),
                "partID": .string("p1"),
                "delta": .string(" world")
            ]
        )
        let msgJSON = """
        {"info":{"id":"msg_1","role":"assistant","time":{"created":1}},"parts":[{"id":"p1","type":"text","text":"hello"}]}
        """
        viewModel.selectedSessionId = "ses_1"
        viewModel.messages = [try! JSONDecoder().decode(MessageEnvelope.self, from: Data(msgJSON.utf8))]
        viewModel.handleEvent(event)
        XCTAssertEqual(viewModel.messages.first?.parts.first?.text, "hello world")
    }

    func testHandleEventMessagePartDeltaMissingFields() {
        let event = makeEvent(
            type: "message.part.delta",
            properties: ["sessionID": .string("ses_1")]
        )
        viewModel.handleEvent(event)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testHandleEventMessagePartDeltaMessageNotFound() {
        let event = makeEvent(
            type: "message.part.delta",
            properties: [
                "sessionID": .string("ses_1"),
                "messageID": .string("missing"),
                "partID": .string("p1"),
                "delta": .string("x")
            ]
        )
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
    }

    func testHandleEventMessagePartDeltaPartNotFound() {
        let event = makeEvent(
            type: "message.part.delta",
            properties: [
                "sessionID": .string("ses_1"),
                "messageID": .string("msg_1"),
                "partID": .string("missing"),
                "delta": .string("x")
            ]
        )
        let msgJSON = """
        {"info":{"id":"msg_1","role":"assistant","time":{"created":1}},"parts":[{"id":"p1","type":"text","text":"hello"}]}
        """
        viewModel.messages = [try! JSONDecoder().decode(MessageEnvelope.self, from: Data(msgJSON.utf8))]
        viewModel.selectedSessionId = "ses_1"
        viewModel.handleEvent(event)
    }

    // MARK: - queue / submit / clear

    func testQueueFollowUpPrompt() async {
        configureWithMockClient { _ in
            testRespondJSON("true")
        }
        viewModel.selectedSessionId = "ses_1"
        viewModel.inputText = "follow up"
        await viewModel.queueFollowUpPrompt()
        XCTAssertTrue(viewModel.inputText.isEmpty)
    }

    func testSubmitQueuedPrompt() async {
        configureWithMockClient { _ in
            testRespondJSON("true")
        }
        viewModel.selectedSessionId = "ses_1"
        await viewModel.submitQueuedPrompt()
    }

    func testClearQueuedPrompt() async {
        configureWithMockClient { _ in
            testRespondJSON("true")
        }
        viewModel.selectedSessionId = "ses_1"
        viewModel.nextTUIRequest = TUIControlRequest(path: "/test", body: .object([:]))
        await viewModel.clearQueuedPrompt()
        XCTAssertNil(viewModel.nextTUIRequest)
    }

    // MARK: - loadMoreMessages failure

    func testLoadMoreMessagesFailure() async throws {
        let session = try decodeSession(id: "ses_fail", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_fail"
        viewModel.hasMoreMessages = true

        configureWithMockClient { _ in
            let error = NSError(domain: "test", code: 500)
            return (HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        await viewModel.loadMoreMessages()
    }

    // MARK: - enrichSessionsWithSummary

    func testLoadSessionsEnrichSummary() async throws {
        let session = try decodeSession(id: "ses_enrich", title: "T", directory: "/p")
        viewModel.sessions = [session]
        viewModel.selectedSessionId = "ses_enrich"
        let projectJSON = """
        {"id":"proj","worktree":"/p","time":{"created":1,"updated":2}}
        """
        viewModel.projects = [try JSONDecoder().decode(Project.self, from: Data(projectJSON.utf8))]

        configureWithMockClient { request in
            if request.url?.absoluteString.contains("session/") == true {
                return testRespondJSON("""
                {"id":"ses_enrich","slug":"ses_enrich","version":"1.0.0","projectID":"proj","directory":"/p","title":"T","summary":{"additions":1,"deletions":0,"files":1},"time":{"created":1,"updated":2}}
                """)
            }
            return testRespondJSON("""
            [{"id":"ses_enrich","slug":"ses_enrich","version":"1.0.0","projectID":"proj","directory":"/p","title":"T","time":{"created":1,"updated":2}}]
            """)
        }

        await viewModel.loadSessions(resetLimit: true)
        XCTAssertNotNil(viewModel.sessions.first?.summary)
    }

    // MARK: - startEventStream

    func testStartEventStreamNoClient() {
        viewModel.configure(with: nil)
        viewModel.startEventStream()
    }
}

private func makeEvent(type: String, properties: [String: JSONValue]) -> SSEEvent {
    SSEEvent(type: type, properties: properties)
}
