import SwiftUI

struct ServerListView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @State private var showAddServer = false
    @State private var editingServer: ServerConfig?
    @State private var showDeleteConfirmation: ServerConfig?

    var body: some View {
        NavigationStack {
            Group {
                if connectionManager.serverStore.servers.isEmpty {
                    emptyState
                } else {
                    serverList
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddServer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddServer) {
                ServerEditView(serverStore: connectionManager.serverStore)
            }
            .sheet(item: $editingServer) { server in
                ServerEditView(serverStore: connectionManager.serverStore, existingServer: server)
            }
            .alert(
                "Delete Server?",
                isPresented: Binding(
                    get: { showDeleteConfirmation != nil },
                    set: { if !$0 { showDeleteConfirmation = nil } }
                ),
                actions: {
                    Button("Cancel", role: .cancel) { showDeleteConfirmation = nil }
                    Button("Delete", role: .destructive) {
                        if let server = showDeleteConfirmation {
                            deleteServer(server)
                        }
                    }
                },
                message: {
                    Text("Remove \(showDeleteConfirmation?.displayLabel ?? "this server") from your server list?")
                }
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Servers",
            systemImage: "server.rack",
            description: Text("Add a server to connect to your OpenCode instance")
        )
    }

    private var serverList: some View {
        List {
            ForEach(connectionManager.serverStore.servers) { server in
                serverRow(server)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = server
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !server.isDefault {
                            Button {
                                connectionManager.serverStore.setDefault(id: server.id)
                            } label: {
                                Label("Default", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                    .contextMenu {
                        Button {
                            editingServer = server
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        if !server.isDefault {
                            Button {
                                connectionManager.serverStore.setDefault(id: server.id)
                            } label: {
                                Label("Set as Default", systemImage: "star")
                            }
                        }
                        if connectionManager.isConnected,
                           connectionManager.serverStore.activeServerId != server.id {
                            Button {
                                Task { await switchToServer(server) }
                            } label: {
                                Label("Connect", systemImage: "link")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = server
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func serverRow(_ server: ServerConfig) -> some View {
        Button {
            Task { await switchToServer(server) }
        } label: {
            HStack(spacing: 12) {
                healthIndicator(server)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(server.displayLabel)
                            .font(.body)
                            .lineLimit(1)
                        if server.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                    Text(server.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if connectionManager.serverStore.activeServerId == server.id && connectionManager.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func healthIndicator(_ server: ServerConfig) -> some View {
        Circle()
            .fill(healthColor(server))
            .frame(width: 10, height: 10)
    }

    private func healthColor(_ server: ServerConfig) -> Color {
        guard let healthy = server.isHealthy else { return .gray.opacity(0.5) }
        return healthy ? .green : .red
    }

    private func switchToServer(_ server: ServerConfig) async {
        if connectionManager.serverStore.activeServerId == server.id && connectionManager.isConnected {
            return
        }
        connectionManager.disconnect()
        await connectionManager.connect(to: server)
    }

    private func deleteServer(_ server: ServerConfig) {
        if connectionManager.serverStore.activeServerId == server.id {
            connectionManager.disconnect()
        }
        connectionManager.serverStore.removeServer(id: server.id)
    }
}
