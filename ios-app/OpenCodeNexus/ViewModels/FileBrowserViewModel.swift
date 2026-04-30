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
    private var didCompleteFileSearch = false

    private let client: OpenCodeClient
    private let directory: String?
    private var searchTask: Task<Void, Never>?

    var displayFiles: [FileNode] {
        if searchText.isEmpty {
            return sortedFiles
        }
        if !matchedFiles.isEmpty {
            let visibleMatches = sortedFiles.filter { matchedFiles.contains($0.path) || matchedFiles.contains($0.absolute) }
            let visiblePaths = Set(visibleMatches.flatMap { [$0.path, $0.absolute] })
            let missingMatches = matchedFiles.filter { !visiblePaths.contains($0) }
            return visibleMatches + missingMatches.map(syntheticFileNode(for:))
        }
        if didCompleteFileSearch {
            return []
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

    private func syntheticFileNode(for matchedPath: String) -> FileNode {
        let name = matchedPath.split(separator: "/").last.map(String.init) ?? matchedPath
        let absolute: String
        if matchedPath.hasPrefix("/") {
            absolute = matchedPath
        } else if let directory {
            let base = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
            absolute = "\(base)/\(matchedPath)"
        } else {
            absolute = matchedPath
        }
        return FileNode(name: name, path: matchedPath, absolute: absolute, type: "file", ignored: false)
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
            files = try await client.listFiles(path: path, directory: directory)
            fileStatuses = try await client.getFileStatus(directory: directory)
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
            didCompleteFileSearch = false
            isSearching = false
            return
        }
        let client = client
        let directory = directory
        let logger = logger
        didCompleteFileSearch = false
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                let results = try await client.findFiles(query: query, directory: directory)
                guard !Task.isCancelled else { return }
                matchedFiles = results
                didCompleteFileSearch = true
            } catch {
                logger.warning("File name search failed: \(error)")
            }
            do {
                let results = try await client.findText(pattern: query, directory: directory)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                logger.warning("Text search failed: \(error)")
            }
        }
    }
}
