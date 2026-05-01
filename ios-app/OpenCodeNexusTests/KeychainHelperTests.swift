import XCTest
@testable import OpenCodeNexus

final class KeychainHelperTests: XCTestCase {

    private let testKey = "keychain-test-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        KeychainHelper.setInMemoryMode(true)
        KeychainHelper.delete(key: testKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndLoad() {
        KeychainHelper.save(key: testKey, value: "test-value-123")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "test-value-123")
    }

    func testLoadNonexistentReturnsNil() {
        let loaded = KeychainHelper.load(key: "nonexistent-key-\(UUID().uuidString)")
        XCTAssertNil(loaded)
    }

    func testDeleteRemovesValue() {
        KeychainHelper.save(key: testKey, value: "to-be-deleted")
        KeychainHelper.delete(key: testKey)
        XCTAssertNil(KeychainHelper.load(key: testKey))
    }

    func testSaveOverwritesExisting() {
        KeychainHelper.save(key: testKey, value: "first-value")
        KeychainHelper.save(key: testKey, value: "second-value")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "second-value")
    }

    func testEmptyStringIsSavedAndLoaded() {
        KeychainHelper.save(key: testKey, value: "")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "")
    }

    func testSpecialCharactersArePreserved() {
        let specialValue = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        KeychainHelper.save(key: testKey, value: specialValue)
        XCTAssertEqual(KeychainHelper.load(key: testKey), specialValue)
    }
}
