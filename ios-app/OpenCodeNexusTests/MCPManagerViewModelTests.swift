import XCTest
@testable import OpenCodeNexus

@MainActor
final class MCPManagerViewModelTests: XCTestCase {

    private var viewModel: MCPManagerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MCPManagerViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.servers.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showAddServer)
        XCTAssertTrue(viewModel.newServerName.isEmpty)
        XCTAssertTrue(viewModel.newServerCommand.isEmpty)
        XCTAssertTrue(viewModel.newServerArgs.isEmpty)
    }

    func testAddServerValidation() async {
        viewModel.newServerName = ""
        viewModel.newServerCommand = "npx"
        await viewModel.addServer()
        XCTAssertFalse(viewModel.showAddServer)

        viewModel.newServerName = "test-server"
        viewModel.newServerCommand = ""
        await viewModel.addServer()
        XCTAssertFalse(viewModel.showAddServer)
    }

    func testConnectServerWithoutClient() async {
        await viewModel.connectServer("test-server")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDisconnectServerWithoutClient() async {
        await viewModel.disconnectServer("test-server")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRemoveServerWithoutClient() async {
        await viewModel.removeServer("test-server")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadServersWithoutClient() async {
        await viewModel.loadServers()
        XCTAssertTrue(viewModel.servers.isEmpty)
    }
}
