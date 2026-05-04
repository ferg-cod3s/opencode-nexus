import Foundation

struct MessageEnvelope: Codable, Identifiable {
    let info: MessageInfo
    let parts: [Part]
    var id: String { info.id }

    init(info: MessageInfo, parts: [Part]) {
        self.info = info
        self.parts = parts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decode(MessageInfo.self, forKey: .info)
        parts = try container.decodeIfPresent([Part].self, forKey: .parts) ?? []
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant

    var displayName: String {
        switch self {
        case .user: return "User"
        case .assistant: return "Assistant"
        }
    }
}

struct MessageInfo: Codable, Identifiable {
    let id: String
    let sessionID: String?
    let role: MessageRole
    let time: MessageTimeInfo
    let parentID: String?
    let modelID: String?
    let providerID: String?
    let agent: String?
    let model: ModelRef?
    let system: String?
    let mode: String?
    let cost: Double?
    let tokens: TokenInfo?
    let error: MessageError?
    let summary: MessageSummary?
    let path: MessagePath?
    let finish: String?
    let variant: String?

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }

    init(
        id: String, sessionID: String? = nil, role: MessageRole,
        time: MessageTimeInfo, parentID: String? = nil,
        modelID: String? = nil, providerID: String? = nil,
        agent: String? = nil, model: ModelRef? = nil,
        system: String? = nil, mode: String? = nil,
        cost: Double? = nil, tokens: TokenInfo? = nil,
        error: MessageError? = nil, summary: MessageSummary? = nil,
        path: MessagePath? = nil, finish: String? = nil,
        variant: String? = nil
    ) {
        self.id = id; self.sessionID = sessionID; self.role = role
        self.time = time; self.parentID = parentID; self.modelID = modelID
        self.providerID = providerID; self.agent = agent; self.model = model
        self.system = system; self.mode = mode; self.cost = cost
        self.tokens = tokens; self.error = error; self.summary = summary
        self.path = path; self.finish = finish; self.variant = variant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionID = try? container.decodeIfPresent(String.self, forKey: .sessionID)
        role = try container.decode(MessageRole.self, forKey: .role)
        time = try container.decode(MessageTimeInfo.self, forKey: .time)
        parentID = try? container.decodeIfPresent(String.self, forKey: .parentID)
        modelID = try? container.decodeIfPresent(String.self, forKey: .modelID)
        providerID = try? container.decodeIfPresent(String.self, forKey: .providerID)
        agent = try? container.decodeIfPresent(String.self, forKey: .agent)
        model = try? container.decodeIfPresent(ModelRef.self, forKey: .model)
        system = try? container.decodeIfPresent(String.self, forKey: .system)
        mode = try? container.decodeIfPresent(String.self, forKey: .mode)
        cost = try? container.decodeIfPresent(Double.self, forKey: .cost)
        tokens = try? container.decodeIfPresent(TokenInfo.self, forKey: .tokens)
        error = try? container.decodeIfPresent(MessageError.self, forKey: .error)
        summary = try? container.decodeIfPresent(MessageSummary.self, forKey: .summary)
        path = try? container.decodeIfPresent(MessagePath.self, forKey: .path)
        finish = try? container.decodeIfPresent(String.self, forKey: .finish)
        variant = try? container.decodeIfPresent(String.self, forKey: .variant)
    }

    struct ModelRef: Codable {
        let providerID: String?
        let modelID: String?
        let variant: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            providerID = try? container.decodeIfPresent(String.self, forKey: .providerID)
            modelID = try? container.decodeIfPresent(String.self, forKey: .modelID)
            variant = try? container.decodeIfPresent(String.self, forKey: .variant)
        }
    }

    struct MessageSummary: Codable {
        let title: String?
        let body: String?
        let diffs: [FileDiff]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
            body = try? container.decodeIfPresent(String.self, forKey: .body)
            diffs = try? container.decodeIfPresent([FileDiff].self, forKey: .diffs)
        }
    }

    struct MessagePath: Codable {
        let cwd: String?
        let root: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            cwd = try? container.decodeIfPresent(String.self, forKey: .cwd)
            root = try? container.decodeIfPresent(String.self, forKey: .root)
        }
    }
}

struct MessageTimeInfo: Codable {
    let created: Int64
    let completed: Int64?
    let started: Int64?

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created) / 1000)
    }

    var completedDate: Date? {
        completed.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        created = (try? container.decode(Int64.self, forKey: .created)) ?? 0
        completed = try? container.decodeIfPresent(Int64.self, forKey: .completed)
        started = try? container.decodeIfPresent(Int64.self, forKey: .started)
    }

    init(created: Int64, completed: Int64? = nil, started: Int64? = nil) {
        self.created = created
        self.completed = completed
        self.started = started
    }
}

struct TokenInfo: Codable {
    let input: Int?
    let output: Int?
    let reasoning: Int?
    let cache: CacheInfo?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        input = try? container.decodeIfPresent(Int.self, forKey: .input)
        output = try? container.decodeIfPresent(Int.self, forKey: .output)
        reasoning = try? container.decodeIfPresent(Int.self, forKey: .reasoning)
        cache = try? container.decodeIfPresent(CacheInfo.self, forKey: .cache)
    }

    struct CacheInfo: Codable {
        let read: Int?
        let write: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            read = try? container.decodeIfPresent(Int.self, forKey: .read)
            write = try? container.decodeIfPresent(Int.self, forKey: .write)
        }
    }
}

struct MessageError: Codable {
    let name: String?
    let data: ErrorData?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        data = try? container.decodeIfPresent(ErrorData.self, forKey: .data)
    }

    struct ErrorData: Codable {
        let message: String?
        let providerID: String?
        let statusCode: Int?
        let isRetryable: Bool?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try? container.decodeIfPresent(String.self, forKey: .message)
            providerID = try? container.decodeIfPresent(String.self, forKey: .providerID)
            statusCode = try? container.decodeIfPresent(Int.self, forKey: .statusCode)
            isRetryable = try? container.decodeIfPresent(Bool.self, forKey: .isRetryable)
        }
    }

    var displayMessage: String {
        data?.message ?? name ?? "Unknown error"
    }
}
