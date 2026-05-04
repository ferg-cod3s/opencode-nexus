import Foundation

struct VcsInfo: Codable {
    let branch: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        branch = try? container.decodeIfPresent(String.self, forKey: .branch)
    }

    var displayBranch: String? {
        guard let branch, !branch.isEmpty else { return nil }
        return branch
    }
}

struct PathInfo: Codable {
    let home: String?
    let state: String?
    let config: String?
    let worktree: String?
    let directory: String?
}

struct FileNode: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let absolute: String
    let type: String
    let ignored: Bool

    var isDirectory: Bool { type == "directory" }
}

struct FileContent: Codable {
    let type: String
    let content: String
    let diff: String?
    let patch: FilePatch?
    let encoding: String?
    let mimeType: String?
}

struct FilePatch: Codable {
    let oldFileName: String?
    let newFileName: String?
    let hunks: [FilePatchHunk]?
}

struct FilePatchHunk: Codable {
    let oldStart: Int
    let oldLines: Int
    let newStart: Int
    let newLines: Int
    let lines: [String]
}

struct FileStatus: Codable {
    let path: String
    let added: Int
    let removed: Int
    let status: String
}

struct SymbolInfo: Codable {
    let name: String
    let kind: Int
    let location: SymbolLocation
}

struct SymbolLocation: Codable {
    let uri: String
    let range: CodeRange
}

struct CodeRange: Codable {
    let start: CodePosition
    let end: CodePosition
}

struct CodePosition: Codable {
    let line: Int
    let character: Int
}

struct Todo: Codable, Identifiable {
    let id: String
    let content: String
    let status: String
    let priority: String

    var isCompleted: Bool { status == "completed" }
    var isInProgress: Bool { status == "in_progress" }
}

struct Permission: Codable, Identifiable {
    let id: String
    let type: String
    let pattern: PatternValue?
    let sessionID: String
    let messageID: String
    let callID: String?
    let title: String
    let metadata: [String: JSONValue]?
    let time: PermissionTime

    struct PermissionTime: Codable {
        let created: Int64
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pattern
        case sessionID
        case messageID
        case callID
        case title
        case metadata
        case time
        case permission
        case patterns
        case tool
    }

    enum ToolCodingKeys: String, CodingKey {
        case messageID
        case callID
    }

    init(id: String, type: String, pattern: PatternValue?, sessionID: String, messageID: String, callID: String?, title: String, metadata: [String: JSONValue]?, time: PermissionTime) {
        self.id = id
        self.type = type
        self.pattern = pattern
        self.sessionID = sessionID
        self.messageID = messageID
        self.callID = callID
        self.title = title
        self.metadata = metadata
        self.time = time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)

        let decodedType = try container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .permission)
            ?? "permission"
        type = decodedType

        if let patternValue = try container.decodeIfPresent(PatternValue.self, forKey: .pattern) {
            pattern = patternValue
        } else if let patterns = try container.decodeIfPresent([String].self, forKey: .patterns) {
            pattern = .array(patterns)
        } else {
            pattern = nil
        }

        if container.contains(.tool) {
            let tool = try container.nestedContainer(keyedBy: ToolCodingKeys.self, forKey: .tool)
            messageID = try tool.decodeIfPresent(String.self, forKey: ToolCodingKeys.messageID) ?? container.decodeIfPresent(String.self, forKey: .messageID) ?? ""
            callID = try tool.decodeIfPresent(String.self, forKey: ToolCodingKeys.callID) ?? container.decodeIfPresent(String.self, forKey: .callID)
        } else {
            messageID = try container.decodeIfPresent(String.self, forKey: .messageID) ?? ""
            callID = try container.decodeIfPresent(String.self, forKey: .callID)
        }

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Permission: \(decodedType)"
        time = try container.decodeIfPresent(PermissionTime.self, forKey: .time) ?? PermissionTime(created: 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(pattern, forKey: .pattern)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(messageID, forKey: .messageID)
        try container.encodeIfPresent(callID, forKey: .callID)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(time, forKey: .time)
    }
}

enum PatternValue: Codable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode([String].self) { self = .array(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else { self = .string("") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        }
    }
}

struct ProviderListResponse: Codable {
    let all: [ProviderInfo]?
    let connected: [String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if var providersArray = try? container.nestedUnkeyedContainer(forKey: .all) {
            var decoded: [ProviderInfo] = []
            while !providersArray.isAtEnd {
                if let provider = try? providersArray.decode(ProviderInfo.self) {
                    decoded.append(provider)
                }
            }
            all = decoded.isEmpty ? nil : decoded
        } else {
            all = nil
        }
        connected = try? container.decodeIfPresent([String].self, forKey: .connected)
    }
}

struct ProviderInfo: Codable, Identifiable {
    let id: String
    let name: String?
    let models: [String: ProviderModelInfo]?

    init(id: String, name: String? = nil, models: [String: ProviderModelInfo]? = nil) {
        self.id = id
        self.name = name
        self.models = models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        if let modelsContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .models) {
            var decoded: [String: ProviderModelInfo] = [:]
            for key in modelsContainer.allKeys {
                if let model = try? modelsContainer.decodeIfPresent(ProviderModelInfo.self, forKey: key) {
                    decoded[key.stringValue] = model
                }
            }
            models = decoded.isEmpty ? nil : decoded
        } else {
            models = nil
        }
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

struct ProviderModelInfo: Codable {
    let id: String?
    let name: String?
    let providerID: String?
    let status: String?
    let cost: ModelCost?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        cost = try? container.decodeIfPresent(ModelCost.self, forKey: .cost)
    }

    var isDeprecated: Bool { status == "deprecated" }
    var isFree: Bool { cost?.input == 0 && cost?.output == 0 }

    struct ModelCost: Codable {
        let input: Double?
        let output: Double?
    }
}

struct ConfigProvidersResponse: Codable {
    let providers: [ProviderInfo]?
    let defaultModels: [String: String]?

    enum CodingKeys: String, CodingKey {
        case providers
        case defaultModels = "default"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if var providersArray = try? container.nestedUnkeyedContainer(forKey: .providers) {
            var decoded: [ProviderInfo] = []
            while !providersArray.isAtEnd {
                if let provider = try? providersArray.decode(ProviderInfo.self) {
                    decoded.append(provider)
                }
            }
            providers = decoded.isEmpty ? nil : decoded
        } else {
            providers = nil
        }
        defaultModels = try? container.decodeIfPresent([String: String].self, forKey: .defaultModels)
    }
}

struct AgentInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let mode: String?
    let builtIn: Bool?
    let permission: [AgentPermission]?
}

struct AgentPermission: Codable {
    let permission: String?
    let action: String?
    let pattern: String?
}

struct CommandInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
}

struct SkillInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let location: String?
}

struct SearchResult: Codable {
    let path: String?
    let line: Int?
    let text: String?

    init(path: String?, line: Int?, text: String?) {
        self.path = path
        self.line = line
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeStringOrTextObjectIfPresent(forKey: .path)
        line = try container.decodeIfPresent(Int.self, forKey: .line) ?? container.decodeIfPresent(Int.self, forKey: .lineNumber)
        text = try container.decodeStringOrTextObjectIfPresent(forKey: .text) ?? container.decodeStringOrTextObjectIfPresent(forKey: .lines)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(line, forKey: .line)
        try container.encodeIfPresent(text, forKey: .text)
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case path
        case line
        case text
        case lines
        case lineNumber = "line_number"
    }

    fileprivate struct TextObject: Codable {
        let text: String?
    }
}

private extension KeyedDecodingContainer where Key == SearchResult.CodingKeys {
    func decodeStringOrTextObjectIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        return try decodeIfPresent(SearchResult.TextObject.self, forKey: key)?.text
    }
}

struct TUIControlRequest: Codable, Identifiable {
    var id: String { path }
    let path: String
    let body: JSONValue
}

struct QuestionRequest: Codable, Identifiable {
    let id: String
    let sessionID: String
    let messageID: String?
    let title: String?
    let description: String?
    let questions: [QuestionInfo]

    var question: Question {
        let first = questions.first
        return Question(
            id: id,
            sessionID: sessionID,
            messageID: messageID,
            title: title ?? first?.header ?? "Question",
            description: description ?? first?.question,
            questions: questions.isEmpty ? [QuestionInfo(question: description ?? "", header: title ?? "Question", options: [], multiple: false, custom: true)] : questions
        )
    }
}

struct Question: Identifiable, Codable, Hashable {
    let id: String
    let sessionID: String
    let messageID: String?
    let title: String
    let description: String?
    let questions: [QuestionInfo]
}

struct QuestionInfo: Identifiable, Codable, Hashable {
    var id: String { header + question }
    let question: String
    let header: String
    let options: [QuestionOption]
    let multiple: Bool
    let custom: Bool

    init(question: String, header: String, options: [QuestionOption], multiple: Bool, custom: Bool) {
        self.question = question
        self.header = header
        self.options = options
        self.multiple = multiple
        self.custom = custom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? container.decodeIfPresent(String.self, forKey: .description) ?? ""
        header = try container.decodeIfPresent(String.self, forKey: .header) ?? container.decodeIfPresent(String.self, forKey: .title) ?? "Question"
        options = try container.decodeIfPresent([QuestionOption].self, forKey: .options) ?? []
        multiple = try container.decodeIfPresent(Bool.self, forKey: .multiple) ?? false
        custom = try container.decodeIfPresent(Bool.self, forKey: .custom) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(question, forKey: .question)
        try container.encode(header, forKey: .header)
        try container.encode(options, forKey: .options)
        try container.encode(multiple, forKey: .multiple)
        try container.encode(custom, forKey: .custom)
    }

    enum CodingKeys: String, CodingKey {
        case question
        case description
        case header
        case title
        case options
        case multiple
        case custom
    }
}

struct QuestionOption: Identifiable, Codable, Hashable {
    var id: String { label }
    let label: String
    let description: String

    init(label: String, description: String) {
        self.label = label
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

struct VcsDiffResponse: Codable {
    let files: [FileDiffInfo]
}

struct FileDiffInfo: Codable {
    let path: String
    let additions: Int
    let deletions: Int
    let status: String
}

struct McpServerStatus: Codable, Identifiable {
    var id: String { name }
    let name: String
    let status: String
    let error: String?
    let tools: [McpToolInfo]?
    
    var isConnected: Bool { status == "connected" }
    var isConnecting: Bool { status == "connecting" }
    var hasError: Bool { status == "error" || error != nil }
}

struct McpToolInfo: Codable {
    let name: String
    let description: String?
}

struct AddMcpServerBody: Encodable {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]
}

struct McpOAuthResponse: Codable {
    let url: String
}

struct McpOAuthCallbackBody: Encodable {
    let code: String
    let state: String
}

struct ProviderAuthMethod: Codable, Identifiable {
    var id: String { type }
    let type: String
    let providerID: String
    let name: String?
}

struct ProviderOAuthResponse: Codable {
    let url: String
}

struct ProviderOAuthCallbackBody: Encodable {
    let code: String
    let state: String
}

struct ServerConfigResponse: Codable {
    let theme: String?
    let language: String?
    let autoAcceptPermissions: Bool?
    let reasoningSummaries: Bool?
    let shellToolParts: Bool?
    let editToolParts: Bool?
    let sessionProgressBar: Bool?
    let visibleModels: [String]?
    let hiddenModels: [String]?
}

struct ConfigUpdate: Codable {
    let theme: String?
    let language: String?
    let autoAcceptPermissions: Bool?
    let reasoningSummaries: Bool?
    let shellToolParts: Bool?
    let editToolParts: Bool?
    let sessionProgressBar: Bool?
    let visibleModels: [String]?
    let hiddenModels: [String]?
}

struct UpdatePartBody: Encodable {
    let data: [String: JSONValue]
}
