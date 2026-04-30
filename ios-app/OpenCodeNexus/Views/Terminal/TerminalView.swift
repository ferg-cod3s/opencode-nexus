import SwiftUI

struct TerminalView: View {
    let client: OpenCodeClient?
    let sessionId: String?
    let directory: String?
    let agent: String?
    @Environment(\.dismiss) private var dismiss
    @State private var terminalVM = TerminalViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !terminalVM.outputLines.isEmpty {
                    ScrollViewReader { proxy in
                        TerminalOutputView(lines: terminalVM.outputLines, proxy: proxy)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: terminalVM.outputLines.count) { _, _ in
                                if let lastId = terminalVM.outputLines.last?.id {
                                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                                }
                            }
                    }
                } else {
                    ContentUnavailableView("Terminal", systemImage: "terminal", description: Text("Run shell commands on the server"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.interactiveBlue)

                    TextField("Shell command...", text: $terminalVM.commandText)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { Task { await terminalVM.executeCommand() } }

                    Button {
                        Task { await terminalVM.executeCommand() }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textStrong)
                            .frame(width: 32, height: 32)
                            .background(Theme.interactiveBlue.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .disabled(terminalVM.commandText.trimmingCharacters(in: .whitespaces).isEmpty || terminalVM.isRunning)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                TerminalAccessoryView(text: $terminalVM.commandText, onSubmit: { Task { await terminalVM.executeCommand() } }, onNavigateHistory: { direction in
                    if let result = terminalVM.navigateHistory(direction) {
                        terminalVM.commandText = result
                    }
                })
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        terminalVM.clearOutput()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .onAppear {
            terminalVM.configure(client: client, sessionId: sessionId, directory: directory, agent: agent)
        }
    }
}
