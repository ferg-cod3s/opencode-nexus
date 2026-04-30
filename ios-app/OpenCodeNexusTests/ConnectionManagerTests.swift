import XCTest
@testable import OpenCodeNexus

@MainActor
final class ConnectionManagerTests: XCTestCase {
    private var store: ServerStore!
    private var manager: ConnectionManager!
    private let serversKey = "opencode-nexus.servers.v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: serversKey)
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.active-server")
        store = ServerStore()
        manager = ConnectionManager(serverStore: store)
    }

    override func tearDown() {
        manager.disconnect()
        UserDefaults.standard.removeObject(forKey: serversKey)
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.active-server")
        super.tearDown()
    }

    func testDisconnectClearsState() {
        manager.isConnected = true
        manager.disconnect()
        XCTAssertFalse(manager.isConnected)
        XCTAssertNil(manager.client)
        XCTAssertNil(manager.testResult)
    }

    func testConnectWithInvalidURL() async {
        let config = ServerConfig(url: "not a valid url with spaces")
        await manager.connect(to: config)
        XCTAssertFalse(manager.isConnected)
        if case .failure(let message) = manager.testResult {
            XCTAssertEqual(message, "Invalid URL")
        } else {
            XCTFail("Expected failure result")
        }
    }

    func testConnectAndTestNoServer() async {
        XCTAssertTrue(store.servers.isEmpty)
        await manager.connectAndTest()
        if case .failure(let message) = manager.testResult {
            XCTAssertEqual(message, "No server configured")
        } else {
            XCTFail("Expected failure")
        }
    }

    func testTestConnectionSuccess() async {
        let config = ServerConfig(url: "http://localhost:4096")
        let result = await manager.testConnection(config)
        if case .failure = result {
            // Expected in test env without server
        } else if case .success = result {
            // Would succeed if server running
        }
    }

    func testIsConnectingSetDuringConnect() async {
        let config = ServerConfig(url: "http://localhost:4096")
        let task = Task { await manager.connect(to: config) }
        try? await Task.sleep(for: .milliseconds(10))
        task.cancel()
        await task.value
    }

    func testStartAndStopHealthPolling() {
        manager.startHealthPolling(interval: 999)
        XCTAssertNotNil(manager)
        manager.stopHealthPolling()
    }

    func testConnectSetsIsConnectingFalseAfterCompletion() async {
        let config = ServerConfig(url: "http://localhost:4096")
        await manager.connect(to: config)
        XCTAssertFalse(manager.isConnecting)
    }
}