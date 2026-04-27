import Foundation

final class OpenCodeClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func healthCheck() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("global/health")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func listSessions() async throws -> [Session] {
        let url = baseURL.appendingPathComponent("session")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([Session].self, from: data)
    }

    func createSession(title: String) async throws -> Session {
        let url = baseURL.appendingPathComponent("session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateSessionBody(title: title))
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Session.self, from: data)
    }

    func deleteSession(id: String) async throws -> Bool {
        let url = baseURL.appendingPathComponent("session/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Bool.self, from: data)
    }

    func getMessages(sessionId: String) async throws -> [Message] {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([Message].self, from: data)
    }

    func sendMessage(sessionId: String, text: String) async throws -> Message {
        let url = baseURL.appendingPathComponent("session/\(sessionId)/message")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = SendMessageBody(parts: [SendMessageBody.Part(type: "text", text: text)])
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Message.self, from: data)
    }

    func eventStream() -> AsyncThrowingStream<SSEEvent, Error> {
        let url = baseURL.appendingPathComponent("event")
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = TimeInterval.infinity

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw OpenCodeError.invalidResponse
                    }
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let jsonData = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(SSEEvent.self, from: jsonData) {
                                continuation.yield(event)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCodeError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenCodeError.httpError(httpResponse.statusCode)
        }
    }
}

private struct CreateSessionBody: Encodable {
    let title: String
}

private struct SendMessageBody: Encodable {
    let parts: [Part]

    struct Part: Encodable {
        let type: String
        let text: String
    }
}

enum OpenCodeError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .httpError(let code): "Server error (HTTP \(code))"
        case .decodingError(let detail): "Failed to parse response: \(detail)"
        }
    }
}
