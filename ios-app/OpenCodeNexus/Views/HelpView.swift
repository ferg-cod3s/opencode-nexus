import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Built-In Commands") {
                    helpRow("/new, /clear", description: "Start a new session")
                    helpRow("/share", description: "Share current session and copy link")
                    helpRow("/sessions, /resume, /continue", description: "List or switch sessions")
                    helpRow("/models", description: "List or select AI models")
                    helpRow("/export", description: "Export conversation as Markdown")
                    helpRow("/help", description: "Show this help dialog")
                    helpRow("/themes", description: "List and select themes")
                    helpRow("/connect", description: "Configure AI providers")
                }
                Section("Not Available on iOS") {
                    helpRow("/editor", description: "External editor (not available on iOS)")
                    helpRow("/exit, /quit, /q", description: "Exit app (not available on iOS)")
                }
                Section("Server-Side Commands") {
                    Text("These commands are sent to the OpenCode server:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    helpRow("/compact, /summarize", description: "Compact session history")
                    helpRow("/init", description: "Create or update AGENTS.md")
                    helpRow("/details", description: "Toggle tool execution details")
                    helpRow("/thinking", description: "Toggle thinking block visibility")
                    helpRow("/undo", description: "Undo last message (requires Git)")
                    helpRow("/redo", description: "Redo undone message (requires Git)")
                    helpRow("/unshare", description: "Remove share link from session")
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpRow(_ command: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.interactiveBlue)
                .frame(width: 180, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundStyle(Theme.textBase)
        }
        .padding(.vertical, 2)
    }
}
