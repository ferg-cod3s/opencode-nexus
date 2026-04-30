import XCTest
@testable import OpenCodeNexus

final class KeychainHelperTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clean up any test keys before each test
        KeychainHelper.delete(key: "test-key")
    }
    
    override func tearDown() {
        // Clean up after each test
        KeychainHelper.delete(key: "test-key")
        super.tearDown()
    }
    
    func testSaveAndLoad() {
        let testValue = "test-value-123"
        KeychainHelper.save(key: "test-key", value: testValue)
        let loaded = KeychainHelper.load(key: "test-key")
        XCTAssertEqual(loaded, testValue)
    }
    
    func testLoadNonexistentReturnsNil() {
        let loaded = KeychainHelper.load(key: "nonexistent-key")
        XCTAssertNil(loaded)
    }
    
    func testDeleteRemovesValue() {
        let testValue = "to-be-deleted"
        KeychainHelper.save(key: "test-key", value: testValue)
        XCTAssertNotNil(KeychainHelper.load(key: "test-key"))
        
        KeychainHelper.delete(key: "test-key")
        XCTAssertNil(KeychainHelper.load(key: "test-key"))
    }
    
    func testSaveOverwritesExisting() {
        let firstValue = "first-value"
        let secondValue = "second-value"
        
        KeychainHelper.save(key: "test-key", value: firstValue)
        XCTAssertEqual(KeychainHelper.load(key: "test-key"), firstValue)
        
        KeychainHelper.save(key: "test-key", value: secondValue)
        XCTAssertEqual(KeychainHelper.load(key: "test-key"), secondValue)
        XCTAssertNotEqual(KeychainHelper.load(key: "test-key"), firstValue)
    }
    
    func testEmptyStringIsSavedAndLoaded() {
        let emptyValue = ""
        KeychainHelper.save(key: "test-key", value: emptyValue)
        let loaded = KeychainHelper.load(key: "test-key")
        XCTAssertEqual(loaded, emptyValue)
    }
    
    func testSpecialCharactersArePreserved() {
        let specialValue = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        KeychainHelper.save(key: "test-key", value: specialValue)
        let loaded = KeychainHelper.load(key: "test-key")
        XCTAssertEqual(loaded, specialValue)
    }
}