import XCTest
@testable import OpenCodeNexus

final class ServerConfigTests: XCTestCase {

    func testInitSetsDefaultValues() {
        let config = ServerConfig(url: "http://localhost:4096")
        XCTAssertFalse(config.isDefault)
        XCTAssertFalse(config.hasPassword)
        XCTAssertFalse(config.hasCFAccess)
        XCTAssertNil(config.displayName)
        XCTAssertNil(config.username)
    }

    func testInitWithPasswordSetsHasPassword() throws {
        let config = ServerConfig(url: "http://localhost:4096", password: "secret")
        XCTAssertTrue(config.hasPassword)
        let loaded = config.password
        try XCTSkipIf(loaded == nil, "Keychain unavailable in test environment")
        XCTAssertEqual(loaded, "secret")
        KeychainHelper.delete(key: "serverConfig.\(config.id.uuidString).password")
    }

    func testInitWithCFAccessSetsHasCFAccess() throws {
        let config = ServerConfig(url: "http://localhost:4096",
                                   cfAccessClientId: "cf-id",
                                   cfAccessClientSecret: "cf-secret")
        XCTAssertTrue(config.hasCFAccess)
        let loaded = config.cfAccessClientId
        try XCTSkipIf(loaded == nil, "Keychain unavailable in test environment")
        XCTAssertEqual(loaded, "cf-id")
        KeychainHelper.delete(key: "serverConfig.\(config.id.uuidString).cfClientId")
        KeychainHelper.delete(key: "serverConfig.\(config.id.uuidString).cfClientSecret")
    }

    func testDisplayLabelWithDisplayName() {
        let config = ServerConfig(url: "http://localhost:4096", displayName: "My Server")
        XCTAssertEqual(config.displayLabel, "My Server")
    }

    func testDisplayLabelStripsProtocol() {
        let config = ServerConfig(url: "https://example.com/")
        XCTAssertEqual(config.displayLabel, "example.com")
    }

    func testDisplayLabelStripsHTTP() {
        let config = ServerConfig(url: "http://localhost:4096")
        XCTAssertEqual(config.displayLabel, "localhost:4096")
    }

    func testDisplayLabelFallsBackToURL() {
        let config = ServerConfig(url: "https://my-server.com/path/")
        XCTAssertEqual(config.displayLabel, "my-server.com/path")
    }

    func testSecretsReturnsNilWhenNoFlags() {
        let config = ServerConfig(url: "http://localhost:4096")
        let secrets = config.secrets()
        XCTAssertNil(secrets.password)
        XCTAssertNil(secrets.cfClientId)
        XCTAssertNil(secrets.cfClientSecret)
    }

    func testSecretsReturnsValuesWhenFlagsTrue() throws {
        let config = ServerConfig(url: "http://localhost:4096",
                                   password: "pw",
                                   cfAccessClientId: "cf-id",
                                   cfAccessClientSecret: "cf-secret")
        let secrets = config.secrets()
        try XCTSkipIf(secrets.password == nil, "Keychain unavailable in test environment")
        XCTAssertEqual(secrets.password, "pw")
        XCTAssertEqual(secrets.cfClientId, "cf-id")
        XCTAssertEqual(secrets.cfClientSecret, "cf-secret")
        config.deleteSecrets()
    }

    func testCodableRoundtrip() throws {
        let config = ServerConfig(url: "http://localhost:4096",
                                   displayName: "Test",
                                   username: "user",
                                   isDefault: true)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)
        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.url, config.url)
        XCTAssertEqual(decoded.displayName, config.displayName)
        XCTAssertEqual(decoded.username, config.username)
        XCTAssertEqual(decoded.isDefault, config.isDefault)
    }

    func testEqualityByID() {
        let id = UUID()
        let a = ServerConfig(id: id, url: "http://a")
        let b = ServerConfig(id: id, url: "http://b")
        XCTAssertEqual(a, b)
    }

    func testInequalityByDifferentID() {
        let a = ServerConfig(url: "http://a")
        let b = ServerConfig(url: "http://a")
        XCTAssertNotEqual(a, b)
    }

    func testDeleteSecretsClearsKeychain() throws {
        let config = ServerConfig(url: "http://localhost:4096",
                                   password: "pw",
                                   cfAccessClientId: "cf-id",
                                   cfAccessClientSecret: "cf-secret")
        config.deleteSecrets()
        XCTAssertNil(config.password)
        XCTAssertNil(config.cfAccessClientId)
        XCTAssertNil(config.cfAccessClientSecret)
    }

    func testPasswordNilClearsKeychain() {
        var config = ServerConfig(url: "http://localhost:4096", password: "pw")
        config.password = nil
        XCTAssertNil(KeychainHelper.load(key: "serverConfig.\(config.id.uuidString).password"))
    }
}
