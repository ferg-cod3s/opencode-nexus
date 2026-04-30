import SwiftUI
import os

@MainActor
@Observable
final class FileBrowserViewModel {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "FileBrowserViewModel")

    var files: [FileNode] = []
    var fileStatuses: [FileStatus] = []
    var searchResults: [SearchResult] = []
    var matchedFiles: [String] = []
    var isLoading = false
    var isSearching = false
    var errorMessage: String?
    var searchText = ""
    var currentPath: String?
    var navigationStack: [FileNode] = []

    private let client: OpenCodeClient
    private let directory: String?
    private var searchTask: Task<Void, Never>?

    var displayFiles: [FileNode] {
        if searchText.isEmpty {
            return sortedFiles
        }
        if !matchedFiles.isEmpty {
            return sortedFiles.filter { matchedFiles.contains($0.path) || matchedFiles.contains($0.absolute) }
        }
        return sortedFiles
    }

    private var sortedFiles: [FileNode] {
        files.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var statusMap: [String: FileStatus] {
        Dictionary(uniqueKeysWithValues: fileStatuses.compactMap { status in
            (status.path, status)
        })
    }

    init(client: OpenCodeClient, directory: String?) {
        self.client = client
        self.directory = directory
    }

    func loadFiles(path: String? = nil) async {
        isLoading = true
        errorMessage = nil
        currentPath = path
        do {
            files = try await client.listFiles(path: path)
            fileStatuses = try await client.getFileStatus()
        } catch {
            logger.error("Failed to load files: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func navigateInto(_ node: FileNode) async {
        guard node.isDirectory else { return }
        navigationStack.append(node)
        await loadFiles(path: node.path)
    }

    func navigateBack() async {
        guard !navigationStack.isEmpty else {
            await loadFiles(path: nil)
            return
        }
        navigationStack.removeLast()
        let parent = navigationStack.last
        await loadFiles(path: parent?.path)
    }

    func search() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            matchedFiles = []
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        let results = try await self.client.findFiles(query: query)
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self.matchedFiles = results }
                    } catch {
                        self.logger.warning("File name search failed: \(error)")
                    }
                }
                group.addTask {
                    do {
                        let results = try await self.client.findText(pattern: query)
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self.searchResults = results }
                    } catch {
                        self.logger.warning("Text search failed: \(error)")
                    }
                }
            }
            isSearching = false
        }
    }
}
