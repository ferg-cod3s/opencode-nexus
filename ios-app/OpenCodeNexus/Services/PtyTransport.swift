import Foundation
import os

protocol PtyTransport: Sendable {
    var output: AsyncThrowingStream<Data, Error> { get }
    func connect(request: URLRequest) async throws
    func send(_ data: Data) async throws
    func close() async
}

protocol PtyTransportFactory: Sendable {
    func makeTransport() -> PtyTransport
}

final class URLSessionPtyTransport: PtyTransport, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "PtyTransport")
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private let _continuation: AsyncThrowingStream<Data, Error>.Continuation
    let output: AsyncThrowingStream<Data, Error>

    init(session: URLSession = .shared) {
        self.session = session
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.output = AsyncThrowingStream { cont in
            continuation = cont
        }
        self._continuation = continuation
        self.webSocketTask = nil
        continuation.onTermination = { [weak self] _ in
            Task { await self?.close() }
        }
    }

    func connect(request: URLRequest) async throws {
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        startReceiveLoop()
    }

    func send(_ data: Data) async throws {
        guard let task = webSocketTask else { return }
        if let text = String(data: data, encoding: .utf8) {
            try await task.send(.string(text))
        } else {
            try await task.send(.data(data))
        }
    }

    func close() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        _continuation.finish()
    }

    private func startReceiveLoop() {
        guard let task = webSocketTask else { return }
        Task { [weak self] in
            do {
                while true {
                    let message = try await task.receive()
                    switch message {
                    case .data(let data):
                        self?._continuation.yield(data)
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self?._continuation.yield(data)
                        }
                    @unknown default:
                        break
                    }
                }
            } catch {
                self?.logger.debug("PTY WebSocket receive ended: \(error.localizedDescription)")
                self?._continuation.finish(throwing: error)
            }
        }
    }
}

final class DefaultPtyTransportFactory: PtyTransportFactory, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func makeTransport() -> PtyTransport {
        URLSessionPtyTransport(session: session)
    }
}
