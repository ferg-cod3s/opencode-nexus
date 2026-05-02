import Foundation

struct SSEEvent: Decodable, Sendable, Equatable {
    let directory: String?
    let project: String?
    let workspace: String?
    let payload: Payload?
    let syncEvent: SyncPayload?

    struct Payload: Decodable, Sendable, Equatable {
        let type: String
        let properties: [String: JSONValue]?
    }

    struct SyncPayload: Decodable, Sendable, Equatable {
        let type: String
        let id: String?
        let seq: Int?
        let aggregateID: String?
        let data: [String: JSONValue]?
    }

    var eventType: String {
        if let payload { return payload.type }
        if let syncEvent { return syncEvent.type }
        return "unknown"
    }

    var properties: [String: JSONValue]? {
        if let payload { return payload.properties }
        if let syncEvent { return syncEvent.data }
        return nil
    }

    var sessionID: String? {
        properties?["sessionID"]?.stringValue
    }

    var messageID: String? {
        properties?["messageID"]?.stringValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        directory = try? container.decodeIfPresent(String.self, forKey: .directory)
        project = try? container.decodeIfPresent(String.self, forKey: .project)
        workspace = try? container.decodeIfPresent(String.self, forKey: .workspace)

        if let payload = try? container.decodeIfPresent(Payload.self, forKey: .payload) {
            self.payload = payload
            self.syncEvent = nil
        } else if let syncEvent = try? container.decodeIfPresent(SyncPayload.self, forKey: .payload) {
            self.payload = nil
            self.syncEvent = syncEvent
        } else {
            self.payload = nil
            self.syncEvent = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case directory, project, workspace, payload
    }
}

enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var displayText: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .bool(let value): String(value)
        case .object(let value): value.map { "\($0): \($1.displayText)" }.sorted().joined(separator: ", ")
        case .array(let value): value.map(\.displayText).joined(separator: ", ")
        case .null: ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
