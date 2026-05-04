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

    func testMessageBubbleWithTokens() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}, "tokens": {"input": 500, "output": 1500}, "cost": 0.0023, "modelID": "gpt-4", "agent": "build"}, "parts": [{"type": "text", "text": "Hello"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithError() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}, "error": {"name": "TestError", "data": {"message": "fail"}}}, "parts": [{"type": "text", "text": "Hello"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithToolPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "tool", "tool": "search", "text": "results"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithReasoningPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "reasoning", "text": "thinking..."}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithPatchPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "patch", "text": "diff"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithAgentPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "agent", "name": "coder"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithCompactionPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "compaction"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithRetryPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "retry", "error": {"name": "Err", "data": {"message": "retrying"}}, "attempt": 2}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testSessionRowBody() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session)
        evaluateBody(view)
    }

    func testSessionRowWithStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "busy"))
        evaluateBody(view)
    }

    func testSessionRowWithPermission() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, hasPermission: true)
        evaluateBody(view)
    }

    func testSessionRowWithQuestion() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, hasQuestion: true)
        evaluateBody(view)
    }

    func testSessionRowWithShare() throws {
        let json = """
        {"id": "1", "title": "Test", "directory": "/test", "time": {"created": 1000}, "share": {"url": "https://share.link"}}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        let view = SessionRow(session: session)
        evaluateBody(view)
    }

    func testSessionRowWithSummary() throws {
        let json = """
        {"id": "1", "title": "Test", "directory": "/test", "time": {"created": 1000}, "summary": {"additions": 10, "deletions": 5, "files": 2}}
        """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        let view = SessionRow(session: session)
        evaluateBody(view)
    }

    func testQuestionSheetRendersEmpty() {
        let view = QuestionSheet(questions: [], onAnswer: { _, _ in }, onReject: { _ in })
        evaluateBody(view)
    }

    func testQuestionSheetRendersWithSingleQuestion() {
        let info = QuestionInfo(
            question: "Which language?",
            header: "Language",
            options: [QuestionOption(label: "Swift", description: "iOS"),
                      QuestionOption(label: "TypeScript", description: "Web")],
            multiple: false,
            custom: true
        )
        let question = Question(
            id: "que_1",
            sessionID: "ses_1",
            messageID: nil,
            title: "Pick one",
            description: "Choose your language",
            questions: [info]
        )
        let view = QuestionSheet(questions: [question], onAnswer: { _, _ in }, onReject: { _ in })
        evaluateBody(view)
    }

    func testChatSidebarShowsArchivedSection() throws {
        let viewModel = ChatViewModel()
        viewModel.sessions = [try decodeSession(id: "active", title: "Active Session")]
        let archived = try JSONDecoder().decode(Session.self, from: Data("""
        {"id":"archived","title":"Archived Session","directory":"/test","time":{"created":1000,"archived":1200}}
        """.utf8))
        viewModel.archivedSessions = [archived]

        let renderedText = renderedTexts(
            NavigationStack {
                ChatSidebarView(
                    chatVM: viewModel,
                    collapsedDirectories: .constant([]),
                    onDisconnect: {},
                    onNewSession: {},
                    onShowWorkspaces: {}
                )
            }
        )

        XCTAssertTrue(renderedText.contains("Archived"))
        XCTAssertTrue(renderedText.contains("Archived Session"))
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

    func testMessageListViewBody() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: false,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testMessageListViewWithBanners() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let diff = try decodeFileDiff()
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: true,
            isSessionBusy: true,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [diff],
            todos: [],
            hasPermission: true,
            hasQuestion: true,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: true,
            onLoadMoreMessages: { },
            availableModels: [("openai", "gpt-4", "GPT-4")],
            availableAgents: [AgentInfo(name: "Build", description: nil, mode: nil, builtIn: nil, permission: nil)],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [CommandInfo(name: "commit", description: "Commit changes")],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: ["Follow up"],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
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

extension ViewBodyTests {
    func decodeSession(id: String, title: String) throws -> Session {
        let json = """
        {"id": "\(id)", "title": "\(title)", "directory": "/test", "time": {"created": 1000}}
        """
        return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
    }

    func renderedTexts<V: View>(_ view: V) -> String {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        return collectText(from: controller.view).joined(separator: " ")
    }

    func collectText(from view: UIView) -> [String] {
        var result: [String] = []
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            result.append(text)
        }
        if let textField = view as? UITextField, let text = textField.text, !text.isEmpty {
            result.append(text)
        }
        for subview in view.subviews {
            result.append(contentsOf: collectText(from: subview))
        }
        return result
    }

    func testMessageBubbleUserMessage() throws {
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleEmptyText() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "text", "text": ""}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleStepStartPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "step-start", "text": "step"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleStepFinishPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "step-finish", "text": "step"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleFilePart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "file", "filename": "test.swift", "text": "code"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleSnapshotPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "snapshot", "text": "snap"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleSubtaskPart() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "subtask", "text": "sub"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleMultipleParts() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "text", "text": "Hello"}, {"type": "tool", "tool": "search", "text": "results"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageListViewEmpty() throws {
        let session = try decodeSession(id: "1", title: "Test")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [],
            isLoading: true,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: false,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testMessageListViewSendingWithTUI() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: true,
            isSessionBusy: true,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [Todo(id: "1", content: "Todo", status: "pending", priority: "high")],
            hasPermission: true,
            hasQuestion: true,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: true,
            onLoadMoreMessages: { },
            availableModels: [("openai", "gpt-4", "GPT-4")],
            availableAgents: [AgentInfo(name: "Build", description: nil, mode: nil, builtIn: nil, permission: nil)],
            availableProviders: [ProviderInfo(id: "openai", name: "OpenAI", models: nil)],
            providerDefaults: ["openai": "gpt-4"],
            availableCommands: [CommandInfo(name: "commit", description: "Commit changes")],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: ["Queued"],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testModelPickerWithModels() {
        @State var selection: ModelRefBody? = nil
        let view = ModelPicker(
            models: [("openai", "gpt-4", "GPT-4"), ("anthropic", "claude", "Claude")],
            providers: [ProviderInfo(id: "openai", name: "OpenAI", models: nil), ProviderInfo(id: "anthropic", name: "Anthropic", models: nil)],
            defaults: ["openai": "gpt-4"],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testAgentPickerWithAgents() {
        @State var selection: String? = nil
        let view = AgentPicker(
            agents: [AgentInfo(name: "build", description: "Build", mode: "primary", builtIn: false, permission: nil)],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testInlineModelPickerWithSelection() {
        @State var selection: ModelRefBody? = ModelRefBody(providerID: "openai", modelID: "gpt-4")
        let view = InlineModelPicker(
            models: [("openai", "gpt-4", "GPT-4"), ("anthropic", "claude", "Claude")],
            providers: [ProviderInfo(id: "openai", name: "OpenAI", models: nil), ProviderInfo(id: "anthropic", name: "Anthropic", models: nil)],
            defaults: ["openai": "gpt-4"],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testInlineAgentPickerWithSelection() {
        @State var selection: String? = "build"
        let view = InlineAgentPicker(
            agents: [AgentInfo(name: "build", description: "Build", mode: "primary", builtIn: false, permission: nil)],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testSessionRowWithBusyStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "busy"))
        evaluateBody(view)
    }

    func testSessionRowWithIdleStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "idle"))
        evaluateBody(view)
    }

    func testSessionRowWithRetryStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "retry"))
        evaluateBody(view)
    }

    func testSessionRowWithWaitingStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "waiting-for-input"))
        evaluateBody(view)
    }

    func testSessionRowWithFailedStatus() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, status: SessionStatus(status: "error"))
        evaluateBody(view)
    }

    func testSessionRowWithBothPermissionAndQuestion() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let view = SessionRow(session: session, hasPermission: true, hasQuestion: true)
        evaluateBody(view)
    }

    func testMessageBubbleWithModelAndZeroTokens() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}, "tokens": {"input": 0, "output": 0}, "modelID": "gpt-4"}, "parts": [{"type": "text", "text": "Hello"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithCostZero() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}, "cost": 0}, "parts": [{"type": "text", "text": "Hello"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithRetryNoAttempt() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "retry", "error": {"name": "Err", "data": {"message": "retrying"}}}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithAgentNoName() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"type": "agent"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageBubbleWithPartId() throws {
        let json = """
        {"info": {"id": "1", "role": "assistant", "time": {"created": 1000}}, "parts": [{"id": "part-1", "type": "text", "text": "Hello"}]}
        """
        let message = try JSONDecoder().decode(MessageEnvelope.self, from: Data(json.utf8))
        let view = MessageBubble(message: message)
        evaluateBody(view)
    }

    func testMessageListViewWithDiffsAndTodos() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        let diff = try decodeFileDiff()
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [diff],
            todos: [Todo(id: "1", content: "Todo", status: "completed", priority: "high")],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: false,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testMessageListViewEmptyNotLoading() throws {
        let session = try decodeSession(id: "1", title: "Test")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [],
            isLoading: false,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: false,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testMessageListViewWithAssistantMessage() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "assistant", text: "Hello")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: true,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testMessageListViewWithTUIQuestions() throws {
        let session = try decodeSession(id: "1", title: "Test")
        let message = try decodeMessageEnvelope(id: "1", role: "user", text: "Hello")
        @State var inputText = ""
        @State var attachedParts: [MessagePartBody] = []
        @State var selectedModel: ModelRefBody? = nil
        @State var selectedAgent: String? = nil
        let tuiBody = JSONValue.object([
            "questions": .array([
                .object([
                    "header": .string("Test Header"),
                    "question": .string("Test Question"),
                    "options": .array([
                        .object(["label": .string("Yes"), "description": .string("Yes desc")]),
                        .object(["label": .string("No"), "description": .string("No desc")])
                    ]),
                    "multiple": .bool(false)
                ])
            ])
        ])
        let view = MessageListView(
            session: session,
            messages: [message],
            isLoading: false,
            isSending: false,
            isSessionBusy: false,
            inputText: $inputText,
            attachedParts: $attachedParts,
            onSend: { _ in },
            onAbort: { },
            onFork: { _ in },
            onDelete: { _ in },
            onRevert: { _, _ in },
            diffs: [],
            todos: [],
            hasPermission: false,
            hasQuestion: false,
            onShowPermissions: { },
            onShowDiffs: { },
            onShowQuestion: { },
            hasMoreMessages: false,
            onLoadMoreMessages: { },
            availableModels: [],
            availableAgents: [],
            availableProviders: [],
            providerDefaults: [:],
            availableCommands: [],
            selectedModel: $selectedModel,
            selectedAgent: $selectedAgent,
            onNavigateHistory: { _ in },
            onShellCommand: { _ in },
            queuedMessages: [],
            onQueueFollowUp: { },
            onSubmitQueuedPrompt: { },
            onClearQueuedPrompt: { },
            onRespondToTUIRequest: { _ in },
            onRefresh: { }
        )
        evaluateBody(view)
    }

    func testModelPickerExpanded() {
        @State var selection: ModelRefBody? = ModelRefBody(providerID: "openai", modelID: "gpt-4")
        let view = ModelPicker(
            models: [("openai", "gpt-4", "GPT-4")],
            providers: [ProviderInfo(id: "openai", name: "OpenAI", models: nil)],
            defaults: [:],
            selection: $selection
        )
        evaluateBody(view)
    }

    func testTerminalViewModelStateTransitions() {
        let viewModel = TerminalViewModel()
        viewModel.connectionState = .connecting
        viewModel.debugMessage = "Connecting"
        viewModel.errorMessage = "Error"
        XCTAssertEqual(viewModel.connectionState, .connecting)
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
