import SwiftUI

struct CodeBlockView: View {
    let language: String?
    let source: String
    @State private var showCopied = false

    private var highlightedSource: AttributedString {
        let withLineNumbers = addLineNumbers(source)
        return SyntaxHighlighter.highlight(withLineNumbers, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textWeak)
                Spacer()
                Button {
                    UIPasteboard.general.string = source
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(showCopied ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.textWeak)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().overlay(Theme.borderWeak)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightedSource)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textStrong)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .overlay { Theme.borderOverlay(radius: 8) }
    }

    private func addLineNumbers(_ code: String) -> String {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = lines.count
        let width = String(lineCount).count
        let pad = String(repeating: " ", count: width)
        return lines.enumerated().map { index, line in
            let num = String(index + 1)
            let padded = pad + num
            let trimmed = padded.suffix(width)
            return "\(trimmed) | \(line)"
        }.joined(separator: "\n")
    }
}
