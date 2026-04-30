import XCTest
@testable import OpenCodeNexus

@MainActor
final class ServerStoreTests: XCTestCase {
    private var store: ServerStore!
    private let serversKey = "opencode-nexus.servers.v1"
    private let activeKey = "opencode-nexus.active-server"
    private let migratedKey = "opencode-nexus.migrated-v1"

    nonisolated private func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: serversKey)
        UserDefaults.standard.removeObject(forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: migratedKey)
        UserDefaults.standard.removeObject(forKey: "serverURL")
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.password")
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.cfAccessClientId")
        UserDefaults.standard.removeObject(forKey: "opencode-nexus.cfAccessClientSecret")
    }

    override func setUp() {
        super.setUp()
        resetDefaults()
        UserDefaults.standard.set(true, forKey: migratedKey)
        store = ServerStore()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    func testInitWithEmptyUserDefaults() {
        XCTAssertTrue(store.servers.isEmpty)
        XCTAssertNil(store.activeServerId)
    }

    func testAddServerAppendsToList() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.servers[0].id, config.id)
    }

    func testAddServerUpdatesExistingById() {
        let id = UUID()
        let config1 = ServerConfig(id: id, url: "http://localhost:4096")
        let config2 = ServerConfig(id: id, url: "http://localhost:8080")
        store.addServer(config1)
        store.addServer(config2)
        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.servers[0].url, "http://localhost:8080")
    }

    func testAddServerSetsDefaultClearsOthers() {
        let config1 = ServerConfig(url: "http://localhost:4096", isDefault: true)
        let config2 = ServerConfig(url: "http://localhost:8080", isDefault: true)
        store.addServer(config1)
        store.addServer(config2)
        XCTAssertEqual(store.servers.filter(\.isDefault).count, 1)
        XCTAssertTrue(store.servers[1].isDefault)
        XCTAssertFalse(store.servers[0].isDefault)
    }

    func testUpdateServerModifiesExisting() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        let updated = ServerConfig(id: config.id, url: "http://localhost:9999", displayName: "Updated")
        store.updateServer(updated)
        XCTAssertEqual(store.servers[0].url, "http://localhost:9999")
        XCTAssertEqual(store.servers[0].displayName, "Updated")
    }

    func testUpdateServerNonexistentIsNoOp() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        let ghost = ServerConfig(id: UUID(), url: "http://ghost")
        store.updateServer(ghost)
        XCTAssertEqual(store.servers.count, 1)
    }

    func testRemoveServerDeletesFromList() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        store.removeServer(id: config.id)
        XCTAssertTrue(store.servers.isEmpty)
    }

    func testRemoveServerPromotesNewDefault() {
        let config1 = ServerConfig(url: "http://localhost:4096", isDefault: true)
        let config2 = ServerConfig(url: "http://localhost:8080")
        store.addServer(config1)
        store.addServer(config2)
        store.removeServer(id: config1.id)
        XCTAssertTrue(store.servers[0].isDefault)
    }

    func testRemoveServerResetsActiveId() {
        let config1 = ServerConfig(url: "http://localhost:4096")
        let config2 = ServerConfig(url: "http://localhost:8080")
        store.addServer(config1)
        store.addServer(config2)
        store.setActive(id: config1.id)
        store.removeServer(id: config1.id)
        XCTAssertEqual(store.activeServerId, config2.id)
    }

    func testSetActiveSetsId() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        store.setActive(id: config.id)
        XCTAssertEqual(store.activeServerId, config.id)
    }

    func testSetActiveIgnoresUnknownId() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        store.setActive(id: UUID())
        XCTAssertNotEqual(store.activeServerId, config.id)
    }

    func testSetDefaultUpdatesFlags() {
        let config1 = ServerConfig(url: "http://localhost:4096", isDefault: true)
        let config2 = ServerConfig(url: "http://localhost:8080")
        store.addServer(config1)
        store.addServer(config2)
        store.setDefault(id: config2.id)
        XCTAssertFalse(store.servers[0].isDefault)
        XCTAssertTrue(store.servers[1].isDefault)
    }

    func testUpdateHealthSetsProperties() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        store.updateHealth(id: config.id, healthy: true)
        XCTAssertTrue(store.servers[0].isHealthy == true)
        XCTAssertNotNil(store.servers[0].lastHealthCheck)
    }

    func testActiveServerReturnsFirstWhenNoId() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        XCTAssertNotNil(store.activeServer)
        XCTAssertEqual(store.activeServer?.id, config.id)
    }

    func testDefaultServerReturnsFirstDefault() {
        let config1 = ServerConfig(url: "http://localhost:4096")
        let config2 = ServerConfig(url: "http://localhost:8080", isDefault: true)
        store.addServer(config1)
        store.addServer(config2)
        XCTAssertEqual(store.defaultServer?.id, config2.id)
    }

    func testDefaultServerReturnsFirstWhenNoDefault() {
        let config = ServerConfig(url: "http://localhost:4096")
        store.addServer(config)
        XCTAssertEqual(store.defaultServer?.id, config.id)
    }

    func testPersistenceViaUserDefaults() {
        let config = ServerConfig(url: "http://localhost:4096", displayName: "Test")
        store.addServer(config)
        let store2 = ServerStore()
        XCTAssertEqual(store2.servers.count, 1)
        XCTAssertEqual(store2.servers[0].url, "http://localhost:4096")
        XCTAssertEqual(store2.servers[0].displayName, "Test")
    }
}
