import SwiftUI
import GhosttyTerminal

struct TerminalTabsView: View {
    @State private var tabManager: TerminalTabManager
    @Environment(\.dismiss) private var dismiss

    init(client: OpenCodeClient?, sessionId: String?, directory: String?, agent: String?) {
        _tabManager = State(initialValue: TerminalTabManager(client: client, sessionId: sessionId, directory: directory, agent: agent))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if tabManager.tabs.isEmpty {
                    ContentUnavailableView("No Terminals", systemImage: "terminal", description: Text("Tap + to open a terminal"))
                } else {
                    tabContentView
                    tabBar
                }
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Task { await tabManager.closeAll() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        tabManager.addTerminal()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.addTerminal()
            }
        }
        .onDisappear {
            Task { await tabManager.closeAll() }
        }
    }

    private var tabContentView: some View {
        Group {
            if let selectedTab = tabManager.selectedTab {
                TerminalContent(viewModel: selectedTab.viewModel)
                    .id(selectedTab.id)
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    Button {
                        tabManager.selectTerminal(id: tab.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal.fill")
                                .font(.caption)
                            Text(tab.title)
                                .font(.caption)
                            if tabManager.tabs.count > 1 {
                                Button {
                                    tabManager.closeTerminal(id: tab.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(tab.id == tabManager.selectedTabId ? Color.blue.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.gray.opacity(0.2))
    }
}

private struct TerminalContent: View {
    let viewModel: TerminalViewModel

    var body: some View {
        ZStack {
            if let state = viewModel.terminalState, viewModel.connectionState == .connected {
                TerminalSurfaceView(context: state)
                    .overlay {
                        TerminalFocusHelper()
                    }
            } else if viewModel.connectionState == .failed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Connection Failed")
                        .font(.headline)
                    Text(viewModel.errorMessage ?? "Unknown error")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await viewModel.retryTerminal() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if viewModel.connectionState == .connecting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let msg = viewModel.debugMessage {
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
