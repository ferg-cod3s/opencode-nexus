import Foundation

struct ServerConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var url: String
    var displayName: String?
    var username: String?
    var isDefault: Bool
    var hasCFAccess: Bool
    var hasPassword: Bool
    var lastHealthCheck: Date?
    var isHealthy: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, url, displayName, username, isDefault, hasCFAccess, hasPassword, lastHealthCheck, isHealthy
    }

    var password: String? {
        get { KeychainHelper.load(key: secretKey("password")) }
        set {
            if let newValue {
                KeychainHelper.save(key: secretKey("password"), value: newValue)
            } else {
                KeychainHelper.delete(key: secretKey("password"))
            }
        }
    }

    var cfAccessClientId: String? {
        get { KeychainHelper.load(key: secretKey("cfClientId")) }
        set {
            if let newValue {
                KeychainHelper.save(key: secretKey("cfClientId"), value: newValue)
            } else {
                KeychainHelper.delete(key: secretKey("cfClientId"))
            }
        }
    }

    var cfAccessClientSecret: String? {
        get { KeychainHelper.load(key: secretKey("cfClientSecret")) }
        set {
            if let newValue {
                KeychainHelper.save(key: secretKey("cfClientSecret"), value: newValue)
            } else {
                KeychainHelper.delete(key: secretKey("cfClientSecret"))
            }
        }
    }

    var displayLabel: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    init(
        id: UUID = UUID(),
        url: String,
        displayName: String? = nil,
        username: String? = nil,
        password: String? = nil,
        cfAccessClientId: String? = nil,
        cfAccessClientSecret: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.username = username
        self.isDefault = isDefault
        self.hasPassword = password != nil
        self.hasCFAccess = cfAccessClientId != nil

        if let password { self.password = password }
        if let cfAccessClientId { self.cfAccessClientId = cfAccessClientId }
        if let cfAccessClientSecret { self.cfAccessClientSecret = cfAccessClientSecret }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        hasPassword = try container.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        hasCFAccess = try container.decodeIfPresent(Bool.self, forKey: .hasCFAccess) ?? false
        lastHealthCheck = try container.decodeIfPresent(Date.self, forKey: .lastHealthCheck)
        isHealthy = try container.decodeIfPresent(Bool.self, forKey: .isHealthy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(hasPassword, forKey: .hasPassword)
        try container.encode(hasCFAccess, forKey: .hasCFAccess)
        try container.encodeIfPresent(lastHealthCheck, forKey: .lastHealthCheck)
        try container.encodeIfPresent(isHealthy, forKey: .isHealthy)
    }

    func secrets() -> (password: String?, cfClientId: String?, cfClientSecret: String?) {
        (password: hasPassword ? password : nil,
         cfClientId: hasCFAccess ? cfAccessClientId : nil,
         cfClientSecret: hasCFAccess ? cfAccessClientSecret : nil)
    }

    func deleteSecrets() {
        KeychainHelper.delete(key: secretKey("password"))
        KeychainHelper.delete(key: secretKey("cfClientId"))
        KeychainHelper.delete(key: secretKey("cfClientSecret"))
    }

    static func == (lhs: ServerConfig, rhs: ServerConfig) -> Bool {
        lhs.id == rhs.id
    }

    private func secretKey(_ field: String) -> String {
        "serverConfig.\(id.uuidString).\(field)"
    }
}
