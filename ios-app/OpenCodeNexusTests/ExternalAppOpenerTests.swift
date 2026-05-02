import XCTest
@testable import OpenCodeNexus

@MainActor
final class ExternalAppOpenerTests: XCTestCase {

    private var opener: ExternalAppOpener!

    override func setUp() {
        super.setUp()
        opener = ExternalAppOpener.shared
    }

    override func tearDown() {
        opener = nil
        super.tearDown()
    }

    func testAllAppsHaveURLSchemes() {
        for app in ExternalApp.allCases {
            XCTAssertFalse(app.urlScheme.isEmpty, "\(app.rawValue) should have a URL scheme")
        }
    }

    func testAllAppsHaveDisplayNames() {
        for app in ExternalApp.allCases {
            XCTAssertFalse(app.displayName.isEmpty, "\(app.rawValue) should have a display name")
        }
    }

    func testVSCodeURLGeneration() {
        let url = ExternalApp.vscode.urlForFile(path: "/Users/test/project/file.swift")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "vscode://file//Users/test/project/file.swift")
    }

    func testCursorURLGeneration() {
        let url = ExternalApp.cursor.urlForFile(path: "/Users/test/project/file.swift")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "cursor://file//Users/test/project/file.swift")
    }

    func testZedURLGeneration() {
        let url = ExternalApp.zed.urlForFile(path: "/Users/test/project/file.swift")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "zed://file//Users/test/project/file.swift")
    }

    func testFilesURLGeneration() {
        let url = ExternalApp.files.urlForFile(path: "/Users/test/project")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "shareddocuments:///Users/test/project")
    }

    func testAvailableAppsReturnsArray() {
        let apps = opener.availableApps()
        XCTAssertNotNil(apps)
    }
}
