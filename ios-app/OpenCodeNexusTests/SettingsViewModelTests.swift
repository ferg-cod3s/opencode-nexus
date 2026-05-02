import XCTest
@testable import OpenCodeNexus

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "settings")
        viewModel = SettingsViewModel()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "settings")
        viewModel = nil
        super.tearDown()
    }

    func testSettingsPersistence() {
        viewModel.reasoningSummariesEnabled = false
        viewModel.sessionProgressBarEnabled = false
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertFalse(freshVM.reasoningSummariesEnabled)
        XCTAssertFalse(freshVM.sessionProgressBarEnabled)
    }

    func testSettingsLoadDefaults() {
        XCTAssertTrue(viewModel.reasoningSummariesEnabled)
        XCTAssertTrue(viewModel.sessionProgressBarEnabled)
        XCTAssertFalse(viewModel.shellToolPartsExpanded)
        XCTAssertFalse(viewModel.editToolPartsExpanded)
        XCTAssertFalse(viewModel.autoAcceptPermissions)
        XCTAssertEqual(viewModel.selectedTheme, "Default")
        XCTAssertEqual(viewModel.selectedLanguage, "en")
    }

    func testSettingsSaveAndLoad() {
        viewModel.reasoningSummariesEnabled = false
        viewModel.shellToolPartsExpanded = true
        viewModel.editToolPartsExpanded = true
        viewModel.sessionProgressBarEnabled = false
        viewModel.autoAcceptPermissions = true
        viewModel.selectedTheme = "Custom"
        viewModel.selectedLanguage = "es"
        viewModel.visibleModels = ["gpt-4", "claude-3"]
        viewModel.hiddenModels = ["gpt-3.5"]
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertFalse(freshVM.reasoningSummariesEnabled)
        XCTAssertTrue(freshVM.shellToolPartsExpanded)
        XCTAssertTrue(freshVM.editToolPartsExpanded)
        XCTAssertFalse(freshVM.sessionProgressBarEnabled)
        XCTAssertTrue(freshVM.autoAcceptPermissions)
        XCTAssertEqual(freshVM.selectedTheme, "Custom")
        XCTAssertEqual(freshVM.selectedLanguage, "es")
        XCTAssertEqual(freshVM.visibleModels, ["gpt-4", "claude-3"])
        XCTAssertEqual(freshVM.hiddenModels, ["gpt-3.5"])
    }

    func testReasoningSummariesToggle() {
        XCTAssertTrue(viewModel.reasoningSummariesEnabled)
        viewModel.reasoningSummariesEnabled = false
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertFalse(freshVM.reasoningSummariesEnabled)
    }

    func testAutoAcceptPermissionsToggle() {
        XCTAssertFalse(viewModel.autoAcceptPermissions)
        viewModel.autoAcceptPermissions = true
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertTrue(freshVM.autoAcceptPermissions)
    }

    func testSessionProgressBarToggle() {
        XCTAssertTrue(viewModel.sessionProgressBarEnabled)
        viewModel.sessionProgressBarEnabled = false
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertFalse(freshVM.sessionProgressBarEnabled)
    }

    func testToolExpansionDefaults() {
        XCTAssertFalse(viewModel.shellToolPartsExpanded)
        XCTAssertFalse(viewModel.editToolPartsExpanded)

        viewModel.shellToolPartsExpanded = true
        viewModel.editToolPartsExpanded = true
        viewModel.save()

        let freshVM = SettingsViewModel()
        XCTAssertTrue(freshVM.shellToolPartsExpanded)
        XCTAssertTrue(freshVM.editToolPartsExpanded)
    }
}
