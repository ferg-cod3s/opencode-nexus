import SwiftUI

struct MessageListView: View {
    let session: Session
    let messages: [Message]
    let isLoading: Bool
    let isSending: Bool
    @Binding var inputText: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            messageListPane
            Divider()
            MessageInputView(
                text: $inputText,
                isSending: isSending,
                onSend: onSend
            )
        }
        .navigationTitle(session.title.isEmpty ? "Untitled" : session.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messageListPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty && !isLoading {
                        emptyState
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if isSending {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("typing")
                    }
                }
                .padding(.vertical, 16)
            }
            .overlay {
                if isLoading && messages.isEmpty {
                    ProgressView("Loading messages...")
                }
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isSending) {
                if isSending {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Send a message to start the conversation")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 60)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

private struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Thinking")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 5, height: 5)
                        .offset(y: animate ? -3 : 3)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animate
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .onAppear { animate = true }
    }
}
