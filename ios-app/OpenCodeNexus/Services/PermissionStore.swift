import Foundation

struct PermissionStore {
    private let defaults: UserDefaults
    private let serverURL: String

    var permissionsKey: String { "opencode-nexus.responded-permissions.\(serverURL)" }
    var questionsKey: String { "opencode-nexus.responded-questions.\(serverURL)" }
    var dismissedPermissionsKey: String { "opencode-nexus.dismissed-permissions.\(serverURL)" }
    var dismissedQuestionsKey: String { "opencode-nexus.dismissed-questions.\(serverURL)" }
    var lastClearedKey: String { "opencode-nexus.last-cleared.\(serverURL)" }

    init(serverURL: String, defaults: UserDefaults = .standard) {
        self.serverURL = serverURL
        self.defaults = defaults
    }

    func loadPermissions() -> Set<String> {
        guard let data = defaults.data(forKey: permissionsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    func savePermissions(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        defaults.set(data, forKey: permissionsKey)
    }

    func loadQuestions() -> Set<String> {
        guard let data = defaults.data(forKey: questionsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    func saveQuestions(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        defaults.set(data, forKey: questionsKey)
    }

    func loadDismissedPermissions() -> Set<String> {
        guard let data = defaults.data(forKey: dismissedPermissionsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    func saveDismissedPermissions(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        defaults.set(data, forKey: dismissedPermissionsKey)
    }

    func loadDismissedQuestions() -> Set<String> {
        guard let data = defaults.data(forKey: dismissedQuestionsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    func saveDismissedQuestions(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(Array(ids)) else { return }
        defaults.set(data, forKey: dismissedQuestionsKey)
    }

    func clear() {
        defaults.removeObject(forKey: permissionsKey)
        defaults.removeObject(forKey: questionsKey)
        defaults.removeObject(forKey: dismissedPermissionsKey)
        defaults.removeObject(forKey: dismissedQuestionsKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastClearedKey)
    }

    func loadLastCleared() -> Date? {
        let timestamp = defaults.double(forKey: lastClearedKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}