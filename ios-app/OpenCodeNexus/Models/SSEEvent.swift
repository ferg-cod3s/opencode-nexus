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
        let syncEvent: SyncPayload?
    }

    struct SyncPayload: Decodable, Sendable, Equatable {
        let type: String
        let id: String?
        let seq: Int?
        let aggregateID: String?
        let data: [String: JSONValue]?
    }

    private var directType: String?
    private var directProperties: [String: JSONValue]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        directory = try? container.decodeIfPresent(String.self, forKey: .directory)
        project = try? container.decodeIfPresent(String.self, forKey: .project)
        workspace = try? container.decodeIfPresent(String.self, forKey: .workspace)

        if let syncEvent = try? container.decodeIfPresent(SyncPayload.self, forKey: .payload) {
            self.payload = nil
            self.syncEvent = syncEvent
            self.directType = nil
            self.directProperties = nil
        } else if let payload = try? container.decodeIfPresent(Payload.self, forKey: .payload) {
            self.payload = payload
            self.syncEvent = nil
            self.directType = nil
            self.directProperties = nil
        } else {
            self.payload = nil
            self.syncEvent = nil
            self.directType = try? container.decodeIfPresent(String.self, forKey: .type)
            self.directProperties = try? container.decodeIfPresent([String: JSONValue].self, forKey: .properties)
        }
    }

    var eventType: String {
        if let payload {
            if let syncEvent = payload.syncEvent { return syncEvent.type }
            return payload.type
        }
        if let syncEvent { return syncEvent.type }
        if let directType { return directType }
        return "unknown"
    }

    var properties: [String: JSONValue]? {
        if let payload {
            if let syncEvent = payload.syncEvent { return syncEvent.data }
            return payload.properties
        }
        if let syncEvent { return syncEvent.data }
        if let directProperties { return directProperties }
        return nil
    }

    var sessionID: String? {
        properties?.recursiveStringValue(forKeys: ["sessionID", "sessionId"])
            ?? payload?.syncEvent?.aggregateID
            ?? syncEvent?.aggregateID
    }

    var messageID: String? {
        properties?.recursiveStringValue(forKeys: ["messageID", "messageId"])
            ?? properties?.nestedStringValue(for: ["message", "info", "id"])
            ?? properties?.nestedStringValue(for: ["info", "id"])
            ?? properties?.nestedStringValue(for: ["message", "id"])
            ?? properties?.nestedStringValue(for: ["part", "messageID"])
            ?? properties?.nestedStringValue(for: ["part", "messageId"])
            ?? (eventType.hasPrefix("message") ? (payload?.syncEvent?.id ?? syncEvent?.id) : nil)
    }

    enum CodingKeys: String, CodingKey {
        case directory, project, workspace, payload, type, properties
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

private extension Dictionary where Key == String, Value == JSONValue {
    func nestedStringValue(for path: [String]) -> String? {
        guard let first = path.first,
            let value = self[first]
        else { return nil }

        if path.count == 1 {
            return value.stringValue
        }

        return value.nestedStringValue(for: Array(path.dropFirst()))
    }

    func recursiveStringValue(forKeys keys: Set<String>) -> String? {
        for key in keys {
            if let value = self[key]?.stringValue {
                return value
            }
        }

        for value in values {
            if let resolved = value.recursiveStringValue(forKeys: keys) {
                return resolved
            }
        }

        return nil
    }
}

private extension JSONValue {
    func nestedStringValue(for path: [String]) -> String? {
        guard !path.isEmpty else { return stringValue }
        guard case .object(let object) = self else { return nil }
        return object.nestedStringValue(for: path)
    }

    func recursiveStringValue(forKeys keys: Set<String>) -> String? {
        switch self {
        case .object(let object):
            return object.recursiveStringValue(forKeys: keys)
        case .array(let values):
            for value in values {
                if let resolved = value.recursiveStringValue(forKeys: keys) {
                    return resolved
                }
            }
            return nil
        default:
            return nil
        }
    }
}
