import XCTest
@testable import OpenCodeNexus

@MainActor
final class UpdateCheckerTests: XCTestCase {

    private var checker: UpdateChecker!

    override func setUp() {
        super.setUp()
        checker = UpdateChecker.shared
    }

    override func tearDown() {
        checker = nil
        super.tearDown()
    }

    func testVersionComparisonMajorUpdate() {
        XCTAssertTrue(checker.isNewerVersion("2.0.0", than: "1.0.0"))
    }

    func testVersionComparisonMinorUpdate() {
        XCTAssertTrue(checker.isNewerVersion("1.1.0", than: "1.0.0"))
    }

    func testVersionComparisonPatchUpdate() {
        XCTAssertTrue(checker.isNewerVersion("1.0.1", than: "1.0.0"))
    }

    func testVersionComparisonNoUpdate() {
        XCTAssertFalse(checker.isNewerVersion("1.0.0", than: "1.0.0"))
    }

    func testVersionComparisonOlderVersion() {
        XCTAssertFalse(checker.isNewerVersion("0.9.9", than: "1.0.0"))
    }

    func testVersionComparisonDifferentLengths() {
        XCTAssertTrue(checker.isNewerVersion("1.1", than: "1.0.0"))
        XCTAssertFalse(checker.isNewerVersion("1.0", than: "1.0.1"))
    }

    func testNoUpdateAvailable() async throws {
        let mockClient = MockHealthCheckable(healthResponse: HealthResponse(healthy: true, version: "1.0.0"))
        let result = await checker.checkForUpdate(client: mockClient)
        XCTAssertNil(result)
    }

    func testUpdateAvailable() async throws {
        let mockClient = MockHealthCheckable(healthResponse: HealthResponse(healthy: true, version: "99.0.0"))
        let result = await checker.checkForUpdate(client: mockClient)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.serverVersion, "99.0.0")
    }

    func testHealthCheckFailure() async throws {
        let mockClient = MockHealthCheckable(shouldFail: true)
        let result = await checker.checkForUpdate(client: mockClient)
        XCTAssertNil(result)
    }
}

private final class MockHealthCheckable: HealthCheckable {
    private let healthResponse: HealthResponse?
    private let shouldFail: Bool

    init(healthResponse: HealthResponse? = nil, shouldFail: Bool = false) {
        self.healthResponse = healthResponse
        self.shouldFail = shouldFail
    }

    func healthCheck() async throws -> HealthResponse {
        if shouldFail {
            throw URLError(.badServerResponse)
        }
        guard let response = healthResponse else {
            throw URLError(.badServerResponse)
        }
        return response
    }
}
