import SwiftUI
import PhotosUI

struct MessageInputView: View {
    @Binding var text: String
    @Binding var attachedFileParts: [MessagePartBody]
    let isSending: Bool
    let onSend: ([MessagePartBody]) -> Void
    let onAbort: () -> Void
    let onShellCommand: (String) -> Void
    let commands: [CommandInfo]
    let agents: [AgentInfo]
    let onNavigateHistory: (ChatViewModel.HistoryDirection) -> Void

    @FocusState private var isFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShellMode = false

    private var placeholderText: String {
        isShellMode ? "Run a shell command..." : "Type a message..."
    }

    private var filteredCommands: [CommandInfo] {
        guard text.hasPrefix("/") else { return [] }
        let query = text.dropFirst().lowercased()
        let parts = query.split(separator: " ", maxSplits: 1)
        guard let first = parts.first else {
            return Array(commands.prefix(8))
        }
        let cmdPart = String(first)
        guard parts.count == 1 else { return [] }
        return Array(commands.filter { $0.name.lowercased().hasPrefix(cmdPart) && $0.name.lowercased() != cmdPart }.prefix(8))
    }

    private var filteredAgents: [AgentInfo] {
        guard let atRange = text.range(of: "@", options: .backwards) else { return [] }
        let afterAt = text[atRange.upperBound...]
        let query = afterAt.trimmingCharacters(in: .whitespaces)
        guard !query.contains(" ") else { return [] }
        return Array(agents.filter { $0.name.lowercased().hasPrefix(query.lowercased()) && $0.name.lowercased() != query.lowercased() }.prefix(8))
    }

    var body: some View {
        VStack(spacing: 0) {
            attachmentPreview
            autocompletePalette
            HStack(alignment: .bottom, spacing: 12) {
                VStack(spacing: 4) {
                    shellModeToggle
                    attachButton
                }
                inputField
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular)
            .overlay { Theme.borderOverlay(radius: 0) }
        }
    }

    private var shellModeToggle: some View {
        Button {
            isShellMode.toggle()
            if isShellMode && !text.hasPrefix("!") {
                text = "! " + text
            } else if !isShellMode && text.hasPrefix("!") {
                text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
        } label: {
            Image(systemName: isShellMode ? "terminal.fill" : "terminal")
                .font(.body)
                .foregroundStyle(isShellMode ? Theme.brandYuzu : Theme.textBase)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(isShellMode ? "Switch to normal mode" : "Switch to shell mode")
    }

    private var attachmentPreview: some View {
        Group {
            if !attachedFileParts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(attachedFileParts.enumerated()), id: \.offset) { index, part in
                            HStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.caption2)
                                Text(part.filename ?? part.text ?? part.mime ?? "file")
                                    .font(.caption)
                                    .lineLimit(1)
                                Button {
                                    attachedFileParts.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textBase)
                                }
                                .accessibilityLabel("Remove attachment")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular, in: .rect(cornerRadius: 6))
                            .overlay { Theme.borderOverlay(radius: 6) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var autocompletePalette: some View {
        Group {
            if !filteredCommands.isEmpty {
                autocompleteScrollView {
                    ForEach(filteredCommands) { cmd in
                        Button {
                            selectCommand(cmd)
                        } label: {
                            autocompleteItem(title: "/\(cmd.name)", description: cmd.description)
                        }
                        .accessibilityLabel("Command: \(cmd.name)")
                    }
                }
            } else if !filteredAgents.isEmpty {
                autocompleteScrollView {
                    ForEach(filteredAgents) { agent in
                        Button {
                            selectAgent(agent)
                        } label: {
                            autocompleteItem(title: "@\(agent.name)", description: agent.description) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                            }
                        }
                        .accessibilityLabel("Agent: \(agent.name)")
                    }
                }
            }
        }
    }

    private func autocompleteScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func autocompleteItem<Icon: View>(title: String, description: String?, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 4) {
            icon()
            Text(title)
                .font(.caption.weight(.medium))
            if let description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(Theme.textBase)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 6))
    }

    private func autocompleteItem(title: String, description: String?) -> some View {
        autocompleteItem(title: title, description: description) {
            EmptyView()
        }
    }

    private var attachButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Image(systemName: "paperclip")
                .font(.body)
                .foregroundStyle(Theme.textBase)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Attach file or photo")
        .onChange(of: selectedPhotoItem) {
            Task {
                guard let item = selectedPhotoItem else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let base64 = data.base64EncodedString()
                    let mime = (item.itemIdentifier ?? "").hasSuffix("png") ? "image/png" : "image/jpeg"
                    let filename = item.itemIdentifier ?? "image"
                    let part = MessagePartBody(type: "file", mime: mime, url: "data:\(mime);base64,\(base64)", filename: filename)
                    attachedFileParts.append(part)
                }
                selectedPhotoItem = nil
            }
        }
    }

    private var inputField: some View {
        TextField(placeholderText, text: $text, axis: .vertical)
            .font(.body)
            .lineLimit(1...5)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }
            .focused($isFocused)
            .onKeyPress(.upArrow) {
                onNavigateHistory(.up)
                return .handled
            }
            .onKeyPress(.downArrow) {
                onNavigateHistory(.down)
                return .handled
            }
    }

    private var actionButton: some View {
        Button {
            if isSending {
                onAbort()
            } else {
                sendOrAttach()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isSending ? Theme.errorCritical.opacity(0.8) : (canSend ? Theme.interactiveBlue : Color.gray.opacity(0.3)))
                    .frame(width: 36, height: 36)

                if isSending {
                    Image(systemName: "stop.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!isSending && !canSend)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(isSending ? "Abort message" : "Send message")
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedFileParts.isEmpty
    }

    private func sendOrAttach() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isShellMode || trimmed.hasPrefix("!") {
            let command = trimmed.hasPrefix("!") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
            if !command.isEmpty {
                text = ""
                isShellMode = false
                onShellCommand(command)
                return
            }
        }
        let parts = attachedFileParts
        attachedFileParts = []
        onSend(parts)
    }

    private func selectCommand(_ cmd: CommandInfo) {
        text = "/\(cmd.name) "
    }

    private func selectAgent(_ agent: AgentInfo) {
        guard let atRange = text.range(of: "@", options: .backwards) else { return }
        text.replaceSubrange(atRange.lowerBound..., with: "@\(agent.name) ")
    }
}
