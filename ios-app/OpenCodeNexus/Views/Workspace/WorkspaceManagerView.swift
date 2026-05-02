import SwiftUI

struct WorkspaceManagerView: View {
    @State private var viewModel: WorkspaceManagerViewModel
    @State private var showCreateSheet = false
    @Environment(\.dismiss) private var dismiss

    init(client: OpenCodeClient) {
        _viewModel = State(initialValue: WorkspaceManagerViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.workspaces.isEmpty {
                    ProgressView("Loading workspaces...")
                } else if viewModel.workspaces.isEmpty {
                    ContentUnavailableView("No Workspaces", systemImage: "folder.badge.gearshape", description: Text("Create a workspace to get started"))
                } else {
                    workspaceList
                }
            }
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                WorkspaceCreateSheet(viewModel: viewModel)
            }
        }
        .task { await viewModel.loadWorkspaces() }
    }

    private var workspaceList: some View {
        List {
            ForEach(viewModel.workspaces) { workspace in
                WorkspaceRow(workspace: workspace, status: viewModel.statusForWorkspace(workspace), viewModel: viewModel)
            }
        }
        .listStyle(.plain)
    }
}

private struct WorkspaceRow: View {
    let workspace: Workspace
    let status: WorkspaceStatus?
    let viewModel: WorkspaceManagerViewModel
    @State private var showRemoveConfirmation = false
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                workspaceStatusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.displayName)
                        .font(.body.weight(.medium))
                    Text(workspace.displayBranch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                workspaceActions
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Remove Workspace", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeWorkspace(workspace) }
            }
        } message: {
            Text("This will remove the workspace and its worktree. This action cannot be undone.")
        }
        .confirmationDialog("Reset Workspace", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                Task { await viewModel.resetWorkspace(workspace) }
            }
        } message: {
            Text("This will reset the workspace to the default branch. All uncommitted changes will be lost.")
        }
    }

    @ViewBuilder
    private var workspaceStatusIcon: some View {
        if workspace.isConnected || status?.isConnected == true {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if workspace.isConnecting || status?.isConnecting == true {
            ProgressView()
                .scaleEffect(0.8)
        } else if workspace.hasError || status?.hasError == true {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private var workspaceActions: some View {
        Menu {
            Button {
                showResetConfirmation = true
            } label: {
                Label("Reset", systemImage: "arrow.clockwise")
            }
            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
    }
}

struct WorkspaceCreateSheet: View {
    let viewModel: WorkspaceManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAdaptor = ""
    @State private var branchName = ""
    @State private var autoGenerateBranch = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Adaptor") {
                    Picker("Type", selection: $selectedAdaptor) {
                        Text("Select adaptor").tag("")
                        ForEach(viewModel.adaptors) { adaptor in
                            Text(adaptor.name).tag(adaptor.id)
                        }
                    }
                }

                Section("Branch") {
                    Toggle("Auto-generate branch name", isOn: $autoGenerateBranch)
                    if !autoGenerateBranch {
                        TextField("Branch name", text: $branchName)
                    }
                }

                if viewModel.isCreating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Creating workspace...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let branch = autoGenerateBranch ? nil : branchName
                            await viewModel.createWorkspace(type: selectedAdaptor, branch: branch)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedAdaptor.isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}
