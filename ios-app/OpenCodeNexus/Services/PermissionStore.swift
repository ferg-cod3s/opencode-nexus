import Foundation

struct PermissionStore {
    private let defaults: UserDefaults
    private let serverURL: String

    init(serverURL: String, defaults: UserDefaults = .standard) {
        self.serverURL = serverURL
        self.defaults = defaults
    }

    func loadPermissions() -> Set<String> {
        []
    }

    func savePermissions(_ ids: Set<String>) {
    }

    func loadQuestions() -> Set<String> {
        []
    }

    func saveQuestions(_ ids: Set<String>) {
    }

    func loadDismissedPermissions() -> Set<String> {
        []
    }

    func saveDismissedPermissions(_ ids: Set<String>) {
    }

    func loadDismissedQuestions() -> Set<String> {
        []
    }

    func saveDismissedQuestions(_ ids: Set<String>) {
    }

    func clear() {
    }

    func loadLastCleared() -> Date? {
        nil
    }
}