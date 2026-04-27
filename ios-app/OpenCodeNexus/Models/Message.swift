import Foundation

struct Message: Codable, Identifiable {
    let info: MessageInfo
    let parts: [Part]

    var id: String { info.id }
}

struct MessageInfo: Codable, Identifiable {
    let id: String
    let role: String
    let time: TimeInfo
    let agent: String?
    let model: ModelRef?
    let system: String?
    let summary: MessageSummary?
    let sessionID: String?
    let parentID: String?
    let mode: String?
    let cost: Double?
    let tokens: TokenInfo?

    struct ModelRef: Codable {
        let providerID: String?
        let modelID: String?
    }

    struct MessageSummary: Codable {
        let diffs: [DiffInfo]?
    }

    struct DiffInfo: Codable {}
}

struct TokenInfo: Codable {
    let total: Int?
    let input: Int?
    let output: Int?
    let reasoning: Int?
}

struct Part: Codable, Identifiable {
    let id: String?
    let type: String
    let text: String?
    let sessionID: String?
    let messageID: String?

    var displayText: String {
        text ?? ""
    }
}
