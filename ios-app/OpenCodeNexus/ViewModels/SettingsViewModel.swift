import Foundation
import SwiftUI

@MainActor
@Observable
class SettingsViewModel {
    var reasoningSummariesEnabled = true
    var shellToolPartsExpanded = false
    var editToolPartsExpanded = false
    var sessionProgressBarEnabled = true
    var autoAcceptPermissions = false
    var selectedTheme = "Default"
    var selectedLanguage = "en"
    var visibleModels: [String] = []
    var hiddenModels: [String] = []
    
    private let defaultsKey = "settings"
    
    init() {
        load()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let settings = try? JSONDecoder().decode(SavedSettings.self, from: data) {
            reasoningSummariesEnabled = settings.reasoningSummariesEnabled
            shellToolPartsExpanded = settings.shellToolPartsExpanded
            editToolPartsExpanded = settings.editToolPartsExpanded
            sessionProgressBarEnabled = settings.sessionProgressBarEnabled
            autoAcceptPermissions = settings.autoAcceptPermissions
            selectedTheme = settings.selectedTheme
            selectedLanguage = settings.selectedLanguage
            visibleModels = settings.visibleModels
            hiddenModels = settings.hiddenModels
        }
    }
    
    func save() {
        let settings = SavedSettings(
            reasoningSummariesEnabled: reasoningSummariesEnabled,
            shellToolPartsExpanded: shellToolPartsExpanded,
            editToolPartsExpanded: editToolPartsExpanded,
            sessionProgressBarEnabled: sessionProgressBarEnabled,
            autoAcceptPermissions: autoAcceptPermissions,
            selectedTheme: selectedTheme,
            selectedLanguage: selectedLanguage,
            visibleModels: visibleModels,
            hiddenModels: hiddenModels
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func syncWithServer(client: OpenCodeClient) async {
        do {
            let config = try await client.getConfig()
            if let value = config.reasoningSummaries { reasoningSummariesEnabled = value }
            if let value = config.shellToolParts { shellToolPartsExpanded = value }
            if let value = config.editToolParts { editToolPartsExpanded = value }
            if let value = config.sessionProgressBar { sessionProgressBarEnabled = value }
            if let value = config.autoAcceptPermissions { autoAcceptPermissions = value }
            if let value = config.theme { selectedTheme = value }
            if let value = config.language { selectedLanguage = value }
            if let value = config.visibleModels { visibleModels = value }
            if let value = config.hiddenModels { hiddenModels = value }
            save()
        } catch {
            print("Failed to sync settings with server: \(error)")
        }
    }
    
    func pushToServer(client: OpenCodeClient) async {
        let config = ConfigUpdate(
            theme: selectedTheme,
            language: selectedLanguage,
            autoAcceptPermissions: autoAcceptPermissions,
            reasoningSummaries: reasoningSummariesEnabled,
            shellToolParts: shellToolPartsExpanded,
            editToolParts: editToolPartsExpanded,
            sessionProgressBar: sessionProgressBarEnabled,
            visibleModels: visibleModels.isEmpty ? nil : visibleModels,
            hiddenModels: hiddenModels.isEmpty ? nil : hiddenModels
        )
        do {
            try await client.updateConfig(config)
        } catch {
            print("Failed to push settings to server: \(error)")
        }
    }
}

struct SavedSettings: Codable {
    var reasoningSummariesEnabled: Bool
    var shellToolPartsExpanded: Bool
    var editToolPartsExpanded: Bool
    var sessionProgressBarEnabled: Bool
    var autoAcceptPermissions: Bool
    var selectedTheme: String
    var selectedLanguage: String
    var visibleModels: [String]
    var hiddenModels: [String]
}
