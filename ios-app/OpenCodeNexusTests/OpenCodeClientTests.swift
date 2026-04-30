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
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 400)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
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
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
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
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
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

    func testOpenCodeErrorDescriptions() {
        XCTAssertEqual(OpenCodeError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(OpenCodeError.httpError(429).errorDescription, "Server error (HTTP 429)")
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
