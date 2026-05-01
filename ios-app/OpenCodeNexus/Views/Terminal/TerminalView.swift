import SwiftUI
import GhosttyTerminal

struct TerminalView: View {
    let client: OpenCodeClient?
    let sessionId: String?
    let directory: String?
    let agent: String?
    @Environment(\.dismiss) private var dismiss
    @State private var terminalVM = TerminalViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if let state = terminalVM.terminalState, terminalVM.connectionState == .connected {
                    TerminalSurfaceView(context: state)
                        .overlay {
                            TerminalFocusHelper()
                        }
                } else if terminalVM.connectionState == .failed {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Connection Failed")
                            .font(.headline)
                        Text(terminalVM.errorMessage ?? "Unknown error")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await terminalVM.retryTerminal() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if terminalVM.connectionState == .connecting {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let msg = terminalVM.debugMessage {
                            Text(msg)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    ContentUnavailableView("Terminal", systemImage: "terminal", description: Text("Run shell commands on the server"))
                }
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            terminalVM.configure(client: client, sessionId: sessionId, directory: directory, agent: agent)
            Task { await terminalVM.startTerminal() }
        }
        .onDisappear {
            Task { await terminalVM.closeTerminal() }
        }
    }
}

private struct TerminalFocusHelper: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = FocusTargetView()
        view.backgroundColor = .clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            view.findAndFocusTerminal()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class FocusTargetView: UIView {
        func findAndFocusTerminal() {
            var responder: UIResponder? = self
            while let current = responder {
                if String(describing: type(of: current)).contains("UITerminalView") {
                    current.becomeFirstResponder()
                    return
                }
                responder = current.next
            }
            if let terminal = superview?.superview?.subviews
                .flatMap({ findTerminalViews(in: $0) })
                .first {
                terminal.becomeFirstResponder()
            }
        }

        private func findTerminalViews(in view: UIView) -> [UIView] {
            var results: [UIView] = []
            if String(describing: type(of: view)).contains("UITerminalView") {
                results.append(view)
            }
            for subview in view.subviews {
                results.append(contentsOf: findTerminalViews(in: subview))
            }
            return results
        }
    }
}