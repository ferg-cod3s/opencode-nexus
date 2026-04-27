import SwiftUI

struct MessageBubble: View {
    let message: Message

    private var isUser: Bool {
        message.info.role == "user"
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 64) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                roleLabel

                ForEach(message.parts.filter { $0.type == "text" }) { part in
                    if !part.displayText.isEmpty {
                        Text(part.displayText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .rect(cornerRadius: 18))
                            .tint(isUser ? .blue : nil)
                            .textSelection(.enabled)
                    }
                }

                timestampLabel
            }

            if !isUser { Spacer(minLength: 64) }
        }
        .padding(.horizontal, 16)
    }

    private var roleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: isUser ? "person.fill" : "cpu")
                .font(.caption2)
            Text(isUser ? "You" : "Assistant")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 4)
    }

    private var timestampLabel: some View {
        Text(message.info.time.createdDate.relativeString)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 4)
    }
}
