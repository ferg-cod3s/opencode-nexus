import XCTest
@testable import OpenCodeNexus

@MainActor
final class TerminalViewModelTests: XCTestCase {
    private var viewModel: TerminalViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TerminalViewModel()
    }

    func testConfigureSetsProperties() {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        viewModel.configure(client: client, sessionId: "sess-1", directory: "/tmp", agent: "build")
        viewModel.commandText = "echo hello"
        XCTAssertFalse(viewModel.commandText.isEmpty)
    }

    func testExecuteCommandRequiresClient() async {
        viewModel.configure(client: nil, sessionId: "sess-1", directory: nil, agent: nil)
        viewModel.commandText = "echo hello"
        await viewModel.executeCommand()
        XCTAssertTrue(viewModel.outputLines.isEmpty)
    }

    func testExecuteCommandIgnoresEmpty() async {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        viewModel.configure(client: client, sessionId: "sess-1", directory: nil, agent: nil)
        viewModel.commandText = "   "
        await viewModel.executeCommand()
        XCTAssertTrue(viewModel.outputLines.isEmpty)
    }

    func testClearOutput() {
        viewModel.outputLines = [TerminalLine(text: "test", type: .output)]
        viewModel.clearOutput()
        XCTAssertTrue(viewModel.outputLines.isEmpty)
    }

    func testNavigateHistoryUpFromEmpty() {
        XCTAssertNil(viewModel.navigateHistory(.up))
    }

    func testNavigateHistoryDownFromEmpty() {
        XCTAssertNil(viewModel.navigateHistory(.down))
    }

    func testNavigateHistoryUpCyclesThroughHistory() {
        viewModel.commandHistory = ["cmd1", "cmd2", "cmd3"]
        let result1 = viewModel.navigateHistory(.up)
        XCTAssertEqual(result1, "cmd1")
        let result2 = viewModel.navigateHistory(.up)
        XCTAssertEqual(result2, "cmd2")
        let result3 = viewModel.navigateHistory(.up)
        XCTAssertEqual(result3, "cmd3")
    }

    func testNavigateHistoryDownGoesBack() {
        viewModel.commandHistory = ["cmd1", "cmd2"]
        _ = viewModel.navigateHistory(.up)
        _ = viewModel.navigateHistory(.up)
        let down1 = viewModel.navigateHistory(.down)
        XCTAssertEqual(down1, "cmd1")
        let down2 = viewModel.navigateHistory(.down)
        XCTAssertEqual(down2, "")
        XCTAssertNil(viewModel.historyIndex)
    }

    func testNavigateHistoryUpStopsAtEnd() {
        viewModel.commandHistory = ["cmd1"]
        _ = viewModel.navigateHistory(.up)
        let result = viewModel.navigateHistory(.up)
        XCTAssertNil(result)
        XCTAssertEqual(viewModel.historyIndex, 0)
    }

    func testHistoryLimitedTo100() {
        for i in 0..<110 {
            viewModel.commandHistory.insert("cmd\(i)", at: 0)
        }
        while viewModel.commandHistory.count > 100 {
            viewModel.commandHistory.removeLast()
        }
        XCTAssertLessThanOrEqual(viewModel.commandHistory.count, 100)
    }
}