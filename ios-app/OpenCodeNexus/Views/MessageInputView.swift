import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            inputField

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular)
    }

    private var inputField: some View {
        TextField("Type a message...", text: $text, axis: .vertical)
            .font(.body)
            .lineLimit(1...5)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .focused($isFocused)
    }

    private var sendButton: some View {
        Button {
            onSend()
        } label: {
            ZStack {
                Circle()
                    .fill(canSend ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)

                if isSending {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!canSend || isSending)
        .frame(minWidth: 44, minHeight: 44)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
