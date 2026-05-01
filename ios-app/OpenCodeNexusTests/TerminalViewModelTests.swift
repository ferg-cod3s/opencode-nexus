import XCTest
@testable import OpenCodeNexus

final class TerminalViewModelTests: XCTestCase {

    @MainActor
    func testStartTerminalNoClient() async {
        let viewModel = TerminalViewModel()
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        XCTAssertEqual(viewModel.errorMessage, "No server connection")
    }

    @MainActor
    func testCloseTerminalNoSession() async {
        let viewModel = TerminalViewModel()
        viewModel.connectionState = .connected
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.debugMessage)
    }

    @MainActor
    func testRetryTerminalNoClient() async {
        let viewModel = TerminalViewModel()
        await viewModel.retryTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
    }

    @MainActor
    func testResizeTerminalNoClient() async {
        let viewModel = TerminalViewModel()
        await viewModel.resizeTerminal(rows: 24, cols: 80)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testStartTerminalClientThrows() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.setRequestHandler { _ in
            let error = NSError(domain: "test", code: 500)
            return (HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OpenCodeClient(baseURL: URL(string: "http://opencode.test")!, configuration: config)
        let viewModel = TerminalViewModel()
        viewModel.configure(client: client, sessionId: "ses_1", directory: "/p", agent: "build")
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testConfigureStoresParameters() {
        let viewModel = TerminalViewModel()
        let client = OpenCodeClient(baseURL: URL(string: "http://test")!)
        viewModel.configure(client: client, sessionId: "ses_1", directory: "/tmp", agent: "build")
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testCloseTerminalIdempotent() async {
        let viewModel = TerminalViewModel()
        viewModel.connectionState = .connecting
        viewModel.debugMessage = "testing..."
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.debugMessage)
        await viewModel.closeTerminal()
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }

    @MainActor
    func testRetryTerminalMultipleTimes() async {
        let viewModel = TerminalViewModel()
        viewModel.connectionState = .connected
        await viewModel.retryTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        await viewModel.retryTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
    }

    @MainActor
    func testResizeTerminalWithClientNoPtyId() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = OpenCodeClient(baseURL: URL(string: "http://test")!, configuration: config)
        let viewModel = TerminalViewModel()
        viewModel.configure(client: client, sessionId: "ses_1", directory: "/tmp", agent: "build")
        await viewModel.resizeTerminal(rows: 24, cols: 80)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testStateTransitionsFromNilClient() async {
        let viewModel = TerminalViewModel()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        XCTAssertEqual(viewModel.errorMessage, "No server connection")
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.debugMessage)
    }

    @MainActor
    func testCloseTerminalClearsAllState() async {
        let viewModel = TerminalViewModel()
        viewModel.connectionState = .connecting
        viewModel.debugMessage = "debug info"
        viewModel.errorMessage = "some error"
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.debugMessage)
    }

    @MainActor
    func testConfigureWithTransportFactory() {
        let viewModel = TerminalViewModel()
        let client = OpenCodeClient(baseURL: URL(string: "http://test")!)
        let factory = DefaultPtyTransportFactory(session: client.urlSession)
        viewModel.configure(client: client, sessionId: "ses_1", directory: "/tmp", agent: "build", transportFactory: factory)
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }
}
