import SwiftUI

struct TerminalAccessoryView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    var onNavigateHistory: ((ChatViewModel.HistoryDirection) -> Void)?

    var body: some View {
        HStack(spacing: 2) {
            accessoryButton(icon: "control", label: "Ctrl") {
                text += "^"
            }
            accessoryButton(icon: "option", label: "Alt") {
                text += "\\"
            }
            accessoryButton(icon: "arrow.right.to.line.compact", label: "Tab") {
                text += "\t"
            }
            accessoryButton(icon: "escape", label: "Esc") {
                if !text.isEmpty { text.removeLast() }
            }
            accessoryButton(icon: "chevron.up", label: "Up") {
                onNavigateHistory?(.up)
            }
            accessoryButton(icon: "chevron.down", label: "Down") {
                onNavigateHistory?(.down)
            }

            Spacer()

            accessoryButton(icon: "arrow.right.to.line", label: "End") {
                text += "  "
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.bar)
    }

    private func accessoryButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
