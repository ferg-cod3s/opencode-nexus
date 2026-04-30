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
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }

    func testStartTerminalRequiresClient() async {
        viewModel.configure(client: nil, sessionId: "sess-1", directory: nil, agent: nil)
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testStartTerminalCreatesPtyAndConnects() async throws {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        let transport = MockPtyTransport()
        let factory = MockPtyTransportFactory(transport: transport)
        viewModel.configure(client: client, sessionId: "sess-1", directory: "/tmp", agent: "build", transportFactory: factory)
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .connected)
        XCTAssertNotNil(viewModel.terminalState)
    }

    func testStartTerminalFailureSetsErrorState() async {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        let transport = MockPtyTransport(shouldFail: true)
        let factory = MockPtyTransportFactory(transport: transport)
        viewModel.configure(client: client, sessionId: "sess-1", directory: "/tmp", agent: "build", transportFactory: factory)
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .failed)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testCloseTerminalDeletesPty() async throws {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        let transport = MockPtyTransport()
        let factory = MockPtyTransportFactory(transport: transport)
        viewModel.configure(client: client, sessionId: "sess-1", directory: "/tmp", agent: "build", transportFactory: factory)
        await viewModel.startTerminal()
        await viewModel.closeTerminal()
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertNil(viewModel.terminalState)
    }

    func testStartTerminalIdempotent() async throws {
        let client = OpenCodeClient(baseURL: URL(string: "http://localhost:4096")!)
        let transport = MockPtyTransport()
        let factory = MockPtyTransportFactory(transport: transport)
        viewModel.configure(client: client, sessionId: "sess-1", directory: "/tmp", agent: "build", transportFactory: factory)
        await viewModel.startTerminal()
        await viewModel.startTerminal()
        XCTAssertEqual(viewModel.connectionState, .connected)
    }
}

private final class MockPtyTransport: PtyTransport, @unchecked Sendable {
    private let shouldFail: Bool
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    let output: AsyncThrowingStream<Data, Error>

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
        var cont: AsyncThrowingStream<Data, Error>.Continuation!
        self.output = AsyncThrowingStream { cont = $0 }
        self.continuation = cont
    }

    func connect(request: URLRequest) async throws {
        if shouldFail {
            throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        }
    }

    func send(_ data: Data) async throws {}

    func close() async {
        continuation.finish()
    }
}

private final class MockPtyTransportFactory: PtyTransportFactory, @unchecked Sendable {
    private let transport: MockPtyTransport
    init(transport: MockPtyTransport) { self.transport = transport }
    func makeTransport() -> PtyTransport { transport }
}
