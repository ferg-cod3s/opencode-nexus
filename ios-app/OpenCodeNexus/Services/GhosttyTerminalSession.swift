import Foundation
import GhosttyTerminal

final class GhosttyTerminalSession: @unchecked Sendable {
    private let transport: PtyTransport
    private let _ghosttySession: InMemoryTerminalSession
    private var receiveTask: Task<Void, Never>?
    private let onError: @Sendable (Error) -> Void

    var ghosttySession: InMemoryTerminalSession { _ghosttySession }

    init(
        transport: PtyTransport,
        onResize: @escaping @Sendable (Int, Int) -> Void,
        onError: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.transport = transport
        self.onError = onError
        let resizeHandler = onResize
        self._ghosttySession = InMemoryTerminalSession(
            write: { data in
                Task { try? await transport.send(data) }
            },
            resize: { viewport in
                resizeHandler(Int(viewport.columns), Int(viewport.rows))
            }
        )
    }

    func start() {
        let stream = transport.output
        receiveTask = Task { [weak self] in
            do {
                for try await data in stream {
                    guard let self, !Task.isCancelled else { break }
                    self._ghosttySession.receive(data)
                }
            } catch is CancellationError {
            } catch {
                self?.onError(error)
            }
        }
    }

    func stop() async {
        receiveTask?.cancel()
        receiveTask = nil
        await transport.close()
    }

    func sendInput(_ data: Data) {
        _ghosttySession.sendInput(data)
    }
}
