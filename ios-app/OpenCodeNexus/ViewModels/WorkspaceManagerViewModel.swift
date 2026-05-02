import SwiftUI
import os

@MainActor
@Observable
final class WorkspaceManagerViewModel {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "WorkspaceManagerViewModel")
    private let client: OpenCodeClient

    var workspaces: [Workspace] = []
    var workspaceStatuses: [String: WorkspaceStatus] = [:]
    var adaptors: [WorkspaceAdaptor] = []
    var isLoading = false
    var isCreating = false
    var errorMessage: String?

    init(client: OpenCodeClient) {
        self.client = client
    }

    func loadWorkspaces() async {
        isLoading = true
        errorMessage = nil

        workspaces = (try? await client.listWorkspaces()) ?? []
        if workspaces.isEmpty {
            logger.warning("listWorkspaces returned empty or failed")
        }

        workspaceStatuses = (try? await client.getWorkspaceStatus()) ?? [:]

        adaptors = (try? await client.listWorkspaceAdaptors()) ?? []
        if adaptors.isEmpty {
            logger.warning("listWorkspaceAdaptors returned empty or failed")
        }

        isLoading = false
    }

    func createWorkspace(type: String, branch: String? = nil) async {
        isCreating = true
        errorMessage = nil
        do {
            let workspace = try await client.createWorkspace(type: type, branch: branch)
            workspaces.insert(workspace, at: 0)
        } catch {
            logger.error("Failed to create workspace: \(error)")
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    func removeWorkspace(_ workspace: Workspace) async {
        errorMessage = nil
        do {
            try await client.removeWorkspace(id: workspace.id)
            workspaces.removeAll { $0.id == workspace.id }
            workspaceStatuses.removeValue(forKey: workspace.id)
        } catch {
            logger.error("Failed to remove workspace: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func resetWorkspace(_ workspace: Workspace) async {
        errorMessage = nil
        do {
            try await client.resetWorkspace(id: workspace.id)
            if let idx = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[idx] = workspace
            }
        } catch {
            logger.error("Failed to reset workspace: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func statusForWorkspace(_ workspace: Workspace) -> WorkspaceStatus? {
        workspaceStatuses[workspace.id]
    }
}
