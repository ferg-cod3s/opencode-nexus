import SwiftUI
import GhosttyTerminal
import os

enum TerminalConnectionState {
    case disconnected
    case connecting
    case connected
    case failed
}

@MainActor
@Observable
final class TerminalViewModel {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "TerminalViewModel")

    var errorMessage: String?
    var debugMessage: String?
    var connectionState: TerminalConnectionState = .disconnected
    var terminalState: TerminalViewState?

    private var client: OpenCodeClient?
    private var sessionId: String?
    private var directory: String?
    private var agent: String?
    private var ptyId: String?
    @ObservationIgnored private var transport: PtyTransport?
    @ObservationIgnored private var terminalSession: GhosttyTerminalSession?
    private var hasStartedPty = false

    @ObservationIgnored private var transportFactory: PtyTransportFactory?

    func configure(client: OpenCodeClient?, sessionId: String?, directory: String?, agent: String?, transportFactory: PtyTransportFactory? = nil) {
        self.client = client
        self.sessionId = sessionId
        self.directory = directory
        self.agent = agent
        self.transportFactory = transportFactory
    }

    func startTerminal() async {
        guard !hasStartedPty else { return }
        guard let client else {
            logger.error("startTerminal: client is nil")
            errorMessage = "No server connection"
            connectionState = .failed
            return
        }
        hasStartedPty = true
        connectionState = .connecting
        debugMessage = "Creating PTY session..."

        do {
            debugMessage = "Step 1/4: POST /pty (command=/bin/bash, cwd=\(directory ?? "nil"))"
            logger.info("Terminal: creating PTY, cwd=\(self.directory ?? "nil")")
            let pty = try await client.createPty(
                command: "/bin/bash",
                cwd: directory,
                title: "OpenCode Terminal"
            )
            ptyId = pty.id
            logger.info("Terminal: PTY created: \(pty.id), pid=\(pty.pid ?? -1), status=\(pty.status)")
            debugMessage = "Step 2/4: PTY \(pty.id) created, building WS URL..."

            let wsRequest = client.ptyConnectRequest(ptyID: pty.id)
            logger.info("Terminal: WS URL: \(wsRequest.url?.absoluteString ?? "nil")")
            debugMessage = "WS: \(wsRequest.url?.absoluteString ?? "nil")"

            let factory = transportFactory ?? DefaultPtyTransportFactory(session: client.urlSession)
            let ptyTransport = factory.makeTransport()
            transport = ptyTransport

            debugMessage = "Step 3/4: Connecting WebSocket..."
            logger.info("Terminal: connecting WebSocket...")
            try await ptyTransport.connect(request: wsRequest)
            logger.info("Terminal: WebSocket connected")
            debugMessage = "Step 4/4: Starting Ghostty session..."

            let session = GhosttyTerminalSession(
                transport: ptyTransport,
                onResize: { [weak self] cols, rows in
                    Task { @MainActor in
                        await self?.resizeTerminal(rows: rows, cols: cols)
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        guard let self else { return }
                        self.logger.error("Terminal session error: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.connectionState = .failed
                        self.hasStartedPty = false
                    }
                }
            )
            terminalSession = session

            let state = TerminalViewState(
                theme: TerminalTheme(
                    light: TerminalConfiguration { $0.withBackgroundOpacity(1.0) },
                    dark: TerminalConfiguration { $0.withBackgroundOpacity(1.0) }
                ),
                terminalConfiguration: .default
            )
            state.configuration = TerminalSurfaceOptions(
                backend: .inMemory(session.ghosttySession)
            )
            state.onClose = { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.logger.info("Terminal process exited")
                    self.errorMessage = "Terminal process exited"
                    self.connectionState = .failed
                    self.hasStartedPty = false
                }
            }
            terminalState = state

            debugMessage = nil
            connectionState = .connected
            session.start()

            logger.info("Terminal connected: PTY \(pty.id)")
        } catch let error as OpenCodeError {
            logger.error("Failed to start PTY (OpenCodeError): \(error.localizedDescription)")
            errorMessage = "Server error: \(error.localizedDescription)"
            debugMessage = "Failed at step. Check server logs."
            connectionState = .failed
            hasStartedPty = false
        } catch {
            logger.error("Failed to start PTY: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            debugMessage = "Error: \(type(of: error)) - \(error.localizedDescription)"
            connectionState = .failed
            hasStartedPty = false
        }
    }

    func retryTerminal() async {
        await closeTerminal()
        await startTerminal()
    }

    func closeTerminal() async {
        await terminalSession?.stop()
        terminalSession = nil
        terminalState = nil
        transport = nil
        if let ptyId, let client {
            try? await client.removePty(ptyId)
        }
        ptyId = nil
        connectionState = .disconnected
        hasStartedPty = false
        debugMessage = nil
    }

    func resizeTerminal(rows: Int, cols: Int) async {
        guard let ptyId, let client else { return }
        try? await client.resizePty(ptyId, rows: rows, cols: cols, directory: directory)
    }
}
