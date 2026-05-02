import SwiftUI

struct SessionHierarchyRow: View {
    let session: Session
    let isSelected: Bool
    let childSessions: [Session]
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onSelect: () -> Void
    let onFork: () -> Void
    let onShare: () -> Void

    @State private var isExpanded = false
    @State private var showRenameSheet = false
    @State private var newName = ""
    @State private var isEditing = false
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if !childSessions.isEmpty {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 16)
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        if isEditing {
                            TextField("Session name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .onAppear { editingName = session.displayTitle }
                                .onSubmit { commitRename() }
                        } else {
                            Text(session.displayTitle)
                                .font(.body)
                                .lineLimit(1)
                                .onTapGesture(count: 2) {
                                    isEditing = true
                                }
                        }
                        if let summary = session.summary {
                            Text("+\(summary.additions)/-\(summary.deletions)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    sessionIndicators
                }
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        commitRename()
                    } else {
                        onSelect()
                    }
                }
            }
            .contextMenu {
                sessionContextMenuActions
            }

            if isExpanded && !childSessions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(childSessions) { child in
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.displayTitle)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let summary = child.summary {
                                    Text("+\(summary.additions)/-\(summary.deletions)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            childIndicators(for: child)
                        }
                        .padding(.vertical, 4)
                        .padding(.leading, 16)
                        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect()
                        }
                        .contextMenu {
                            childContextMenuActions(for: child)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSessionSheet(currentName: session.displayTitle, onSave: onRename)
        }
    }

    private func commitRename() {
        if !editingName.isEmpty && editingName != session.displayTitle {
            onRename(editingName)
        }
        isEditing = false
    }

    @ViewBuilder
    private var sessionIndicators: some View {
        HStack(spacing: 4) {
            if session.share != nil {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            if session.isArchived {
                Image(systemName: "archivebox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func childIndicators(for child: Session) -> some View {
        HStack(spacing: 4) {
            if child.share != nil {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var sessionContextMenuActions: some View {
        Button(action: onShare) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        if session.share != nil {
            Button {
                UIPasteboard.general.string = session.share?.url ?? ""
            } label: {
                Label("Copy Share Link", systemImage: "link")
            }
        }
        Button(action: onArchive) {
            Label(session.isArchived ? "Unarchive" : "Archive", systemImage: session.isArchived ? "archivebox.fill" : "archivebox")
        }
        Button(action: { showRenameSheet = true }) {
            Label("Rename", systemImage: "pencil")
        }
        Button(action: onFork) {
            Label("Fork Here", systemImage: "arrow.triangle.branch")
        }
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func childContextMenuActions(for child: Session) -> some View {
        Button(action: onFork) {
            Label("Fork Here", systemImage: "arrow.triangle.branch")
        }
    }
}

struct RenameSessionSheet: View {
    let currentName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(currentName: String, onSave: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Session name", text: $name)
            }
            .navigationTitle("Rename Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.isEmpty || name == currentName)
                }
            }
        }
    }
}
