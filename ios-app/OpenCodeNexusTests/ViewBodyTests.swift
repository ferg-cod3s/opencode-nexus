import SwiftUI
import XCTest
@testable import OpenCodeNexus

@MainActor
final class ViewBodyTests: XCTestCase {

    func testMessageBubbleBody() throws {
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testSessionRowBody() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session)
        evaluateBody(view)
    }

    func testDiffLineViewBody() {
        let line = DiffLine(id: 0, type: .addition, content: "added code", oldLineNumber: nil, newLineNumber: 5)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testDiffLineViewDeletion() {
        let line = DiffLine(id: 1, type: .deletion, content: "removed code", oldLineNumber: 3, newLineNumber: nil)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testDiffLineViewHeader() {
        let line = DiffLine(id: 2, type: .header, content: "@@ -1,3 +1,4 @@", oldLineNumber: 1, newLineNumber: 1)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testFileDiffViewBody() throws {
        let diff = try decodeFileDiff()
        let lines = DiffParser.parse("+ new line")
        let view = FileDiffView(diff: diff, diffLines: lines)
        evaluateBody(view)
    }

    func testCodeBlockViewBody() {
        let view = CodeBlockView(language: "swift", source: "let x = 1")
        evaluateBody(view)
    }

    func testCodeBlockViewNoLanguage() {
        let view = CodeBlockView(language: nil, source: "plain text code")
        evaluateBody(view)
    }

    func testTerminalAccessoryViewBody() {
        @State var text = "test command"
        let view = TerminalAccessoryView(text: $text, onSubmit: {}, onNavigateHistory: { _ in })
        evaluateBody(view)
    }

    func testTerminalAccessoryViewNoHistory() {
        @State var text = ""
        let view = TerminalAccessoryView(text: $text, onSubmit: {})
        evaluateBody(view)
    }

    func testReasoningViewBody() {
        let view = ReasoningView(text: "Let me think about this...")
        evaluateBody(view)
    }

    func testMarkdownTextViewBody() {
        let view = MarkdownTextView(text: "Hello **world**")
        evaluateBody(view)
    }

    func testErrorBannerBody() {
        let json = """
        {"name": "TestError", "data": {"message": "Something failed"}}
        """
        let error = try! JSONDecoder().decode(MessageError.self, from: Data(json.utf8))
        let view = ErrorBanner(error: error)
        evaluateBody(view)
    }

    func testToolOutputViews() {
        let bashView = BashToolView(input: ["command": .string("ls")], output: "out")
        evaluateBody(bashView)
        let readView = FileReadToolView(input: ["path": .string("/f")], output: "code")
        evaluateBody(readView)
        let editView = FileEditToolView(input: ["path": .string("/f")])
        evaluateBody(editView)
        let writeView = WriteToolView(input: ["path": .string("/f")])
        evaluateBody(writeView)
    }

    func testSearchToolViewBody() {
        let view = SearchToolView(input: ["query": .string("func test")], output: "found",
                                   icon: "magnifyingglass", color: .blue)
        evaluateBody(view)
    }

    func testWebFetchToolViewBody() {
        let view = WebFetchToolView(input: ["url": .string("https://example.com")], output: "<html>")
        evaluateBody(view)
    }

    func testSubagentToolViewBody() {
        let view = SubagentToolView(input: ["task": .string("review")], output: "done")
        evaluateBody(view)
    }

    func testSearchResultRowBody() {
        let result = ToolSearchResult(file: "test.swift", line: "42", text: "func test()")
        let view = SearchResultRow(result: result)
        evaluateBody(view)
    }

    func testInlineModelPickerBody() {
        @State var selection: ModelRefBody? = nil
        let view = InlineModelPicker(
            models: [("provider1", "model1", "GPT-4")],
            providers: [],
            defaults: [:],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testInlineAgentPickerBody() throws {
        @State var selection: String? = nil
        let agent = try JSONDecoder().decode(AgentInfo.self, from: Data("{\"name\": \"build\", \"description\": \"Build agent\"}".utf8))
        let view = InlineAgentPicker(agents: [agent], selection: $selection)
        evaluateBody(view)
    }

    func testModelPickerBody() {
        @State var selection: ModelRefBody? = nil
        let view = ModelPicker(models: [], providers: [], defaults: [:], selection: $selection)
        evaluateBody(view)
    }

    func testAgentPickerBody() {
        @State var selection: String? = nil
        let view = AgentPicker(agents: [], selection: $selection)
        evaluateBody(view)
    }

    func testMarkdownRendererRender() {
        let segments = MarkdownRenderer.render("Hello **world**\n```\ncode\n```\nMore text")
        XCTAssertFalse(segments.isEmpty)
    }

    func testMarkdownRendererEmptyString() {
        let segments = MarkdownRenderer.render("")
        XCTAssertTrue(segments.isEmpty)
    }

    func testSyntaxHighlighterHighlight() {
        let result = SyntaxHighlighter.highlight("let x = 1", language: "swift")
        XCTAssertFalse(result.characters.isEmpty)
    }

    func testSyntaxHighlighterUnknownLanguage() {
        let result = SyntaxHighlighter.highlight("some text", language: "unknown")
        XCTAssertFalse(result.characters.isEmpty)
    }

    func testSyntaxHighlighterNilLanguage() {
        let result = SyntaxHighlighter.highlight("plain text", language: nil)
        XCTAssertFalse(result.characters.isEmpty)
    }

    func testDiffParserFullDiff() {
        let diff = """
        --- a/old.swift
        +++ b/new.swift
        @@ -1,3 +1,4 @@
         line1
        -removed
        +added
        +added2
         line3
        """
        let lines = DiffParser.parse(diff)
        XCTAssertTrue(lines.contains(where: { $0.type == .header }))
        XCTAssertTrue(lines.contains(where: { $0.type == .addition }))
        XCTAssertTrue(lines.contains(where: { $0.type == .deletion }))
        XCTAssertTrue(lines.contains(where: { $0.type == .context }))
    }
}

private extension ViewBodyTests {
    func decodeSession(id: String, title: String) throws -> Session {
        let json = """
        {"id": "\(id)", "title": "\(title)", "directory": "/test", "time": {"created": 1000}}
        """
        return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
    }

    func decodeMessageEnvelope(id: String, role: String, text: String) throws -> MessageEnvelope {
        let json = """
        {"info": {"id": "\(id)", "role": "\(role)", "time": {"created": 1000}}, "parts": [{"type": "text", "text": "\(text)"}]}
        """
        return try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
    }

    func decodeFileDiff() throws -> FileDiff {
        let json = """
        {"file": "test.swift", "before": "old.swift", "after": "test.swift", "additions": 1, "deletions": 0}
        """
        return try JSONDecoder().decode(FileDiff.self, from: Data(json.utf8))
    }
}
