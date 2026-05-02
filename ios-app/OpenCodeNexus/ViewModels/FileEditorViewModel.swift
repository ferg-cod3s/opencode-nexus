import SwiftUI
import os

@MainActor
@Observable
final class FileEditorViewModel {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "FileEditorViewModel")
    private let client: OpenCodeClient
    private let directory: String?

    var content = ""
    var isLoading = true
    var isSaving = false
    var errorMessage: String?
    var hasChanges = false
    var isBinary = false
    var fileContent: FileContent?

    private let filePath: String
    private var originalContent: String = ""

    init(client: OpenCodeClient, filePath: String, directory: String?) {
        self.client = client
        self.filePath = filePath
        self.directory = directory
    }

    var displayName: String {
        filePath.split(separator: "/").last.map(String.init) ?? filePath
    }

    func loadContent() async {
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
            if content.count > 1_000_000 {
                content = String(content.prefix(500_000)) + "\n\n... (file truncated)"
            }
            originalContent = content
            hasChanges = false
        } catch {
            logger.error("Failed to load file: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func contentChanged(_ newContent: String) {
        content = newContent
        hasChanges = newContent != originalContent
    }

    func save() async {
        let txn = CrashReporter.transaction(name: "fileEditor.save", operation: "file")
        defer { txn?.finish() }
        guard hasChanges else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await client.writeFile(path: filePath, content: content, directory: directory)
            originalContent = content
            hasChanges = false
        } catch {
            logger.error("Failed to save file: \(error)")
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func revert() {
        content = originalContent
        hasChanges = false
    }
}
