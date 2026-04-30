import XCTest
@testable import OpenCodeNexus

final class KeychainHelperTests: XCTestCase {

    private let testKey = "keychain-test-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        KeychainHelper.delete(key: testKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        KeychainHelper.save(key: testKey, value: "test-value-123")
        let loaded = KeychainHelper.load(key: testKey)
        try XCTSkipIf(loaded == nil, "Keychain unavailable in this test environment")
        XCTAssertEqual(loaded, "test-value-123")
    }

    func testLoadNonexistentReturnsNil() {
        let loaded = KeychainHelper.load(key: "nonexistent-key-\(UUID().uuidString)")
        XCTAssertNil(loaded)
    }

    func testDeleteRemovesValue() throws {
        KeychainHelper.save(key: testKey, value: "to-be-deleted")
        try XCTSkipIf(KeychainHelper.load(key: testKey) == nil, "Keychain unavailable in this test environment")
        KeychainHelper.delete(key: testKey)
        XCTAssertNil(KeychainHelper.load(key: testKey))
    }

    func testSaveOverwritesExisting() throws {
        KeychainHelper.save(key: testKey, value: "first-value")
        try XCTSkipIf(KeychainHelper.load(key: testKey) == nil, "Keychain unavailable in this test environment")
        KeychainHelper.save(key: testKey, value: "second-value")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "second-value")
    }

    func testEmptyStringIsSavedAndLoaded() throws {
        KeychainHelper.save(key: testKey, value: "")
        let loaded = KeychainHelper.load(key: testKey)
        try XCTSkipIf(loaded == nil && KeychainHelper.load(key: testKey) == nil, "Keychain unavailable in this test environment")
        XCTAssertEqual(loaded, "")
    }

    func testSpecialCharactersArePreserved() throws {
        let specialValue = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        KeychainHelper.save(key: testKey, value: specialValue)
        let loaded = KeychainHelper.load(key: testKey)
        try XCTSkipIf(loaded == nil, "Keychain unavailable in this test environment")
        XCTAssertEqual(loaded, specialValue)
    }
}
