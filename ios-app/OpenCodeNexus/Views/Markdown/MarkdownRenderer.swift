import Foundation

struct MarkdownRenderer {
    static func render(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        let pattern = /```(\w*)\n([\s\S]*?)```/
        var currentIndex = text.startIndex

        for match in text.matches(of: pattern) {
            if match.range.lowerBound > currentIndex {
                let markdownText = String(text[currentIndex..<match.range.lowerBound])
                if !markdownText.isEmpty {
                    let trimmed = markdownText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if let attributed = try? AttributedString(markdown: trimmed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            segments.append(.markdown(attributed))
                        } else {
                            segments.append(.markdown(AttributedString(trimmed)))
                        }
                    }
                }
            }

            let language = match.output.1.isEmpty ? nil : String(match.output.1)
            var source = String(match.output.2)
            if source.hasSuffix("\n") {
                source.removeLast()
            }
            segments.append(.codeBlock(language: language, source: source))
            currentIndex = match.range.upperBound
        }

        if currentIndex < text.endIndex {
            let remaining = String(text[currentIndex..<text.endIndex])
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if let attributed = try? AttributedString(markdown: trimmed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    segments.append(.markdown(attributed))
                } else {
                    segments.append(.markdown(AttributedString(trimmed)))
                }
            }
        }

        if segments.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                segments.append(.markdown(attributed))
            } else {
                segments.append(.markdown(AttributedString(text)))
            }
        }

        return segments
    }
}
