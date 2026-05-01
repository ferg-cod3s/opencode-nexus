import XCTest
@testable import OpenCodeNexus

final class TerminalShellFlowTests: XCTestCase {
    func testSendShellCommandPostsToSessionShell() async throws {
        let session = try decodeSession(id: "ses_shell", title: "Shell", directory: "/repo", updated: 1)
        let viewModel = await MainActor.run { () -> ChatViewModel in
            let viewModel = ChatViewModel()
            viewModel.sessions = [session]
            viewModel.selectedSessionId = session.id
            return viewModel
        }

        let client = makeMockClient { request in
            switch request.url?.path {
            case "/session/ses_shell/shell":
                XCTAssertEqual(request.httpMethod, "POST")
                let body = try requestBody(from: request)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(object["command"] as? String, "git status")
                XCTAssertEqual(object["agent"] as? String, "build")
                return respondJSON("""
                {"info":{"id":"msg_shell","role":"assistant","time":{"created":1}},"parts":[]}
                """)
            case "/session/ses_shell/message":
                XCTAssertEqual(request.httpMethod, "GET")
                return respondJSON("[]")
            default:
                XCTFail("Unexpected path \(request.url?.path ?? "nil")")
                return respondJSON("[]", statusCode: 404)
            }
        }
        await MainActor.run {
            viewModel.configure(with: client)
        }

        await viewModel.sendShellCommand("git status")

        await MainActor.run {
            XCTAssertFalse(viewModel.isSending)
            XCTAssertNil(viewModel.errorMessage)
        }
    }

    func testSendShellCommandUsesSelectedAgentAndModel() async throws {
        let session = try decodeSession(id: "ses_shell_model", title: "Shell", directory: "/repo", updated: 1)
        let viewModel = await MainActor.run { () -> ChatViewModel in
            let viewModel = ChatViewModel()
            viewModel.sessions = [session]
            viewModel.selectedSessionId = session.id
            viewModel.selectedAgent = "coder"
            viewModel.selectedModel = ModelRefBody(providerID: "openai", modelID: "gpt-4o")
            return viewModel
        }

        let client = makeMockClient { request in
            switch request.url?.path {
            case "/session/ses_shell_model/shell":
                let body = try requestBody(from: request)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(object["agent"] as? String, "coder")
                let model = try XCTUnwrap(object["model"] as? [String: String])
                XCTAssertEqual(model["providerID"], "openai")
                XCTAssertEqual(model["modelID"], "gpt-4o")
                return respondJSON("""
                {"info":{"id":"msg_shell_model","role":"assistant","time":{"created":1}},"parts":[]}
                """)
            case "/session/ses_shell_model/message":
                XCTAssertEqual(request.httpMethod, "GET")
                return respondJSON("[]")
            default:
                XCTFail("Unexpected path \(request.url?.path ?? "nil")")
                return respondJSON("[]", statusCode: 404)
            }
        }
        await MainActor.run {
            viewModel.configure(with: client)
        }

        await viewModel.sendShellCommand("pwd")

        await MainActor.run {
            XCTAssertFalse(viewModel.isSending)
            XCTAssertNil(viewModel.errorMessage)
        }
    }

    func testSendShellCommandRequiresSelectedSession() async {
        let client = makeMockClient { _ in
            XCTFail("No request should be made without a selected session")
            return respondJSON("[]")
        }
        let viewModel = await MainActor.run { () -> ChatViewModel in
            let viewModel = ChatViewModel()
            viewModel.configure(with: client)
            viewModel.selectedSessionId = nil
            return viewModel
        }

        await viewModel.sendShellCommand("ls")

        await MainActor.run {
            XCTAssertFalse(viewModel.isSending)
        }
    }

    private func makeMockClient(handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> OpenCodeClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.setRequestHandler(handler)
        return OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!, configuration: config)
    }

    private func decodeSession(id: String, title: String, directory: String, updated: Int64) throws -> Session {
        let json = """
        {"id":"\(id)","projectID":"proj_1","directory":"\(directory)","title":"\(title)","version":"1.0.0","time":{"created":1,"updated":\(updated)}}
        """
        return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
    }
}

private func respondJSON(_ json: String, statusCode: Int = 200, url: URL = URL(string: "http://localhost:4096")!) -> (HTTPURLResponse, Data) {
    (
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!,
        Data(json.utf8)
    )
}

private func requestBody(from request: URLRequest) throws -> Data {
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
