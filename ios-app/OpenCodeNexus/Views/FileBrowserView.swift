import SwiftUI

struct FileBrowserView: View {
    let client: OpenCodeClient
    let directory: String?
    let onOpenFile: (String) -> Void
    let onAttachFile: (String, String?) -> Void

    @State private var vm: FileBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSearch = false

    init(client: OpenCodeClient, directory: String?, onOpenFile: @escaping (String) -> Void, onAttachFile: @escaping (String, String?) -> Void) {
        self.client = client
        self.directory = directory
        self.onOpenFile = onOpenFile
        self.onAttachFile = onAttachFile
        _vm = State(wrappedValue: FileBrowserViewModel(client: client, directory: directory))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.files.isEmpty {
                    ProgressView("Loading files...")
                } else if vm.files.isEmpty {
                    ContentUnavailableView("Empty Directory", systemImage: "folder", description: Text("No files found at this path"))
                } else {
                    fileList
                }
            }
            .navigationTitle(vm.currentPath.map { path in
                let parts = path.split(separator: "/")
                return parts.last.map(String.init) ?? path
            } ?? "Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSearch.toggle()
                        if !showSearch {
                            vm.searchText = ""
                            vm.matchedFiles = []
                            vm.searchResults = []
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                    }
                }
                if vm.navigationStack.count > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await vm.navigateBack() }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
            .searchable(text: $vm.searchText, isPresented: $showSearch, prompt: "Search files and text")
            .onChange(of: vm.searchText) {
                vm.search()
            }
        }
        .task {
            await vm.loadFiles()
        }
    }

    private var fileList: some View {
        List {
            if !vm.searchResults.isEmpty {
                Section("Text Results") {
                    ForEach(vm.searchResults.enumerated().map { $0 }, id: \.offset) { index, result in
                        Button {
                            if let path = result.path {
                                onOpenFile(path)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.path?.split(separator: "/").last.map(String.init) ?? "Unknown")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if let line = result.line {
                                        Text("Line \(line)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let text = result.text {
                                        Text(text.prefix(120))
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section(vm.searchText.isEmpty ? "Files" : "Matched Files") {
                ForEach(vm.displayFiles) { node in
                    Button {
                        if node.isDirectory {
                            Task { await vm.navigateInto(node) }
                        } else {
                            onOpenFile(node.path)
                        }
                    } label: {
                        FileRow(node: node, status: vm.statusMap[node.path])
                    }
                    .contextMenu {
                        if !node.isDirectory {
                            Button {
                                onAttachFile(node.path, nil)
                            } label: {
                                Label("Attach to Prompt", systemImage: "paperclip")
                            }
                            Button {
                                UIPasteboard.general.string = node.path
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }

            if vm.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if let error = vm.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            }
        }
    }
}

private struct FileRow: View {
    let node: FileNode
    let status: FileStatus?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder.fill" : iconName)
                .foregroundStyle(node.isDirectory ? Theme.brandYuzu : .secondary)
                .font(.body)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.body)
                    .foregroundStyle(Theme.textStrong)
                    .lineLimit(1)
                if node.ignored {
                    Text("Ignored")
                        .font(.caption2)
                        .foregroundStyle(Theme.textWeak)
                }
            }

            Spacer()

            if let status {
                HStack(spacing: 4) {
                    if status.added > 0 {
                        Text("+\(status.added)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.success)
                    }
                    if status.removed > 0 {
                        Text("-\(status.removed)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.errorCritical)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.name)\(node.isDirectory ? ", directory" : ", file")")
    }

    private var iconName: String {
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "json": return "doc.text"
        case "js", "ts", "tsx", "jsx": return "doc.text"
        case "md", "txt": return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "yml", "yaml", "toml": return "gearshape"
        default: return "doc"
        }
    }
}
