import XCTest
@testable import OpenCodeNexus

@MainActor
final class ProviderManagerViewModelTests: XCTestCase {

    private var viewModel: ProviderManagerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ProviderManagerViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.providers.isEmpty)
        XCTAssertTrue(viewModel.connectedProviders.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testConnectProviderWithoutClient() async {
        await viewModel.connectProvider("openai")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDisconnectProviderWithoutClient() async {
        await viewModel.disconnectProvider("openai")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadProvidersWithoutClient() async {
        await viewModel.loadProviders()
        XCTAssertTrue(viewModel.providers.isEmpty)
    }
}
