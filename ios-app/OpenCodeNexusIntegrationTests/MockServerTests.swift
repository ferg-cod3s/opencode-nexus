import XCTest
@testable import OpenCodeNexus
import Network

final class MockServerTests: XCTestCase {

    private var mockServer: MockHTTPServer?
    private var client: OpenCodeClient?

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        mockServer?.stop()
        mockServer = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Health Endpoint

    func testHealthEndpointReturnsHealthy() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        let health = try await testClient.healthCheck()
        XCTAssertTrue(health.healthy)
        XCTAssertEqual(health.version, "test-1.0.0")
    }

    // MARK: - Session List

    func testSessionListReturnsSessions() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        let sessions = try await testClient.listSessions()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].id, "ses_mock_1")
        XCTAssertEqual(sessions[1].id, "ses_mock_2")
    }

    // MARK: - Session Creation

    func testSessionCreationReturnsNewSession() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        let session = try await testClient.createSession(title: "Test Session")
        XCTAssertEqual(session.id, "ses_created")
        XCTAssertEqual(session.title, "Test Session")
    }

    // MARK: - Message List

    func testMessageListReturnsMessages() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        let messages = try await testClient.getMessages(sessionId: "ses_mock_1")
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].info.role, .user)
        XCTAssertEqual(messages[1].info.role, .assistant)
    }

    // MARK: - SSE Event Stream

    func testSSEEndpointReturnsEventStream() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        var receivedEvents: [SSEEvent] = []
        let stream = testClient.eventStream()
        var iterator = stream.makeAsyncIterator()

        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(3))
        }

        while let event = try? await iterator.next() {
            receivedEvents.append(event)
            if receivedEvents.count >= 3 { break }
        }
        timeoutTask.cancel()

        XCTAssertGreaterThanOrEqual(receivedEvents.count, 3)
        XCTAssertEqual(receivedEvents[0].type, "server.connected")
        XCTAssertEqual(receivedEvents[1].type, "session.created")
        XCTAssertEqual(receivedEvents[2].type, "session.status")
    }

    // MARK: - Full Flow: Connect -> Create Session -> Send Message -> Receive Events

    func testFullFlowConnectCreateSessionSendMessage() async throws {
        let server = try startMockServer()
        let testClient = makeClient(port: server.port)

        let health = try await testClient.healthCheck()
        XCTAssertTrue(health.healthy)

        let session = try await testClient.createSession(title: "Full Flow Test")
        XCTAssertEqual(session.title, "Full Flow Test")

        let messages = try await testClient.getMessages(sessionId: session.id)
        XCTAssertGreaterThanOrEqual(messages.count, 0)

        try await testClient.sendAsyncMessage(sessionId: session.id, text: "Hello!")
    }

    // MARK: - Helpers

    private func startMockServer() throws -> MockHTTPServer {
        let server = try MockHTTPServer()
        try server.start()
        mockServer = server
        return server
    }

    private func makeClient(port: UInt16) -> OpenCodeClient {
        OpenCodeClient(baseURL: URL(string: "http://localhost:\(port)")!)
    }
}

// MARK: - Mock HTTP Server

final class MockHTTPServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    let port: UInt16

    init() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params)
        self.listener = listener
        self.port = 0
    }

    func start() throws {
        guard let listener else { return }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break
            case .failed(let error):
                print("Mock server failed: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .main)

        let semaphore = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .now() + 5)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.removeAll()
    }

    private var actualPort: UInt16 {
        guard let port = listener?.port?.rawValue else { return 0 }
        return port
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                self?.processRequest(data, on: connection)
            }
            if !isComplete, error == nil {
                self?.receiveRequest(on: connection)
            }
        }
    }

    private func processRequest(_ data: Data, on connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else { return }

        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let components = firstLine.split(separator: " ")
        guard components.count >= 2 else { return }

        let method = String(components[0])
        let path = String(components[1])

        let response: (Int, String)
        switch path {
        case "/global/health":
            response = (200, """
            {"healthy": true, "version": "test-1.0.0"}
            """)
        case "/session" where method == "GET":
            response = (200, """
            [
                {"id": "ses_mock_1", "directory": "/project1", "title": "Mock Session 1", "time": {"created": 1700000000000}},
                {"id": "ses_mock_2", "directory": "/project2", "title": "Mock Session 2", "time": {"created": 1700001000000}}
            ]
            """)
        case "/session" where method == "POST":
            let title = extractTitle(from: request) ?? "Untitled"
            response = (200, """
            {"id": "ses_created", "directory": "/project1", "title": "\(title)", "time": {"created": 1700002000000}}
            """)
        case let p where p.hasPrefix("/session/") && p.hasSuffix("/message") && method == "GET":
            response = (200, """
            [
                {"info": {"id": "msg_1", "role": "user", "time": {"created": 1700000000000}}, "parts": [{"type": "text", "text": "Hello!"}]},
                {"info": {"id": "msg_2", "role": "assistant", "time": {"created": 1700000001000}}, "parts": [{"type": "text", "text": "Hi there!"}]}
            ]
            """)
        case let p where p.hasPrefix("/session/") && p.hasSuffix("/prompt_async") && method == "POST":
            response = (204, "")
        case "/event":
            let sseData = [
                "data: {\"type\": \"server.connected\"}\n",
                "data: {\"type\": \"session.created\", \"properties\": {\"sessionID\": \"ses_mock_1\"}}\n",
                "data: {\"type\": \"session.status\", \"properties\": {\"sessionID\": \"ses_mock_1\", \"status\": {\"type\": \"busy\"}}}\n"
            ].joined()
            let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: keep-alive\r\n\r\n\(sseData)"
            let responseData = httpResponse.data(using: .utf8)!
            connection.send(content: responseData, completion: .contentProcessed { _ in })
            return
        default:
            response = (404, "{\"error\": \"not found\"}")
        }

        let httpResponse = "HTTP/1.1 \(response.0) OK\r\nContent-Type: application/json\r\nContent-Length: \(response.1.utf8.count)\r\nConnection: close\r\n\r\n\(response.1)"
        let responseData = httpResponse.data(using: .utf8)!
        connection.send(content: responseData, completion: .contentProcessed { _ in })
    }

    private func extractTitle(from request: String) -> String? {
        guard let bodyStart = request.range(of: "\r\n\r\n") else { return nil }
        let body = String(request[bodyStart.upperBound...])
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["title"] as? String
    }
}
