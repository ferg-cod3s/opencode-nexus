import SwiftUI
import os

struct FileViewerView: View {
    let client: OpenCodeClient
    let filePath: String
    let directory: String?
    let onAttachFile: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var content: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBinary = false
    @State private var fileContent: FileContent?

    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "FileViewerView")

    private var displayName: String {
        filePath.split(separator: "/").last.map(String.init) ?? filePath
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading file...")
                } else if let error = errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if isBinary {
                    ContentUnavailableView("Binary File", systemImage: "doc.badge.ellipsis", description: Text("This file cannot be displayed as text"))
                } else if let content {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(content)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = filePath
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    if let content {
                        Button {
                            UIPasteboard.general.string = content
                        } label: {
                            Image(systemName: "doc.text")
                        }
                    }
                    Button {
                        onAttachFile(filePath, content)
                    } label: {
                        Image(systemName: "paperclip")
                    }
                }
            }
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await client.getFileContent(path: filePath, directory: directory)
            fileContent = result
            if result.type == "binary" {
                isBinary = true
                isLoading = false
                return
            }
            content = result.content
            if let rawContent = content, rawContent.count > 1_000_000 {
                content = String(rawContent.prefix(500_000)) + "\n\n... (file truncated)"
            }
        } catch {
            logger.error("Failed to load file: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
