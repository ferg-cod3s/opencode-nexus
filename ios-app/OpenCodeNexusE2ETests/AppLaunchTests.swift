import XCTest

final class AppLaunchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAppLaunchesWithoutCrashing() {
        let app = XCUIApplication()
        app.launch()

        let exists = app.staticTexts["OpenCode Nexus"].waitForExistence(timeout: 10)
        XCTAssertTrue(exists, "App should display 'OpenCode Nexus' text on launch")
    }

    func testInitialViewShowsConnectView() {
        let app = XCUIApplication()
        app.launch()

        let serverURLField = app.textFields["http://localhost:4096"]
        let fieldExists = serverURLField.waitForExistence(timeout: 10)
        XCTAssertTrue(fieldExists, "ConnectView should display server URL text field")

        let connectButton = app.buttons["Connect"]
        let buttonExists = connectButton.waitForExistence(timeout: 5)
        XCTAssertTrue(buttonExists, "ConnectView should display Connect button")
    }
}
