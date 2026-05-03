import SwiftUI

struct MessageListView: View {
    let session: Session
    let messages: [MessageEnvelope]
    let isLoading: Bool
    let isSending: Bool
    let isSessionBusy: Bool
    @Binding var inputText: String
    @Binding var attachedParts: [MessagePartBody]
    let onSend: ([MessagePartBody]) -> Void
    let onAbort: () -> Void
    let onFork: (String) -> Void
    let onDelete: (String) -> Void
    let onRevert: (String, String?) -> Void
    let diffs: [FileDiff]
    let todos: [Todo]
    let hasPermission: Bool
    let hasQuestion: Bool
    let onShowPermissions: () -> Void
    let onShowDiffs: () -> Void
    let onShowQuestion: () -> Void
    let hasMoreMessages: Bool
    let onLoadMoreMessages: () -> Void
    let availableModels: [(providerID: String, modelID: String, name: String)]
    let availableAgents: [AgentInfo]
    let availableProviders: [ProviderInfo]
    let providerDefaults: [String: String]
    let availableCommands: [CommandInfo]
    @Binding var selectedModel: ModelRefBody?
    @Binding var selectedAgent: String?
    let onNavigateHistory: (ChatViewModel.HistoryDirection) -> Void
    let onShellCommand: (String) -> Void
    let queuedMessages: [String]
    let onQueueFollowUp: () -> Void
    let onSubmitQueuedPrompt: () -> Void
    let onClearQueuedPrompt: () -> Void
    let onRespondToTUIRequest: ([String: JSONValue]) -> Void
    let onRefresh: () async -> Void
    @State private var thinkingEffort: ThinkingEffort = .medium

    var body: some View {
        VStack(spacing: 0) {
            diffBanner
            permissionBanner
            questionBanner
            SessionProgressBar(isBusy: isSessionBusy)
            messageListPane
            followUpCard
            Divider()
            modelAgentBar
            MessageInputView(
                text: $inputText,
                attachedFileParts: $attachedParts,
                isSending: isSending,
                onSend: onSend,
                onAbort: onAbort,
                onShellCommand: onShellCommand,
                commands: availableCommands,
                agents: availableAgents,
                onNavigateHistory: onNavigateHistory
            )
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var followUpCard: some View {
        if isSending || !queuedMessages.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Follow-up Queue", systemImage: "text.badge.plus")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(queuedMessages.count) queued")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !queuedMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(queuedMessages.enumerated()), id: \.offset) { _, text in
                            Text(text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text("Queue your next prompt while this session is busy.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Queue Draft", action: onQueueFollowUp)
                        .buttonStyle(.borderedProminent)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Submit", action: onSubmitQueuedPrompt)
                        .buttonStyle(.bordered)
                        .disabled(queuedMessages.isEmpty)
                    Button("Clear", role: .destructive, action: onClearQueuedPrompt)
                        .buttonStyle(.bordered)
                        .disabled(queuedMessages.isEmpty)
                }
                .font(.caption)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var diffBanner: some View {
        if !diffs.isEmpty {
            Button {
                onShowDiffs()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                    Text("\(diffs.count) file change\(diffs.count == 1 ? "" : "s")")
                    Spacer()
                    let totalAdd = diffs.reduce(0) { $0 + $1.additions }
                    let totalDel = diffs.reduce(0) { $0 + $1.deletions }
                    Text("+\(totalAdd)/-\(totalDel)")
                        .font(.caption2)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var modelAgentBar: some View {
        if !availableModels.isEmpty || !availableAgents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !availableModels.isEmpty {
                        InlineModelPicker(
                            models: availableModels,
                            providers: availableProviders,
                            defaults: providerDefaults,
                            selection: $selectedModel
                        )
                    }
                    if !availableAgents.isEmpty {
                        InlineAgentPicker(
                            agents: availableAgents,
                            selection: $selectedAgent
                        )
                    }
                    ThinkingEffortSelector(selection: $thinkingEffort)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if hasPermission {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    onShowPermissions()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Permission required")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.1))
        }
    }

    @ViewBuilder
    private var questionBanner: some View {
        if hasQuestion {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    onShowQuestion()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Server is asking a question")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.1))
        }
    }

    private var messageListPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty && !isLoading {
                        emptyState
                    } else {
                        if hasMoreMessages {
                            Button {
                                onLoadMoreMessages()
                            } label: {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("Load Earlier Messages")
                                }
                            }
                            .buttonStyle(.glass)
                            .disabled(isLoading)
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .contextMenu {
                                    if message.info.isAssistant {
                                        Button {
                                            onFork(message.id)
                                        } label: {
                                            Label("Fork Here", systemImage: "arrow.branch")
                                        }
                                        Button {
                                            onRevert(message.id, nil)
                                        } label: {
                                            Label("Revert Changes", systemImage: "arrow.uturn.backward")
                                        }
                                    }
                                    Button {
                                        onDelete(message.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if isSending {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("typing")
                    }
                }
                .padding(.vertical, 16)
            }
            .refreshable {
                await onRefresh()
            }
            .overlay {
                if isLoading && messages.isEmpty {
                    ProgressView("Loading messages...")
                }
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isSending) {
                if isSending {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Send a message to start the conversation")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 60)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

private struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Thinking")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 5, height: 5)
                        .offset(y: animate ? -3 : 3)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .onAppear { animate = true }
    }
}
