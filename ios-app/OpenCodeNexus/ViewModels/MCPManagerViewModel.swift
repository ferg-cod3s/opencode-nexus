import Foundation
import SwiftUI

@MainActor
@Observable
class MCPManagerViewModel {
    var servers: [McpServerStatus] = []
    var isLoading = false
    var errorMessage: String?
    var showAddServer = false
    var newServerName = ""
    var newServerCommand = ""
    var newServerArgs = ""
    
    private var client: OpenCodeClient?
    
    func configure(with client: OpenCodeClient) {
        self.client = client
    }
    
    func loadServers() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            servers = try await client.listMcpServers()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addServer() async {
        guard let client, !newServerName.isEmpty, !newServerCommand.isEmpty else { return }
        
        do {
            let args = newServerArgs.split(separator: " ").map { String($0) }
            try await client.addMcpServer(name: newServerName, command: newServerCommand, args: args)
            newServerName = ""
            newServerCommand = ""
            newServerArgs = ""
            showAddServer = false
            await loadServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func connectServer(_ name: String) async {
        guard let client else { return }
        do {
            try await client.connectMcpServer(name: name)
            await loadServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func disconnectServer(_ name: String) async {
        guard let client else { return }
        do {
            try await client.disconnectMcpServer(name: name)
            await loadServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func removeServer(_ name: String) async {
        guard let client else { return }
        do {
            try await client.removeMcpServer(name: name)
            await loadServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MCPManagerView: View {
    @State private var viewModel: MCPManagerViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: MCPManagerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading MCP servers...")
                } else if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.errorCritical)
                } else if viewModel.servers.isEmpty {
                    ContentUnavailableView(
                        "No MCP Servers",
                        systemImage: "server.rack",
                        description: Text("Add MCP servers to extend functionality")
                    )
                } else {
                    ForEach(viewModel.servers) { server in
                        MCPServerRow(server: server, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("MCP Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddServer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddServer) {
                AddMCPServerView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadServers()
            }
        }
    }
}

struct MCPServerRow: View {
    let server: McpServerStatus
    let viewModel: MCPManagerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(server.isConnected ? Theme.success : server.hasError ? Theme.errorCritical : Theme.textWeak)
                    .frame(width: 8, height: 8)
                
                Text(server.name)
                    .font(.body.weight(.semibold))
                
                Spacer()
                
                if server.isConnected {
                    Button("Disconnect") {
                        Task { await viewModel.disconnectServer(server.name) }
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button("Connect") {
                        Task { await viewModel.connectServer(server.name) }
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if let error = server.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.errorCritical)
            }
            
            if let tools = server.tools, !tools.isEmpty {
                Text("\(tools.count) tools available")
                    .font(.caption)
                    .foregroundStyle(Theme.textWeak)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                Task { await viewModel.removeServer(server.name) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct AddMCPServerView: View {
    let viewModel: MCPManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var serverName = ""
    @State private var serverCommand = ""
    @State private var serverArgs = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Server Name", text: $serverName)
                    TextField("Command", text: $serverCommand)
                    TextField("Arguments (space-separated)", text: $serverArgs)
                }
            }
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { @MainActor in
                            viewModel.newServerName = serverName
                            viewModel.newServerCommand = serverCommand
                            viewModel.newServerArgs = serverArgs
                            await viewModel.addServer()
                            dismiss()
                        }
                    }
                    .disabled(serverName.isEmpty || serverCommand.isEmpty)
                }
            }
        }
    }
}
