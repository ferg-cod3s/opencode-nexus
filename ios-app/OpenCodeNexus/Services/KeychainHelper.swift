import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.agentic-codeflow.opencode-nexus"

    #if DEBUG
    nonisolated(unsafe) private static let inMemoryStore = NSMutableDictionary()
    nonisolated(unsafe) private static var useInMemory = false

    static func setInMemoryMode(_ enabled: Bool) {
        useInMemory = enabled
    }
    #endif

    static func save(key: String, value: String) {
        #if DEBUG
        if useInMemory {
            inMemoryStore[key] = value
            return
        }
        #endif
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        #if DEBUG
        if useInMemory {
            return inMemoryStore[key] as? String
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        #if DEBUG
        if useInMemory {
            inMemoryStore.removeObject(forKey: key)
            return
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
