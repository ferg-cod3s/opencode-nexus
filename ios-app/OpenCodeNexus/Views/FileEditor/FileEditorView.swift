import SwiftUI
import os

struct FileEditorView: View {
    @State private var viewModel: FileEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveConfirmation = false

    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "FileEditorView")

    init(client: OpenCodeClient, filePath: String, directory: String?) {
        _viewModel = State(initialValue: FileEditorViewModel(client: client, filePath: filePath, directory: directory))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading file...")
                } else if viewModel.isBinary {
                    ContentUnavailableView("Binary File", systemImage: "doc.badge.ellipsis", description: Text("This file cannot be edited"))
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    editorContent
                }
            }
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.hasChanges {
                        Button {
                            viewModel.revert()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                    Button {
                        Task { await viewModel.save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                    Button {
                        UIPasteboard.general.string = viewModel.content
                        showSaveConfirmation = true
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            .alert("File Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Changes have been saved successfully")
            }
        }
        .task { await viewModel.loadContent() }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            if viewModel.hasChanges {
                HStack {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.orange)
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            TextEditor(text: Binding(
                get: { viewModel.content },
                set: { viewModel.contentChanged($0) }
            ))
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
        }
    }
}
