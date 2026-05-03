import XCTest
import Synchronization
@testable import OpenCodeNexus

final class OpenCodeClientTests: XCTestCase {

    private var client: OpenCodeClient!
    private var mockProtocol: MockURLProtocol!

    override func setUp() {
        super.setUp()
        mockProtocol = MockURLProtocol()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        client = OpenCodeClient(
            baseURL: URL(string: "http://localhost:4096")!,
            cfAccessClientId: "test-client-id",
            cfAccessClientSecret: "test-client-secret",
            configuration: config
        )
        MockURLProtocol.setRequestHandler(nil)
    }

    override func tearDown() {
        MockURLProtocol.setRequestHandler(nil)
        client = nil
        mockProtocol = nil
        super.tearDown()
    }

    // MARK: - URL Construction

    func testHealthCheckURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/global/health")
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"healthy": true, "version": "1.0.0"}
                    """.data(using: .utf8)!)
        }
        _ = try await client.healthCheck()
    }

    func testListSessionsURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session")
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.listSessions()
    }

    func testListSessionsWithDirectory() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session")
            let query = request.url?.query
            XCTAssertNotNil(query)
            XCTAssertTrue(query!.contains("directory=/my/project"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.listSessions(directory: "/my/project")
    }

    func testListSessionsWithArchivedQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session")
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(query["archived"], "true")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.listSessions(archived: true)
    }

    func testGetSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_123")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"id": "ses_123", "directory": "/test", "title": "Test", "time": {"created": 0}}
                    """.data(using: .utf8)!)
        }
        _ = try await client.getSession("ses_123")
    }

    func testGetMessagesURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_abc/message")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.getMessages(sessionId: "ses_abc")
    }

    func testListProvidersURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/provider")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"all": [], "connected": []}
                    """.data(using: .utf8)!)
        }
        _ = try await client.listProviders()
    }

    func testConfigProvidersURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/config/providers")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"providers": [], "default": {}}
                    """.data(using: .utf8)!)
        }
        _ = try await client.listConfigProviders()
    }

    func testGetVcsURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/vcs")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"branch": "main"}
                    """.data(using: .utf8)!)
        }
        _ = try await client.getVcs()
    }

    func testGetTodosURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/todo")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    "[]".data(using: .utf8)!)
        }
        _ = try await client.getTodos("ses_1")
    }

    // MARK: - Request Body Encoding

    func testSendMessageBodyEncoding() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try! Self.jsonBody(from: request)
            let parts = body["parts"] as! [[String: String]]
            XCTAssertEqual(parts[0]["type"], "text")
            XCTAssertEqual(parts[0]["text"], "Hello!")
            XCTAssertNil(body["model"])
            XCTAssertNil(body["agent"])

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"info": {"id": "msg_new", "role": "assistant", "time": {"created": 0}}, "parts": []}
                    """.data(using: .utf8)!)
        }
        _ = try await client.sendMessage(sessionId: "ses_1", text: "Hello!")
    }

    func testSendMessageWithModelAndAgent() async throws {
        MockURLProtocol.setRequestHandler { request in
            let body = try! Self.jsonBody(from: request)
            let model = body["model"] as! [String: String?]
            XCTAssertEqual(model["providerID"], "openai")
            XCTAssertEqual(model["modelID"], "gpt-4o")
            XCTAssertEqual(body["agent"] as? String, "coder")

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"info": {"id": "msg_new", "role": "assistant", "time": {"created": 0}}, "parts": []}
                    """.data(using: .utf8)!)
        }
        _ = try await client.sendMessage(
            sessionId: "ses_1",
            text: "Write code",
            model: ModelRefBody(providerID: "openai", modelID: "gpt-4o"),
            agent: "coder"
        )
    }

    func testAsyncMessageCombinesTextAndFileParts() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/prompt_async")
            let body = try! Self.jsonBody(from: request)
            let parts = body["parts"] as! [[String: Any]]
            XCTAssertEqual(parts.count, 2)
            XCTAssertEqual(parts[0]["type"] as? String, "text")
            XCTAssertEqual(parts[0]["text"] as? String, "Describe this")
            XCTAssertEqual(parts[1]["type"] as? String, "file")
            XCTAssertEqual(parts[1]["filename"] as? String, "image.png")
            XCTAssertEqual(parts[1]["mime"] as? String, "image/png")

            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client.sendAsyncMessage(
            sessionId: "ses_1",
            text: "Describe this",
            parts: [MessagePartBody(type: "file", mime: "image/png", url: "data:image/png;base64,abc", filename: "image.png")]
        )
    }

    func testCommandModelUsesProviderSlashModelString() async throws {
        MockURLProtocol.setRequestHandler { request in
            let body = try! Self.jsonBody(from: request)
            XCTAssertEqual(body["model"] as? String, "openai/gpt-4o")
            XCTAssertEqual(body["command"] as? String, "plan")

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"info": {"id": "msg_new", "role": "assistant", "time": {"created": 0}}, "parts": []}
                    """.data(using: .utf8)!)
        }

        _ = try await client.sendCommand(
            sessionId: "ses_1",
            command: "plan",
            model: ModelRefBody(providerID: "openai", modelID: "gpt-4o")
        )
    }

    func testShellCommandDefaultsAgentToBuild() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/shell")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try! Self.jsonBody(from: request)
            XCTAssertEqual(body["command"] as? String, "ls")
            XCTAssertEqual(body["agent"] as? String, "build")
            XCTAssertNil(body["model"])

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"info": {"id": "msg_new", "role": "assistant", "time": {"created": 0}}, "parts": []}
                    """.data(using: .utf8)!)
        }

        _ = try await client.sendShellCommand(sessionId: "ses_1", command: "ls")
    }

    func testShellCommandUsesDefaultAgentForEmptyAgentAndEncodesModel() async throws {
        MockURLProtocol.setRequestHandler { request in
            let body = try! Self.jsonBody(from: request)
            let model = try XCTUnwrap(body["model"] as? [String: String])
            XCTAssertEqual(body["agent"] as? String, "build")
            XCTAssertEqual(model["providerID"], "openai")
            XCTAssertEqual(model["modelID"], "gpt-4o")

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"info": {"id": "msg_new", "role": "assistant", "time": {"created": 0}}, "parts": []}
                    """.data(using: .utf8)!)
        }

        _ = try await client.sendShellCommand(
            sessionId: "ses_1",
            command: "pwd",
            model: ModelRefBody(providerID: "openai", modelID: "gpt-4o"),
            agent: " "
        )
    }

    func testQuestionReplyBodyEncoding() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/question/que_1/reply")
            let body = try! Self.jsonBody(from: request)
            let answers = body["answers"] as! [[String]]
            XCTAssertEqual(answers, [["Yes", "Custom"]])

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "true".data(using: .utf8)!)
        }

        try await client.replyQuestion("que_1", answers: [["Yes", "Custom"]])
    }

    func testReplyQuestionIncludesDirectoryQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/question/que_1/reply")
            XCTAssertEqual(query["directory"], "/repo/app")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
        }

        try await client.replyQuestion("que_1", answers: [["Yes"]], directory: "/repo/app")
    }

    func testRejectQuestionIncludesDirectoryQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/question/que_1/reject")
            XCTAssertEqual(query["directory"], "/repo/app")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client.rejectQuestion("que_1", directory: "/repo/app")
    }

    func testResizePtyUsesPutAndAcceptsEmpty2xxResponse() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/pty/pty_1")
            XCTAssertEqual(request.httpMethod, "PUT")
            let body = try! Self.jsonBody(from: request)
            let size = try XCTUnwrap(body["size"] as? [String: Int])
            XCTAssertEqual(size["rows"], 40)
            XCTAssertEqual(size["cols"], 120)
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client.resizePty("pty_1", rows: 40, cols: 120)
    }

    func testUnshareSessionReturnsDeleteResponseWithoutSecondGet() async throws {
        let paths = Mutex<[String]>([])
        MockURLProtocol.setRequestHandler { request in
            paths.withLock { $0.append(request.url!.path) }
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/session/ses_1/share")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"id":"ses_1","projectID":"proj_1","directory":"/repo","title":"Unshared","version":"1.0.0","time":{"created":1,"updated":2}}"#.utf8))
        }

        let session = try await client.unshareSession("ses_1")

        XCTAssertEqual(session.id, "ses_1")
        XCTAssertEqual(session.title, "Unshared")
        XCTAssertEqual(paths.withLock { $0 }, ["/session/ses_1/share"])
    }

    func testArchiveSessionPatchesWithUnixMillisTimestamp() async throws {
        let capturedMethod = Mutex<String?>(nil)
        let capturedPath = Mutex<String?>(nil)
        let capturedBodyData = Mutex<Data?>(nil)
        MockURLProtocol.setRequestHandler { request in
            capturedMethod.withLock { $0 = request.httpMethod }
            capturedPath.withLock { $0 = request.url?.path }
            capturedBodyData.withLock { $0 = request.httpBody }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"ses_1","projectID":"p","directory":"/repo","title":"t","version":"1","time":{"created":1,"archived":1234567890}}"#.utf8))
        }

        let beforeMs = Int64(Date().timeIntervalSince1970 * 1000)
        let session = try await client.archiveSession("ses_1", directory: "/repo")
        let afterMs = Int64(Date().timeIntervalSince1970 * 1000)

        let method = capturedMethod.withLock { $0 }
        let path = capturedPath.withLock { $0 }
        let bodyData = capturedBodyData.withLock { $0 }
        XCTAssertEqual(method, "PATCH")
        XCTAssertEqual(path, "/session/ses_1")
        let body = try XCTUnwrap(bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let time = try XCTUnwrap(body["time"] as? [String: Any])
        let archivedNumber = try XCTUnwrap(time["archived"] as? NSNumber)
        let archived = archivedNumber.int64Value
        XCTAssertGreaterThanOrEqual(archived, beforeMs)
        XCTAssertLessThanOrEqual(archived, afterMs)
        XCTAssertNil(body["title"], "title must be omitted, not sent as null")
        XCTAssertTrue(session.isArchived)
    }

    func testUnarchiveSessionPatchesWithZeroTimestamp() async throws {
        let capturedMethod = Mutex<String?>(nil)
        let capturedPath = Mutex<String?>(nil)
        let capturedBodyData = Mutex<Data?>(nil)
        MockURLProtocol.setRequestHandler { request in
            capturedMethod.withLock { $0 = request.httpMethod }
            capturedPath.withLock { $0 = request.url?.path }
            capturedBodyData.withLock { $0 = request.httpBody }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"ses_1","projectID":"p","directory":"/repo","title":"t","version":"1","time":{"created":1,"archived":0}}"#.utf8))
        }

        let session = try await client.unarchiveSession("ses_1", directory: "/repo")

        let method = capturedMethod.withLock { $0 }
        let path = capturedPath.withLock { $0 }
        let bodyData = capturedBodyData.withLock { $0 }
        XCTAssertEqual(method, "PATCH")
        XCTAssertEqual(path, "/session/ses_1")
        let body = try XCTUnwrap(bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let time = try XCTUnwrap(body["time"] as? [String: Any])
        let archivedNumber = try XCTUnwrap(time["archived"] as? NSNumber)
        XCTAssertEqual(archivedNumber.int64Value, 0)
        XCTAssertFalse(session.isArchived)
    }

    func testEventStreamIncludesDirectoryAndWorkspaceQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/event")
            XCTAssertEqual(query["directory"], "/repo/app")
            XCTAssertEqual(query["workspace"], "main")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
            let body = "data: {\"type\":\"server.heartbeat\"}\n\n"
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }

        var iterator = client.eventStream(directory: "/repo/app", workspace: "main").makeAsyncIterator()
        let event = try await iterator.next()

        XCTAssertEqual(event?.eventType, "server.heartbeat")
    }

    func testTUIEndpointsUseExpectedPathsAndBodies() async throws {
        MockURLProtocol.setRequestHandler { request in
            switch request.url!.path {
            case "/tui/control/next":
                XCTAssertEqual(request.httpMethod, "GET")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"path":"/tmp","body":{"prompt":"continue"}}"#.utf8))
            case "/tui/control/response":
                XCTAssertEqual(request.httpMethod, "POST")
                let body = try! Self.jsonBody(from: request)
                XCTAssertEqual(body["response"] as? Bool, true)
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
            case "/tui/append-prompt":
                let body = try! Self.jsonBody(from: request)
                XCTAssertEqual(body["text"] as? String, "next prompt")
                return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            case "/tui/submit-prompt", "/tui/clear-prompt":
                XCTAssertEqual(request.httpMethod, "POST")
                return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let next = try await client.getNextTUIRequest()
        XCTAssertEqual(next.path, "/tmp")
        let response = try await client.respondToTUIRequest(body: ["response": .bool(true)])
        XCTAssertTrue(response)
        try await client.appendPrompt("next prompt")
        try await client.submitPrompt()
        try await client.clearPrompt()
    }

    func testPermissionAndQuestionListAndRejectEndpoints() async throws {
        MockURLProtocol.setRequestHandler { request in
            switch request.url!.path {
            case "/permission":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"[{"id":"perm_1","sessionID":"ses_1","type":"edit","messageID":"msg_1","title":"Edit","time":{"created":0}}]"#.utf8))
            case "/question":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"[{"id":"que_1","sessionID":"ses_1","messageID":"msg_1","title":"Choose","questions":[{"question":"Proceed?","header":"Confirm","options":[],"multiple":false,"custom":true}]}]"#.utf8))
            case "/question/que_1/reject":
                XCTAssertEqual(request.httpMethod, "POST")
                return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let permissions = try await client.listPermissions()
        XCTAssertEqual(permissions.first?.id, "perm_1")
        let questions = try await client.listQuestions()
        XCTAssertEqual(questions.first?.title, "Choose")
        try await client.rejectQuestion("que_1")
    }

    func testGetFileContentIncludesDirectoryAndWorkspaceQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(components.path, "/file/content")
            XCTAssertEqual(query["path"], "Sources/App.swift")
            XCTAssertEqual(query["directory"], "/repo")
            XCTAssertEqual(query["workspace"], "main")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"type":"text","content":"hi"}"#.utf8))
        }
        let content = try await client.getFileContent(path: "Sources/App.swift", directory: "/repo", workspace: "main")
        XCTAssertEqual(content.content, "hi")
    }

    func testListFilesIncludesExplicitRootPathDirectoryAndWorkspaceQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/file")
            XCTAssertEqual(query["path"], "")
            XCTAssertEqual(query["directory"], "/repo")
            XCTAssertEqual(query["workspace"], "main")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }

        _ = try await client.listFiles(directory: "/repo", workspace: "main")
    }

    func testListFilesIncludesNestedPathQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/file")
            XCTAssertEqual(query["path"], "Sources")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }

        _ = try await client.listFiles(path: "Sources")
    }

    func testGetFileStatusIncludesDirectoryAndWorkspaceQuery() async throws {
        MockURLProtocol.setRequestHandler { request in
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(components.path, "/file/status")
            XCTAssertEqual(query["directory"], "/repo")
            XCTAssertEqual(query["workspace"], "main")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }

        _ = try await client.getFileStatus(directory: "/repo", workspace: "main")
    }

    func testCreateSessionBodyEncoding() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try! Self.jsonBody(from: request)
            XCTAssertEqual(body["title"] as? String, "New Chat")
            XCTAssertEqual(body["parentID"] as? String, "ses_parent")

            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"id": "ses_new", "directory": "/test", "title": "New Chat", "time": {"created": 0}}
                    """.data(using: .utf8)!)
        }
        _ = try await client.createSession(title: "New Chat", parentID: "ses_parent")
    }

    // MARK: - Response Validation

    func test200ResponseSucceeds() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"healthy": true, "version": "1.0.0"}
                    """.data(using: .utf8)!)
        }
        let result = try await client.healthCheck()
        XCTAssertTrue(result.healthy)
    }

    func test204ResponseSucceeds() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!,
                    Data())
        }
        let result = try await client.deleteSession(id: "ses_del")
        XCTAssertTrue(result)
    }

    func test400ResponseThrows() async {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                    "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await client.healthCheck()
            XCTFail("Should have thrown")
        } catch let error as OpenCodeError {
            XCTAssertTrue(error.errorDescription?.contains("400") ?? false, "Expected HTTP 400, got \(error.errorDescription ?? "")")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test500ResponseThrows() async {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                    "Internal Server Error".data(using: .utf8)!)
        }
        do {
            _ = try await client.healthCheck()
            XCTFail("Should have thrown")
        } catch let error as OpenCodeError {
            XCTAssertTrue(error.errorDescription?.contains("500") ?? false, "Expected HTTP 500, got \(error.errorDescription ?? "")")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test404ResponseThrows() async {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                    "Not Found".data(using: .utf8)!)
        }
        do {
            _ = try await client.healthCheck()
            XCTFail("Should have thrown")
        } catch let error as OpenCodeError {
            XCTAssertTrue(error.errorDescription?.contains("404") ?? false, "Expected HTTP 404, got \(error.errorDescription ?? "")")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Auth Header Injection

    func testAuthHeadersInjected() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "CF-Access-Client-Id"), "test-client-id")
            XCTAssertEqual(request.value(forHTTPHeaderField: "CF-Access-Client-Secret"), "test-client-secret")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"healthy": true, "version": "1.0.0"}
                    """.data(using: .utf8)!)
        }
        _ = try await client.healthCheck()
    }

    func testAuthHeadersNotInjectedWithoutCredentials() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let noAuthClient = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!, configuration: config)
        MockURLProtocol.setRequestHandler { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "CF-Access-Client-Id"))
            XCTAssertNil(request.value(forHTTPHeaderField: "CF-Access-Client-Secret"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    """
                    {"healthy": true, "version": "1.0.0"}
                    """.data(using: .utf8)!)
        }
        _ = try await noAuthClient.healthCheck()
    }

    // MARK: - sendAsyncMessage 204 Handling

    func testSendAsyncMessageHandles204() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/prompt_async")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!,
                    Data())
        }
        try await client.sendAsyncMessage(sessionId: "ses_1", text: "Hello async")
    }

    func testSendAsyncMessageHandles200() async throws {
        MockURLProtocol.setRequestHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data())
        }
        try await client.sendAsyncMessage(sessionId: "ses_1", text: "Hello")
    }

    // MARK: - Error Descriptions

    func testGetSessionStatusURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/status")
            let json = """
            {"ses_1": {"status": "idle"}}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let result = try await client.getSessionStatus()
        XCTAssertEqual(result["ses_1"]?.status, "idle")
    }

    func testGetChildrenURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/children")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }
        _ = try await client.getChildren("ses_1")
    }

    func testForkSessionBody() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/fork")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("""
            {"id":"forked","slug":"forked","version":"1.0.0","projectID":"p","directory":"/","title":"Fork","time":{"created":1,"updated":1}}
            """.utf8))
        }
        _ = try await client.forkSession("ses_1", messageID: "msg_1")
    }

    func testShareSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            if request.httpMethod == "POST" {
                XCTAssertEqual(request.url?.path, "/session/ses_1/share")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
            }
            XCTAssertEqual(request.url?.path, "/session/ses_1")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("""
            {"id":"ses_1","slug":"ses_1","version":"1.0.0","projectID":"p","directory":"/","title":"Shared","time":{"created":1,"updated":1}}
            """.utf8))
        }
        _ = try await client.shareSession("ses_1")
    }

    func testSummarizeSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/summarize")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
        }
        try await client.summarizeSession("ses_1")
    }

    func testRevertMessageURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/revert")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
        }
        try await client.revertMessage("ses_1", messageID: "msg_1", partID: "part_1")
    }

    func testDeleteSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1")
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
        }
        let result = try await client.deleteSession(id: "ses_1")
        XCTAssertTrue(result)
    }

    func testAbortSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/abort")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
        }
        try await client.abortSession(sessionId: "ses_1")
    }

    func testDeleteMessageURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1/message/msg_1")
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("true".utf8))
        }
        try await client.deleteMessage(sessionId: "ses_1", messageID: "msg_1")
    }

    func testFindTextURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/find")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }
        _ = try await client.findText(pattern: "func test")
    }

    func testFindFilesURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/find/file")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }
        _ = try await client.findFiles(query: "*.swift")
    }

    func testUpdateSessionBody() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_1")
            XCTAssertEqual(request.httpMethod, "PATCH")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("""
            {"id":"ses_1","slug":"ses_1","version":"1.0.0","projectID":"p","directory":"/","title":"New Title","time":{"created":1,"updated":1}}
            """.utf8))
        }
        _ = try await client.updateSession("ses_1", title: "New Title")
    }

    func testBasicAuthHeaderInjection() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let authClient = OpenCodeClient(
            baseURL: URL(string: "http://localhost:4096")!,
            username: "user",
            password: "pass",
            configuration: config
        )
        MockURLProtocol.setRequestHandler { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertNotNil(authHeader)
            XCTAssertTrue(authHeader?.hasPrefix("Basic ") == true)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("""
            {"id":"s","slug":"s","version":"1.0.0","projectID":"p","directory":"/","title":"T","time":{"created":1,"updated":1}}
            """.utf8))
        }
        _ = try await authClient.getSession("s")
    }

    func testListProjectsURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/project")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("[]".utf8))
        }
        _ = try await client.listProjects()
    }

    func testOpenCodeErrorDescriptions() {
        XCTAssertEqual(OpenCodeError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(OpenCodeError.httpError(429, nil).errorDescription, "Server error (HTTP 429)")
        XCTAssertEqual(OpenCodeError.decodingError("bad json").errorDescription, "Failed to parse response: bad json")
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            var collected = Data()
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                collected.append(buffer, count: count)
            }
            data = collected
        } else {
            XCTFail("Expected request body")
            return [:]
        }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private static func queryDictionary(from components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    // MARK: - New Endpoints (Phase 1)

    func testInitSessionURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_123/init")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.initSession("ses_123")
    }

    func testInitSessionWithDirectory() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_123/init")
            let query = request.url?.query
            XCTAssertNotNil(query)
            XCTAssertTrue(query!.contains("directory=/my/project"))
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.initSession("ses_123", directory: "/my/project")
    }

    func testDeleteMessagePartURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_123/message/msg_456/part/part_789")
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "true".data(using: .utf8)!)
        }
        try await client.deleteMessagePart(sessionId: "ses_123", messageID: "msg_456", partID: "part_789")
    }

    func testUpdateMessagePartURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/session/ses_123/message/msg_456/part/part_789")
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "true".data(using: .utf8)!)
        }
        try await client.updateMessagePart(sessionId: "ses_123", messageID: "msg_456", partID: "part_789", body: ["text": .string("updated")])
    }

    func testGetVcsDiffURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/vcs/diff")
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{\"files\": []}".data(using: .utf8)!)
        }
        _ = try await client.getVcsDiff()
    }

    func testCreateWorkspaceIncludesDirectoryQueryAndExplicitNullBranch() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/experimental/workspace")
            XCTAssertEqual(request.httpMethod, "POST")
            let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
            let query = Self.queryDictionary(from: components)
            XCTAssertEqual(query["directory"], "/tmp/project")

            let body = try Self.jsonBody(from: request)
            XCTAssertEqual(body["type"] as? String, "worktree")
            XCTAssertTrue(body.keys.contains("branch"))
            XCTAssertTrue(body["branch"] is NSNull)
            XCTAssertTrue(body.keys.contains("extra"))
            XCTAssertTrue(body["extra"] is NSNull)

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                "{\"id\":\"w1\",\"type\":\"worktree\",\"branch\":null,\"directory\":\"/tmp/project\",\"status\":\"connected\"}".data(using: .utf8)!
            )
        }

        _ = try await client.createWorkspace(type: "worktree", branch: nil, directory: "/tmp/project")
    }

    func testCreateWorkspaceSendsBranchStringWhenProvided() async throws {
        MockURLProtocol.setRequestHandler { request in
            let body = try Self.jsonBody(from: request)
            XCTAssertEqual(body["type"] as? String, "worktree")
            XCTAssertEqual(body["branch"] as? String, "feature/workspaces")
            XCTAssertTrue(body.keys.contains("extra"))
            XCTAssertTrue(body["extra"] is NSNull)

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                "{\"id\":\"w2\",\"type\":\"worktree\",\"branch\":\"feature/workspaces\",\"directory\":\"/tmp/project\",\"status\":\"connected\"}".data(using: .utf8)!
            )
        }

        _ = try await client.createWorkspace(type: "worktree", branch: "feature/workspaces", directory: "/tmp/project")
    }

    func testCreateWorkspaceOmitsDirectoryQueryWhenNotProvided() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertNil(request.url?.query)

            let body = try Self.jsonBody(from: request)
            XCTAssertEqual(body["type"] as? String, "worktree")
            XCTAssertTrue(body.keys.contains("branch"))
            XCTAssertTrue(body["branch"] is NSNull)
            XCTAssertTrue(body.keys.contains("extra"))
            XCTAssertTrue(body["extra"] is NSNull)

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                "{\"id\":\"w3\",\"type\":\"worktree\",\"branch\":null,\"directory\":\"/tmp/project\",\"status\":\"connected\"}".data(using: .utf8)!
            )
        }

        _ = try await client.createWorkspace(type: "worktree")
    }

    func testListMcpServersURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/mcp")
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "[]".data(using: .utf8)!)
        }
        _ = try await client.listMcpServers()
    }

    func testAddMcpServerURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/mcp")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.addMcpServer(name: "test-server", command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem"])
    }

    func testConnectMcpServerURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/mcp/test-server/connect")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.connectMcpServer(name: "test-server")
    }

    func testDisconnectMcpServerURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/mcp/test-server/disconnect")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.disconnectMcpServer(name: "test-server")
    }

    func testRemoveMcpServerURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/mcp/test-server")
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "true".data(using: .utf8)!)
        }
        try await client.removeMcpServer(name: "test-server")
    }

    func testStartProviderOAuthURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/provider/openai/oauth/authorize")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{\"url\": \"https://oauth.example.com\"}".data(using: .utf8)!)
        }
        _ = try await client.startProviderOAuth(providerID: "openai")
    }

    func testCompleteProviderOAuthURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/provider/openai/oauth/callback")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.completeProviderOAuth(providerID: "openai", code: "auth_code", state: "state_token")
    }

    func testDisconnectProviderURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/provider/openai/disconnect")
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.disconnectProvider(providerID: "openai")
    }

    func testGetConfigURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/config")
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
        }
        _ = try await client.getConfig()
    }

    func testUpdateConfigURL() async throws {
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/config")
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let config = ConfigUpdate(theme: "dark", language: nil, autoAcceptPermissions: nil, reasoningSummaries: nil, shellToolParts: nil, editToolParts: nil, sessionProgressBar: nil, visibleModels: nil, hiddenModels: nil)
        try await client.updateConfig(config)
    }
}

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    typealias RequestHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let requestHandler = Mutex<RequestHandler?>(nil)

    static func setRequestHandler(_ handler: RequestHandler?) {
        requestHandler.withLock { $0 = handler }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler.withLock({ $0 }) else {
            XCTFail("No request handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
