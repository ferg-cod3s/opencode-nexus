import Foundation

enum MarkdownSegment {
    case markdown(AttributedString)
    case codeBlock(language: String?, source: String)
}
