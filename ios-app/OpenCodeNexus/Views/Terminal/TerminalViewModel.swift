import SwiftUI
import os

@MainActor
@Observable
final class TerminalViewModel {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "TerminalViewModel")

    var outputLines: [TerminalLine] = []
    var commandHistory: [String] = []
    var historyIndex: Int?
    var isRunning = false
    var commandText = ""
    var errorMessage: String?

    private var client: OpenCodeClient?
    private var sessionId: String?
    private var directory: String?
    private var agent: String?

    func configure(client: OpenCodeClient?, sessionId: String?, directory: String?, agent: String?) {
        self.client = client
        self.sessionId = sessionId
        self.directory = directory
        self.agent = agent
    }

    func executeCommand() async {
        guard let client, let sessionId else { return }
        let trimmed = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        outputLines.append(TerminalLine(text: "$ \(trimmed)", type: .input))
        appendToHistory(trimmed)
        commandText = ""
        isRunning = true

        do {
            let effectiveAgent = agent ?? "build"
            let response = try await client.sendShellCommand(
                sessionId: sessionId,
                command: trimmed,
                agent: effectiveAgent,
                directory: directory
            )
            for part in response.parts.filter({ $0.isText }) {
                for line in part.displayText.components(separatedBy: "\n") where !line.isEmpty {
                    outputLines.append(TerminalLine(text: stripANSI(line), type: .output))
                }
            }
        } catch {
            logger.error("Failed to execute shell command '\(trimmed)': \(error.localizedDescription)")
            outputLines.append(TerminalLine(text: "Error: \(error.localizedDescription)", type: .error))
        }

        isRunning = false
    }

    func clearOutput() {
        outputLines = []
    }

    func navigateHistory(_ direction: ChatViewModel.HistoryDirection) -> String? {
        guard !commandHistory.isEmpty else { return nil }
        switch direction {
        case .up:
            if let idx = historyIndex {
                if idx + 1 < commandHistory.count {
                    historyIndex = idx + 1
                    return commandHistory[idx + 1]
                }
            } else {
                historyIndex = 0
                return commandHistory[0]
            }
        case .down:
            if let idx = historyIndex {
                if idx > 0 {
                    historyIndex = idx - 1
                    return commandHistory[idx - 1]
                } else {
                    historyIndex = nil
                    return ""
                }
            }
        }
        return nil
    }

    private func appendToHistory(_ text: String) {
        guard !text.isEmpty else { return }
        commandHistory.insert(text, at: 0)
        if commandHistory.count > 100 { commandHistory.removeLast() }
        historyIndex = nil
    }

    private func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: TerminalLineType
}

enum TerminalLineType {
    case input, output, error, system
}
