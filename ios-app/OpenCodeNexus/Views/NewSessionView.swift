import SwiftUI
import os

struct NewSessionView: View {
    let chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var projects: [Project] = []
    @State private var isLoadingProjects = false
    @State private var loadError: String?
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "NewSession")

    private var workspaceOptions: [(name: String, path: String)] {
        if !projects.isEmpty {
            var seen = Set<String>()
            return projects.flatMap { project in
                ([(name: project.displayPath, path: project.worktree)] + (project.sandboxes ?? []).map { sandbox in
                    let name = sandbox.split(separator: "/").last.map(String.init) ?? sandbox
                    return (name: name, path: sandbox)
                }).filter { seen.insert($0.path).inserted }
            }
        }
        return chatVM.availableDirectories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Title")
                            .font(.caption)
                            .foregroundStyle(Theme.textBase)
                            .textCase(.uppercase)

                        TextField("My coding session", text: Bindable(chatVM).newSessionTitle)
                            .font(.body)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 8))
                            .overlay { Theme.borderOverlay(radius: 8) }
                            .focused($isTitleFocused)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workspace")
                            .font(.caption)
                            .foregroundStyle(Theme.textBase)
                            .textCase(.uppercase)

                        if isLoadingProjects {
                            HStack {
                                ProgressView()
                                Text("Loading...")
                                    .font(.body)
                                    .foregroundStyle(Theme.textBase)
                            }
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 8))
                            .overlay { Theme.borderOverlay(radius: 8) }
                        } else if workspaceOptions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No workspaces loaded from server")
                                    .font(.body)
                                    .foregroundStyle(Theme.textWeak)

                                if let error = loadError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(Theme.errorCritical.opacity(0.7))
                                }

                                Button {
                                    Task { await loadProjects() }
                                } label: {
                                    Label("Retry", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 8))
                            .overlay { Theme.borderOverlay(radius: 8) }
                        } else {
                            Picker("Workspace", selection: Bindable(chatVM).selectedDirectory) {
                                ForEach(workspaceOptions, id: \.path) { dir in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                        Text(dir.name)
                                    }
                                    .tag(dir.path as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .rect(cornerRadius: 8))
                            .overlay { Theme.borderOverlay(radius: 8) }
                        }
                    }

                    if !chatVM.availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model (optional)")
                                .font(.caption)
                                .foregroundStyle(Theme.textBase)
                                .textCase(.uppercase)

                            ModelPicker(
                            models: chatVM.availableModels,
                            providers: chatVM.availableProviders,
                            defaults: chatVM.providerDefaults,
                            selection: Bindable(chatVM).selectedModel
                        )
                        }
                    }

                    if !chatVM.availableAgents.filter({ $0.builtIn != true }).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Agent (optional)")
                                .font(.caption)
                                .foregroundStyle(Theme.textBase)
                                .textCase(.uppercase)

                            AgentPicker(agents: chatVM.availableAgents, selection: Bindable(chatVM).selectedAgent)
                        }
                    }

                    Button {
                        Task {
                            await chatVM.createSession()
                            dismiss()
                        }
                    } label: {
                        Text("Create Session")
                            .font(.headline)
                            .foregroundStyle(Theme.buttonPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.buttonPrimaryBG)
                            }
                    }
                    .disabled(!canCreate)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isTitleFocused = true
            Task { await loadProjects() }
        }
    }

    private var canCreate: Bool {
        guard !chatVM.newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let selectedDirectory = chatVM.selectedDirectory else { return false }
        return workspaceOptions.contains { $0.path == selectedDirectory }
    }

    private func loadProjects() async {
        guard let client = chatVM.client else {
            loadError = "Not connected to server"
            return
        }
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        loadError = nil
        do {
            projects = try await client.listProjects()
            logger.info("Loaded \(self.projects.count) projects")
            let options = workspaceOptions
            if let selectedDirectory = chatVM.selectedDirectory,
               options.contains(where: { $0.path == selectedDirectory }) {
                return
            }
            if let first = options.first {
                chatVM.selectedDirectory = first.path
            }
        } catch {
            logger.error("Failed to load projects: \(error)")
            loadError = error.localizedDescription
            projects = []
        }
    }
}
