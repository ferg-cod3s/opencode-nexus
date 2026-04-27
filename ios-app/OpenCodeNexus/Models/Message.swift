import Foundation

struct Message: Codable, Identifiable {
    let info: MessageInfo
    let parts: [Part]

    var id: String { info.id }
}

struct MessageInfo: Codable {
    let id: String
    let role: String
    let time: TimeInfo
}

struct Part: Codable, Identifiable {
    let type: String
    let text: String?

    var id: String { "\(type)-\(text.map { String($0.prefix(20)) } ?? UUID().uuidString)" }

    var displayText: String {
        text ?? ""
    }
}
