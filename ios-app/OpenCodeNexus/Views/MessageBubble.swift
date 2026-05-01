import SwiftUI

struct MessageBubble: View {
    let message: MessageEnvelope
    @State private var showActions = false

    private var isUser: Bool { message.info.isUser }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 64) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                roleLabel

                ForEach(message.parts) { part in
                    if let partId = part.id {
                        PartView(part: part, isUser: isUser)
                            .id(partId)
                    } else {
                        PartView(part: part, isUser: isUser)
                    }
                }

                if let error = message.info.error {
                    ErrorBanner(error: error)
                }

                messageFooter
            }

            if !isUser { Spacer(minLength: 64) }
        }
        .padding(.horizontal, 16)
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.parts.filter { $0.isText }.map(\.displayText).joined(separator: "\n")
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    private var roleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: isUser ? "person.fill" : "cpu")
                .font(.caption2)
            Text(isUser ? "You" : "Assistant")
                .font(.caption2.weight(.semibold))
            if let agent = message.info.agent, !isUser {
                Text("(\(agent))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textWeak)
            }
        }
        .foregroundStyle(Theme.textBase)
        .padding(.leading, 4)
    }

    private var messageFooter: some View {
        HStack(spacing: 8) {
            Text(message.info.time.createdDate.relativeString)
                .font(.caption2)
                .foregroundStyle(Theme.textWeak)

            if let tokens = message.info.tokens {
                let total = (tokens.input ?? 0) + (tokens.output ?? 0)
                Label("\(formatTokenCount(total)) tokens", systemImage: "bolt")
                    .font(.caption2)
                    .foregroundStyle(Theme.textWeak)
            }

            if let cost = message.info.cost, cost > 0 {
                Text(String(format: "$%.4f", cost))
                    .font(.caption2)
                    .foregroundStyle(Theme.textWeak)
            }

            if let modelID = message.info.modelID {
                Text(modelID)
                    .font(.caption2)
                    .foregroundStyle(Theme.textWeak)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 4)
    }

    func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Part Rendering

struct PartView: View {
    let part: Part
    let isUser: Bool

    var body: some View {
        switch part.type {
        case "text":
            if !part.displayText.isEmpty {
                MarkdownTextView(text: part.displayText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.surfaceRaised.opacity(0.6))
                        }
                    }
                    .overlay {
                        if isUser {
                            Theme.borderOverlay(radius: 10)
                        }
                    }
            }
        case "tool":
            ToolCallView(part: part)
        case "reasoning":
            ReasoningView(text: part.displayText)
        case "step-start", "step-finish":
            EmptyView()
        case "patch":
            PatchView(part: part)
        case "agent":
            if let name = part.name {
                Label(name, systemImage: "person.crop.circle.badge.plus")
                    .font(.caption)
                    .foregroundStyle(Theme.textBase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    .overlay { Theme.borderOverlay(radius: 6) }
            }
        case "compaction":
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Context compacted")
            }
            .font(.caption)
            .foregroundStyle(Theme.textBase)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay { Theme.borderOverlay(radius: 6) }
        case "retry":
            if part.error != nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry (attempt \(part.attempt ?? 1))")
                }
                .font(.caption)
                .foregroundStyle(Theme.brandYuzu)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
                .overlay { Theme.borderOverlay(radius: 6) }
            }
        case "file":
            if let filename = part.filename ?? part.url {
                Label(filename, systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.interactiveBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    .overlay { Theme.borderOverlay(radius: 6) }
            }
        default:
            if !part.displayText.isEmpty {
                Text(part.displayText)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.surfaceRaised.opacity(0.6))
                        }
                    }
                    .overlay {
                        if isUser {
                            Theme.borderOverlay(radius: 10)
                        }
                    }
            }
        }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let part: Part
    @State private var isExpanded = false

    private var toolName: String {
        part.tool ?? ""
    }

    private var toolDuration: String? {
        guard let time = part.state?.time,
              let start = time.start, start > 0,
              let end = time.end, end > 0 else { return nil }
        let ms = end - start
        if ms >= 1000 {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
        return "\(ms)ms"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    toolIcon
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(toolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textStrong)
                            if let duration = toolDuration {
                                Text("· \(duration)")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textWeak)
                            }
                        }
                        if let error = part.state?.error {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(Theme.errorCritical)
                                .lineLimit(2)
                        } else if let title = part.state?.title {
                            Text(title)
                                .font(.caption2)
                                .foregroundStyle(Theme.textBase)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textWeak)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                toolContent
                if let error = part.state?.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.errorCritical)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .overlay { Theme.borderOverlay(radius: 8) }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch toolName {
        case "bash":
            BashToolView(input: part.state?.input, output: part.state?.output)
        case "read":
            FileReadToolView(input: part.state?.input, output: part.state?.output)
        case "edit":
            FileEditToolView(input: part.state?.input)
        case "write":
            WriteToolView(input: part.state?.input)
        case "glob":
            SearchToolView(
                input: part.state?.input,
                output: part.state?.output,
                icon: "doc.text.magnifyingglass",
                color: Theme.brandYuzu
            )
        case "grep":
            SearchToolView(
                input: part.state?.input,
                output: part.state?.output,
                icon: "text.magnifyingglass",
                color: Theme.interactiveBlue
            )
        case "webfetch":
            WebFetchToolView(input: part.state?.input, output: part.state?.output)
        case "websearch":
            WebFetchToolView(input: part.state?.input, output: part.state?.output)
        case "task":
            SubagentToolView(input: part.state?.input, output: part.state?.output)
        default:
            if let output = part.state?.output, !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textBase)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var toolIcon: some View {
        Group {
            if part.state?.isPending == true {
                ProgressView()
                    .controlSize(.small)
            } else if part.state?.isRunning == true {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.interactiveBlue)
            } else if part.state?.isCompleted == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                    .font(.caption)
            } else if part.state?.isError == true {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.errorCritical)
                    .font(.caption)
            } else {
                Image(systemName: "wrench")
                    .font(.caption)
                    .foregroundStyle(Theme.textBase)
            }
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Reasoning View

struct ReasoningView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb")
                            .font(.caption)
                        Text("Reasoning")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.textBase)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(Theme.textBase)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
            .overlay { Theme.borderOverlay(radius: 8) }
        }
    }
}

// MARK: - Patch View

struct PatchView: View {
    let part: Part

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.badge.gearshape")
                .font(.caption)
            if let files = part.files, !files.isEmpty {
                Text("\(files.count) file\(files.count == 1 ? "" : "s") changed")
                    .font(.caption)
            }
        }
        .foregroundStyle(Theme.textBase)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 6))
        .overlay { Theme.borderOverlay(radius: 6) }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: MessageError

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.brandYuzu)
            Text(error.displayMessage)
                .font(.caption)
                .foregroundStyle(Theme.textBase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 6))
        .overlay { Theme.borderOverlay(radius: 6) }
    }
}

// MARK: - Markdown Text

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownRenderer.render(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .markdown(let attributed):
                    Text(attributed)
                        .font(.body)
                        .foregroundStyle(Theme.textStrong)
                        .textSelection(.enabled)
                case .codeBlock(let lang, let source):
                    CodeBlockView(language: lang, source: source)
                }
            }
        }
    }
}
