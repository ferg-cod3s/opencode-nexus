import SwiftUI

struct ChatView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @State private var chatVM = ChatViewModel()
    @State private var showNewSession = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailPane
        }
        .task {
            chatVM.configure(with: connectionManager.client)
            await chatVM.loadSessions()
            chatVM.startEventStream()
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
                    ForEach(chatVM.sessions) { session in
                        SessionRow(session: session)
                            .tag(session.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await chatVM.deleteSession(session.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
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
                Button {
                    connectionManager.disconnect()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
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
                onSend: { Task { await chatVM.sendMessage() } }
            )
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
