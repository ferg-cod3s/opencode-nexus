import XCTest
@testable import OpenCodeNexus

@MainActor
final class ConnectionManagerAdvancedTests: XCTestCase {

    private var serverStore: ServerStore!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.servers.v1")
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.active-server")
        serverStore = ServerStore()
    }

    override func tearDown() {
        serverStore = nil
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.servers.v1")
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.active-server")
        MockURLProtocol.setRequestHandler(nil)
        super.tearDown()
    }

    private func makeConfig(url: String = "http://localhost:4096") -> ServerConfig {
        ServerConfig(url: url, displayName: "Test", username: nil)
    }

    private func respondJSON(_ json: String, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(json.utf8))
    }

    private func makeMockConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    private func setupMock(_ handler: @Sendable @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSessionConfiguration {
        MockURLProtocol.setRequestHandler(handler)
        return makeMockConfiguration()
    }

    func testConnectSuccessSetsConnected() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":true,\"version\":\"1.0.0\"}".utf8))
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        XCTAssertTrue(manager.isConnected)
        XCTAssertNotNil(manager.client)
    }

    func testConnectSuccessSetsTestResult() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":true,\"version\":\"2.0\"}".utf8))
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        if case .success(let version) = manager.testResult {
            XCTAssertEqual(version, "2.0")
        } else {
            XCTFail("Expected success result")
        }
    }

    func testConnectUnhealthyServer() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":false,\"version\":\"1.0\"}".utf8))
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        XCTAssertFalse(manager.isConnected)
        if case .failure = manager.testResult {
        } else {
            XCTFail("Expected failure result")
        }
    }

    func testConnectNetworkError() async {
        let mockConfig = setupMock { _ in
            throw URLError(.notConnectedToInternet)
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        XCTAssertFalse(manager.isConnected)
        if case .failure = manager.testResult {
        } else {
            XCTFail("Expected failure result")
        }
    }

    func testConnectInvalidURL() async {
        let config = ServerConfig(url: "not a url at all !!!", displayName: "Bad", username: nil)
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore)
        await manager.connect(to: config)
        XCTAssertFalse(manager.isConnected)
        if case .failure(let msg) = manager.testResult {
            XCTAssertTrue(msg.contains("Invalid URL"))
        } else {
            XCTFail("Expected failure result")
        }
    }

    func testConnectSetsActiveServerInStore() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":true,\"version\":\"1.0\"}".utf8))
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        XCTAssertEqual(serverStore.activeServer?.id, config.id)
    }

    func testTestConnectionSuccess() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":true,\"version\":\"3.0\"}".utf8))
        }
        let config = makeConfig()
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        let result = await manager.testConnection(config)
        if case .success(let version) = result {
            XCTAssertEqual(version, "3.0")
        } else {
            XCTFail("Expected success")
        }
    }

    func testTestConnectionFailure() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":false,\"version\":\"1.0\"}".utf8))
        }
        let config = makeConfig()
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        let result = await manager.testConnection(config)
        if case .failure = result {
        } else {
            XCTFail("Expected failure")
        }
    }

    func testTestConnectionInvalidURL() async {
        let config = ServerConfig(url: "   ", displayName: "Bad", username: nil)
        let manager = ConnectionManager(serverStore: serverStore)
        let result = await manager.testConnection(config)
        if case .failure = result {
        } else {
            XCTFail("Expected failure")
        }
    }

    func testDisconnectResetsState() async {
        let mockConfig = setupMock { _ in
            let response = HTTPURLResponse(url: URL(string: "http://localhost:4096")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"healthy\":true,\"version\":\"1.0\"}".utf8))
        }
        let config = makeConfig()
        serverStore.addServer(config)
        let manager = ConnectionManager(serverStore: serverStore, urlSessionConfiguration: mockConfig)
        await manager.connect(to: config)
        XCTAssertTrue(manager.isConnected)
        manager.disconnect()
        XCTAssertFalse(manager.isConnected)
        XCTAssertNil(manager.client)
        XCTAssertNil(manager.testResult)
    }

    func testConnectAndTestWithNoActiveServer() async {
        let manager = ConnectionManager(serverStore: serverStore)
        await manager.connectAndTest()
        if case .failure(let msg) = manager.testResult {
            XCTAssertTrue(msg.contains("No server"))
        } else {
            XCTFail("Expected failure")
        }
    }
}
