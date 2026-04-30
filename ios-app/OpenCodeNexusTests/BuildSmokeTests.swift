import XCTest
@testable import OpenCodeNexus

final class BuildSmokeTests: XCTestCase {
    func testOpenCodeErrorDescription() {
        XCTAssertEqual(OpenCodeError.invalidResponse.errorDescription, "Invalid server response")
    }
}
