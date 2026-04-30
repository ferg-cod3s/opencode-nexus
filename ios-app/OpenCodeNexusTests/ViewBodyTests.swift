import SwiftUI
import XCTest
@testable import OpenCodeNexus

@MainActor
final class ViewBodyTests: XCTestCase {

    // MARK: - Simple Views (No Environment Dependencies)

    func testMessageBubbleBody() {
        let message = MessageEnvelope(
            info: MessageInfo(id: "1", isUser: true, isAssistant: false, agent: nil, modelID: nil,
                              threadID: nil, invitations: [], cost: nil, tokens: nil,
                              time: MessageInfo.Time(created: 0, updated: nil, relativeString: ""), error: nil),
            parts: [MessagePartBody(type: "text", text: "Hello")]
        )
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testSessionRowBody() {
        let session = Session(id: "1", title: "Test", directory: "/test", workspaceName: "W",
                              created: Date(), updated: Date())
        let view = SessionRow(session: session)
        evaluateBody(view)
    }

    func testSessionRowWithStatus() {
        let session = Session(id: "1", title: "Test", directory: "/test", workspaceName: "W",
                              created: Date(), updated: Date())
        let view = SessionRow(session: session, status: SessionStatus(status: "busy"),
                              hasPermission: true, hasQuestion: true)
        evaluateBody(view)
    }

    func testDiffLineViewBody() {
        let line = DiffLine(type: .addition, content: "added code", oldLineNumber: nil, newLineNumber: 5)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testDiffLineViewDeletion() {
        let line = DiffLine(type: .deletion, content: "removed code", oldLineNumber: 3, newLineNumber: nil)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testDiffLineViewHeader() {
        let line = DiffLine(type: .header, content: "@@ -1,3 +1,4 @@", oldLineNumber: 1, newLineNumber: 1)
        let view = DiffLineView(line: line)
        evaluateBody(view)
    }

    func testFileDiffViewBody() {
        let diff = FileDiff(newFile: "test.swift", oldFile: "test.swift", additions: 1, deletions: 0,
                             changes: [["+ new line"]])
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

    func testTypingIndicatorBody() {
        let view = TypingIndicator()
        evaluateBody(view)
    }

    // MARK: - Tool Output Views

    func testBashToolViewBody() {
        let view = BashToolView(input: ["command": .string("ls -la")], output: "file1.txt\nfile2.txt")
        evaluateBody(view)
    }

    func testFileReadToolViewBody() {
        let view = FileReadToolView(input: ["path": .string("/test/file.swift")], output: "let x = 1")
        evaluateBody(view)
    }

    func testFileEditToolViewBody() {
        let view = FileEditToolView(input: ["path": .string("/test/file.swift")])
        evaluateBody(view)
    }

    func testSearchToolViewBody() {
        let view = SearchToolView(input: ["query": .string("func test")], output: "found",
                                   icon: "magnifyingglass", color: .blue)
        evaluateBody(view)
    }

    func testWriteToolViewBody() {
        let view = WriteToolView(input: ["path": .string("/test/new.swift")])
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

    // MARK: - Model/Agent Picker

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

    func testInlineAgentPickerBody() {
        @State var selection: String? = nil
        let view = InlineAgentPicker(
            agents: [AgentInfo(id: "build", name: "Build", description: "Build agent", tools: nil, model: nil)],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testModelPickerBody() {
        @State var selection: ModelRefBody? = nil
        let view = ModelPicker(
            models: [],
            providers: [],
            defaults: [:],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testAgentPickerBody() {
        @State var selection: String? = nil
        let view = AgentPicker(agents: [], selection: $selection)
        evaluateBody(view)
    }

    // MARK: - Markdown Utilities

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

    // MARK: - DiffParser Integration

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