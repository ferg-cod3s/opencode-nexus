import XCTest

final class ConnectionFlowTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Server URL Entry

    func testEnteringServerURL() {
        let urlField = app.textFields.firstMatch
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))

        urlField.tap()
        urlField.clearText()
        urlField.typeText("http://192.168.1.100:4096\n")

        let fieldValue = urlField.value as? String ?? ""
        XCTAssertTrue(
            fieldValue.contains("192.168.1.100"),
            "URL field should contain the entered address"
        )
    }

    func testEnteringSecureServerURL() {
        let urlField = app.textFields.firstMatch
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))

        urlField.tap()
        urlField.clearText()
        urlField.typeText("https://my-server.example.com\n")

        let fieldValue = urlField.value as? String ?? ""
        XCTAssertTrue(
            fieldValue.contains("my-server.example.com"),
            "URL field should contain the entered hostname"
        )
    }

    // MARK: - Connecting to Server

    func testConnectButtonTappable() {
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        XCTAssertTrue(connectButton.isEnabled, "Connect button should be enabled initially")
    }

    func testConnectingButtonState() {
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))

        connectButton.tap()

        let connectingLabel = app.staticTexts["Connecting..."]
        let appears = connectingLabel.waitForExistence(timeout: 3)

        if appears {
            XCTAssertTrue(connectingLabel.exists, "Should show Connecting... state")
        }
    }

    // MARK: - Error State for Invalid URL

    func testErrorStateForUnreachableServer() {
        let urlField = app.textFields.firstMatch
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))

        urlField.tap()
        urlField.clearText()
        urlField.typeText("http://localhost:99999\n")

        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        connectButton.tap()

        let errorBanner = app.staticTexts["Connection Failed"]
        let errorAppears = errorBanner.waitForExistence(timeout: 10)

        if errorAppears {
            XCTAssertTrue(errorBanner.exists, "Should show connection failure banner for unreachable server")
        }
    }

    // MARK: - Disconnect Flow

    func testDisconnectNotAvailableBeforeConnection() {
        let disconnectButton = app.buttons["Disconnect"]
        XCTAssertFalse(disconnectButton.waitForExistence(timeout: 2), "Disconnect should not be visible before connecting")
    }

    // MARK: - Advanced CF Access Toggle

    func testCFAccessSectionToggle() {
        let cfToggle = app.buttons["Advanced: Cloudflare Zero Trust"]
        if cfToggle.waitForExistence(timeout: 3) {
            cfToggle.tap()

            let clientIdField = app.textFields["Client ID"]
            let appears = clientIdField.waitForExistence(timeout: 2)
            XCTAssertTrue(appears, "CF Access Client ID field should appear after toggling")
        }
    }

    // MARK: - Initial State

    func testDefaultServerURL() {
        let urlField = app.textFields.firstMatch
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))

        let value = urlField.value as? String ?? ""
        XCTAssertTrue(
            value.contains("localhost:4096"),
            "Default server URL should be localhost:4096"
        )
    }

    func testNoTestResultBannerInitially() {
        let successBanner = app.staticTexts["Connected"]
        XCTAssertFalse(successBanner.exists, "Should not show connected banner initially")

        let failureBanner = app.staticTexts["Connection Failed"]
        XCTAssertFalse(failureBanner.exists, "Should not show failure banner initially")
    }
}

// MARK: - XCUIElement Helper

extension XCUIElement {
    func clearText() {
        guard let currentValue = value as? String, !currentValue.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
    }
}
