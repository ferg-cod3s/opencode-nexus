import SwiftUI

struct DiffSheet: View {
    let diffs: [FileDiff]
    let client: OpenCodeClient?
    let directory: String?
    let onOpenFile: ((String) -> Void)?
    let onAttachPath: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var diffLinesByFile: [String: [DiffLine]] = [:]
    @State private var isLoading = true

    init(diffs: [FileDiff], client: OpenCodeClient?, directory: String?, onOpenFile: ((String) -> Void)? = nil, onAttachPath: ((String) -> Void)? = nil) {
        self.diffs = diffs
        self.client = client
        self.directory = directory
        self.onOpenFile = onOpenFile
        self.onAttachPath = onAttachPath
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading diffs...")
                } else if diffs.isEmpty {
                    ContentUnavailableView("No Changes", systemImage: "checkmark.circle", description: Text("No file changes in this session"))
                } else {
                    List {
                        ForEach(diffs, id: \.file) { diff in
                            FileDiffView(diff: diff, diffLines: diffLinesByFile[diff.file] ?? [])
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .onTapGesture {
                                    onOpenFile?(diff.file)
                                }
                                .contextMenu {
                                    Button {
                                        onOpenFile?(diff.file)
                                    } label: {
                                        Label("View File", systemImage: "doc.text")
                                    }
                                    Button {
                                        UIPasteboard.general.string = diff.file
                                    } label: {
                                        Label("Copy Path", systemImage: "doc.on.doc")
                                    }
                                    if let onAttachPath {
                                        Button {
                                            onAttachPath(diff.file)
                                        } label: {
                                            Label("Attach to Prompt", systemImage: "paperclip")
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("File Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !diffs.isEmpty {
                        Button {
                            let allText = diffs.map { diff in
                                "\(diff.file) (+\(diff.additions)/-\(diff.deletions))"
                            }.joined(separator: "\n")
                            UIPasteboard.general.string = allText
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .task { await loadDiffContent() }
    }

    private func loadDiffContent() async {
        guard let client else {
            isLoading = false
            return
        }

        var results: [String: [DiffLine]] = [:]
        await withTaskGroup(of: (String, [DiffLine]).self) { group in
            for diff in diffs {
                group.addTask {
                    do {
                        let content = try await client.getFileContent(path: diff.file, directory: directory)
                        if let patch = content.patch, let hunks = patch.hunks {
                            let lines = DiffParser.parseHunks(hunks)
                            return (diff.file, lines)
                        } else if let diffText = content.diff {
                            let lines = DiffParser.parse(diffText)
                            return (diff.file, lines)
                        }
                    } catch { }
                    return (diff.file, [])
                }
            }
            for await (file, lines) in group {
                results[file] = lines
            }
        }

        diffLinesByFile = results
        isLoading = false
    }
}
