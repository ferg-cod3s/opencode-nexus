import SwiftUI

struct TerminalOutputView: View {
    let lines: [TerminalLine]
    let proxy: ScrollViewProxy

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines) { line in
                        HStack(spacing: 0) {
                            Text(line.text)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(color(for: line.type))
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .id(line.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func color(for type: TerminalLineType) -> Color {
        switch type {
        case .input: Theme.interactiveBlue
        case .output: Theme.textBase
        case .error: Theme.errorCritical
        case .system: Theme.textWeak
        }
    }
}
