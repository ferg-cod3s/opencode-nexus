import SwiftUI

@Observable
final class ChatViewModel {
    var sessions: [Session] = []
    var selectedSessionId: String?
    var messages: [Message] = []
    var isLoadingSessions = false
    var isLoadingMessages = false
    var isSending = false
    var errorMessage: String?
    var newSessionTitle = ""
    var inputText = ""

    private var client: OpenCodeClient?
    private var eventTask: Task<Void, Never>?

    var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionId }
    }

    func configure(with client: OpenCodeClient?) {
        self.client = client
    }

    func loadSessions() async {
        guard let client else { return }
        isLoadingSessions = true
        errorMessage = nil
        do {
            sessions = try await client.listSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingSessions = false
    }

    func selectSession(_ sessionId: String) async {
        guard selectedSessionId != sessionId else { return }
        selectedSessionId = sessionId
        messages = []
        await loadMessages()
    }

    func loadMessages() async {
        guard let client, let sessionId = selectedSessionId else { return }
        isLoadingMessages = true
        do {
            messages = try await client.getMessages(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMessages = false
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, let sessionId = selectedSessionId, !text.isEmpty else { return }
        inputText = ""
        isSending = true
        do {
            let _ = try await client.sendMessage(sessionId: sessionId, text: text)
            try? await Task.sleep(for: .milliseconds(300))
            await loadMessages()
        } catch {
            errorMessage = error.localizedDescription
            inputText = text
        }
        isSending = false
    }

    func createSession() async {
        guard let client else { return }
        let title = newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        newSessionTitle = ""
        do {
            let session = try await client.createSession(title: title)
            sessions.insert(session, at: 0)
            selectedSessionId = session.id
            messages = []
            await loadMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(_ sessionId: String) async {
        guard let client else { return }
        do {
            let success = try await client.deleteSession(id: sessionId)
            if success {
                withAnimation {
                    sessions.removeAll { $0.id == sessionId }
                }
                if selectedSessionId == sessionId {
                    selectedSessionId = nil
                    messages = []
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startEventStream() {
        guard let client else { return }
        eventTask?.cancel()
        eventTask = Task {
            do {
                for try await event in client.eventStream() {
                    guard !Task.isCancelled else { return }
                    await Self.handleEvent(event, viewModel: self)
                }
            } catch {
                errorMessage = "Event stream disconnected: \(error.localizedDescription)"
            }
        }
    }

    func stopEventStream() {
        eventTask?.cancel()
        eventTask = nil
    }

    private static func handleEvent(_ event: SSEEvent, viewModel: ChatViewModel?) async {
        guard let viewModel else { return }
        switch event.type {
        case "EventMessageUpdated":
            if viewModel.selectedSessionId != nil {
                await viewModel.loadMessages()
            }
        case "EventSessionUpdated", "EventSessionCreated", "EventSessionDeleted":
            await viewModel.loadSessions()
        default:
            break
        }
    }
}
