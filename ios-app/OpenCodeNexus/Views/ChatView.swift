import SwiftUI
import os

struct ChatView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @State private var chatVM = ChatViewModel()
    @State private var showNewSession = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var collapsedDirectories: Set<String> = []
    @State private var showPermissionSheet = false
    @State private var showQuestionSheet = false
    @State private var showDiffView = false
    @State private var showTerminal = false
    @State private var showFileBrowser = false
    @State private var showFileViewer = false
    @State private var viewingFilePath: String?
    @State private var presentedQuestionIDs: Set<String> = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailPane
        }
        .task {
            let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "ChatView")
            logger.info("task: configuring client...")
            chatVM.configure(with: connectionManager.client)
            logger.info("task: loading project info...")
            await chatVM.loadProjectInfo()
            logger.info("task: loading sessions...")
            await chatVM.loadSessions()
            logger.info("task: sessions loaded (\(chatVM.sessions.count) sessions)")
            Task { await chatVM.loadServerInfo() }
            logger.info("task: starting event stream")
            chatVM.startEventStream()
        }
        .onChange(of: chatVM.selectedSessionId) {
            if let id = chatVM.selectedSessionId {
                Task { await chatVM.selectSession(id) }
                if chatVM.pendingPermissions.contains(where: { $0.sessionID == id }) {
                    showPermissionSheet = true
                }
            }
        }
        .onChange(of: chatVM.pendingPermissions.count) {
            if let id = chatVM.selectedSessionId,
               chatVM.pendingPermissions.contains(where: { $0.sessionID == id }) {
                showPermissionSheet = true
            }
        }
        .onChange(of: chatVM.pendingQuestions.count) {
            guard let newQuestion = chatVM.selectedPendingQuestions.first(where: { !presentedQuestionIDs.contains($0.id) }) else { return }
            presentedQuestionIDs.insert(newQuestion.id)
            showQuestionSheet = true
        }
        .onDisappear {
            chatVM.stopEventStream()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { chatVM.errorMessage != nil },
                set: { if !$0 { chatVM.errorMessage = nil } }
            ),
            actions: {
                Button("OK") { chatVM.errorMessage = nil }
            },
            message: {
                Text(chatVM.errorMessage ?? "")
            }
        )
        .sheet(isPresented: $showNewSession) {
            NewSessionView(chatVM: chatVM)
        }
        .sheet(isPresented: $showPermissionSheet) {
            PermissionSheet(chatVM: chatVM)
        }
        .sheet(isPresented: $showQuestionSheet) {
            QuestionSheet(
                questions: chatVM.selectedPendingQuestions,
                onAnswer: { question, answers in
                    Task { await chatVM.answerQuestion(question, answers: answers) }
                },
                onReject: { question in
                    Task { await chatVM.rejectQuestion(question) }
                }
            )
        }
        .sheet(isPresented: $showDiffView) {
            DiffSheet(
                diffs: chatVM.fileDiffs,
                client: chatVM.client,
                directory: chatVM.directory(for: chatVM.selectedSessionId),
                onOpenFile: { path in
                    showDiffView = false
                    viewingFilePath = path
                    showFileViewer = true
                },
                onAttachPath: { path in
                    chatVM.attachedParts.append(MessagePartBody(type: "text", text: path))
                    showDiffView = false
                }
            )
        }
        .sheet(isPresented: $showTerminal) {
            TerminalView(
                client: chatVM.client,
                sessionId: chatVM.selectedSessionId,
                directory: chatVM.directory(for: chatVM.selectedSessionId),
                agent: chatVM.selectedAgent ?? "coder"
            )
        }
        .sheet(isPresented: $showFileBrowser) {
            if let client = chatVM.client {
                FileBrowserView(
                    client: client,
                    directory: chatVM.directory(for: chatVM.selectedSessionId),
                    onOpenFile: { path in
                        showFileBrowser = false
                        viewingFilePath = path
                        showFileViewer = true
                    },
                    onAttachFile: { path, _ in
                        chatVM.attachedParts.append(MessagePartBody(type: "text", text: path))
                        showFileBrowser = false
                    }
                )
            }
        }
        .sheet(isPresented: $showFileViewer) {
            if let client = chatVM.client, let path = viewingFilePath {
                FileViewerView(
                    client: client,
                    filePath: path,
                    directory: chatVM.directory(for: chatVM.selectedSessionId),
                    onAttachFile: { _, content in
                        if let content {
                            chatVM.attachedParts.append(MessagePartBody(type: "text", text: "Content of \(path):\n\(content.prefix(2000))"))
                        } else {
                            chatVM.attachedParts.append(MessagePartBody(type: "text", text: path))
                        }
                        showFileViewer = false
                    }
                )
            }
        }
    }

    private var sidebar: some View {
        Group {
            if chatVM.sessions.isEmpty && !chatVM.isLoadingSessions {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "tray",
                    description: Text("Create a new session to start coding")
                )
            } else {
                List(selection: Bindable(chatVM).selectedSessionId) {
                    if let branch = chatVM.vcsBranch, !branch.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "branch")
                                .font(.caption2)
                            Text(branch)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                    }

                    ForEach(chatVM.sessionGroups, id: \.directory) { group in
                        Section {
                            if !collapsedDirectories.contains(group.directory) {
                                ForEach(group.sessions) { session in
                                    SessionRow(
                                        session: session,
                                        status: chatVM.sessionStatuses[session.id],
                                        hasPermission: chatVM.pendingPermissions.contains { $0.sessionID == session.id },
                                        hasQuestion: chatVM.pendingQuestions.contains { $0.sessionID == session.id }
                                    )
                                        .tag(session.id)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Task { await chatVM.deleteSession(session.id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                Task { await chatVM.shareSession(session.id) }
                                            } label: {
                                                Label("Share", systemImage: "square.and.arrow.up")
                                            }
                                            if session.share != nil {
                                                Button {
                                                    UIPasteboard.general.string = session.share?.url ?? ""
                                                } label: {
                                                    Label("Copy Share Link", systemImage: "link")
                                                }
                                            }
                                        }
                                }
                            }
                        } header: {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if collapsedDirectories.contains(group.directory) {
                                        collapsedDirectories.remove(group.directory)
                                    } else {
                                        collapsedDirectories.insert(group.directory)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: collapsedDirectories.contains(group.directory) ? "chevron.right" : "chevron.down")
                                        .font(.caption2.weight(.bold))
                                        .frame(width: 10)
                                    Image(systemName: "folder.fill")
                                        .font(.caption2)
                                    Text(group.name)
                                        .font(.caption.weight(.semibold))
                                    Text("\(group.sessions.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if chatVM.hasMoreSessions {
                        Button {
                            Task { await chatVM.loadMoreSessions() }
                        } label: {
                            HStack {
                                Spacer()
                                if chatVM.isLoadingSessions {
                                    ProgressView()
                                } else {
                                    Text("Load More Sessions")
                                }
                                Spacer()
                            }
                        }
                        .disabled(chatVM.isLoadingSessions)
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: Bindable(chatVM).sessionSearchText, prompt: "Search sessions")
                .overlay {
                    if chatVM.isLoadingSessions && chatVM.sessions.isEmpty {
                        ProgressView("Loading sessions...")
                    }
                }
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        connectionManager.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "arrow.uturn.backward")
                    }
                    Button {
                        connectionManager.disconnect()
                    } label: {
                        Label("Switch Server", systemImage: "server.rack")
                    }
                } label: {
                    Image(systemName: "server.rack")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    chatVM.prepareNewSession()
                    showNewSession = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .refreshable {
            await chatVM.loadSessions()
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let session = chatVM.selectedSession {
            MessageListView(
                session: session,
                messages: chatVM.messages,
                isLoading: chatVM.isLoadingMessages,
                isSending: chatVM.isSending,
                inputText: Bindable(chatVM).inputText,
                attachedParts: Bindable(chatVM).attachedParts,
                onSend: { parts in Task { await chatVM.sendMessage(attachedParts: parts) } },
                onAbort: { Task { await chatVM.abortSession() } },
                onFork: { messageId in
                    Task { await chatVM.forkSession(at: messageId) }
                },
                onDelete: { messageId in
                    Task { await chatVM.deleteMessage(messageId) }
                },
                onRevert: { messageId, partId in
                    Task { await chatVM.revertMessage(messageId, partID: partId) }
                },
                diffs: chatVM.fileDiffs,
                todos: chatVM.todos,
                hasPermission: chatVM.pendingPermissions.contains { $0.sessionID == session.id },
                hasQuestion: !chatVM.selectedPendingQuestions.isEmpty,
                onShowPermissions: { showPermissionSheet = true },
                onShowDiffs: { showDiffView = true },
                onShowQuestion: { showQuestionSheet = true },
                hasMoreMessages: chatVM.hasMoreMessages,
                onLoadMoreMessages: { Task { await chatVM.loadMoreMessages() } },
                availableModels: chatVM.availableModels,
                availableAgents: chatVM.availableAgents,
                availableProviders: chatVM.availableProviders,
                providerDefaults: chatVM.providerDefaults,
                availableCommands: chatVM.availableCommands,
                selectedModel: Bindable(chatVM).selectedModel,
                selectedAgent: Bindable(chatVM).selectedAgent,
                onNavigateHistory: { chatVM.navigateHistory($0) },
                onShellCommand: { command in Task { await chatVM.sendShellCommand(command) } },
                nextTUIRequest: chatVM.nextTUIRequest,
                onQueueFollowUp: { Task { await chatVM.queueFollowUpPrompt() } },
                onSubmitQueuedPrompt: { Task { await chatVM.submitQueuedPrompt() } },
                onClearQueuedPrompt: { Task { await chatVM.clearQueuedPrompt() } },
                onRespondToTUIRequest: { body in Task { await chatVM.respondToTUIRequest(body) } }
            )
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        showFileBrowser = true
                    } label: {
                        Image(systemName: "folder")
                    }

                    Button {
                        showTerminal = true
                    } label: {
                        Image(systemName: "terminal")
                    }

                    if !chatVM.fileDiffs.isEmpty {
                        Button {
                            showDiffView = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.badge.gearshape")
                                Text("\(chatVM.fileDiffs.count)")
                            }
                        }
                    }
                    if !chatVM.selectedPendingPermissions.isEmpty {
                        Button {
                            showPermissionSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield")
                                Text("\(chatVM.selectedPendingPermissions.count)")
                            }
                        }
                        .tint(Theme.brandYuzu)
                    }
                    if !chatVM.selectedPendingQuestions.isEmpty {
                        Button {
                            showQuestionSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text("\(chatVM.selectedPendingQuestions.count)")
                            }
                        }
                        .tint(Theme.interactiveBlue)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "Select a Session",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Choose a session from the sidebar to view messages")
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EmptyView()
                }
            }
        }
    }
}
