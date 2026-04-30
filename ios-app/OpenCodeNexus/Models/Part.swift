import Foundation

struct Part: Codable, Identifiable {
    let id: String?
    let sessionID: String?
    let messageID: String?
    let type: String
    let text: String?
    let mime: String?
    let filename: String?
    let url: String?
    let callID: String?
    let tool: String?
    let state: ToolState?
    let snapshot: String?
    let hash: String?
    let files: [String]?
    let name: String?
    let attempt: Int?
    let auto: Bool?
    let prompt: String?
    let reason: String?
    let cost: Double?
    let tokens: TokenInfo?
    let error: MessageError?
    let synthetic: Bool?
    let ignored: Bool?
    let metadata: [String: JSONValue]?
    let description: String?

    var displayText: String {
        text ?? ""
    }

    var isText: Bool { type == "text" }
    var isTool: Bool { type == "tool" }
    var isReasoning: Bool { type == "reasoning" }
    var isStepStart: Bool { type == "step-start" }
    var isStepFinish: Bool { type == "step-finish" }
    var isPatch: Bool { type == "patch" }
    var isSnapshot: Bool { type == "snapshot" }
    var isAgent: Bool { type == "agent" }
    var isFile: Bool { type == "file" }
    var isCompaction: Bool { type == "compaction" }
    var isRetry: Bool { type == "retry" }
    var isSubtask: Bool { type == "subtask" }

    init(
        id: String? = nil, sessionID: String? = nil, messageID: String? = nil,
        type: String = "text", text: String? = nil, mime: String? = nil,
        filename: String? = nil, url: String? = nil, callID: String? = nil,
        tool: String? = nil, state: ToolState? = nil, snapshot: String? = nil,
        hash: String? = nil, files: [String]? = nil, name: String? = nil,
        attempt: Int? = nil, auto: Bool? = nil, prompt: String? = nil,
        reason: String? = nil, cost: Double? = nil, tokens: TokenInfo? = nil,
        error: MessageError? = nil, synthetic: Bool? = nil, ignored: Bool? = nil,
        metadata: [String: JSONValue]? = nil, description: String? = nil
    ) {
        self.id = id; self.sessionID = sessionID; self.messageID = messageID
        self.type = type; self.text = text; self.mime = mime
        self.filename = filename; self.url = url; self.callID = callID
        self.tool = tool; self.state = state; self.snapshot = snapshot
        self.hash = hash; self.files = files; self.name = name
        self.attempt = attempt; self.auto = auto; self.prompt = prompt
        self.reason = reason; self.cost = cost; self.tokens = tokens
        self.error = error; self.synthetic = synthetic; self.ignored = ignored
        self.metadata = metadata; self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        sessionID = try? container.decodeIfPresent(String.self, forKey: .sessionID)
        messageID = try? container.decodeIfPresent(String.self, forKey: .messageID)
        type = (try? container.decode(String.self, forKey: .type)) ?? "text"
        text = try? container.decodeIfPresent(String.self, forKey: .text)
        mime = try? container.decodeIfPresent(String.self, forKey: .mime)
        filename = try? container.decodeIfPresent(String.self, forKey: .filename)
        url = try? container.decodeIfPresent(String.self, forKey: .url)
        callID = try? container.decodeIfPresent(String.self, forKey: .callID)
        tool = try? container.decodeIfPresent(String.self, forKey: .tool)
        state = try? container.decodeIfPresent(ToolState.self, forKey: .state)
        snapshot = try? container.decodeIfPresent(String.self, forKey: .snapshot)
        hash = try? container.decodeIfPresent(String.self, forKey: .hash)
        files = try? container.decodeIfPresent([String].self, forKey: .files)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        attempt = try? container.decodeIfPresent(Int.self, forKey: .attempt)
        auto = try? container.decodeIfPresent(Bool.self, forKey: .auto)
        prompt = try? container.decodeIfPresent(String.self, forKey: .prompt)
        reason = try? container.decodeIfPresent(String.self, forKey: .reason)
        cost = try? container.decodeIfPresent(Double.self, forKey: .cost)
        tokens = try? container.decodeIfPresent(TokenInfo.self, forKey: .tokens)
        error = try? container.decodeIfPresent(MessageError.self, forKey: .error)
        synthetic = try? container.decodeIfPresent(Bool.self, forKey: .synthetic)
        ignored = try? container.decodeIfPresent(Bool.self, forKey: .ignored)
        metadata = try? container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
    }

    func withText(_ newText: String) -> Part {
        Part(
            id: id, sessionID: sessionID, messageID: messageID, type: type,
            text: newText, mime: mime, filename: filename, url: url,
            callID: callID, tool: tool, state: state, snapshot: snapshot,
            hash: hash, files: files, name: name, attempt: attempt, auto: auto,
            prompt: prompt, reason: reason, cost: cost, tokens: tokens,
            error: error, synthetic: synthetic, ignored: ignored,
            metadata: metadata, description: description
        )
    }
}

struct ToolState: Codable {
    let status: String?
    let input: [String: JSONValue]?
    let output: String?
    let title: String?
    let error: String?
    let time: ToolTime?
    let metadata: [String: JSONValue]?
    let attachments: [FilePartRef]?

    var isPending: Bool { status == "pending" }
    var isRunning: Bool { status == "running" }
    var isCompleted: Bool { status == "completed" }
    var isError: Bool { status == "error" }

    init(
        status: String? = nil, input: [String: JSONValue]? = nil,
        output: String? = nil, title: String? = nil, error: String? = nil,
        time: ToolTime? = nil, metadata: [String: JSONValue]? = nil,
        attachments: [FilePartRef]? = nil
    ) {
        self.status = status; self.input = input; self.output = output
        self.title = title; self.error = error; self.time = time
        self.metadata = metadata; self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        input = try? container.decodeIfPresent([String: JSONValue].self, forKey: .input)
        output = try? container.decodeIfPresent(String.self, forKey: .output)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        error = try? container.decodeIfPresent(String.self, forKey: .error)
        time = try? container.decodeIfPresent(ToolTime.self, forKey: .time)
        metadata = try? container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        attachments = try? container.decodeIfPresent([FilePartRef].self, forKey: .attachments)
    }

    struct ToolTime: Codable {
        let start: Int64?
        let end: Int64?
        let compacted: Int64?

        init(start: Int64? = nil, end: Int64? = nil, compacted: Int64? = nil) {
            self.start = start; self.end = end; self.compacted = compacted
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            start = try? container.decodeIfPresent(Int64.self, forKey: .start)
            end = try? container.decodeIfPresent(Int64.self, forKey: .end)
            compacted = try? container.decodeIfPresent(Int64.self, forKey: .compacted)
        }
    }
}

struct FilePartRef: Codable {
    let mime: String?
    let filename: String?
    let url: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mime = try? container.decodeIfPresent(String.self, forKey: .mime)
        filename = try? container.decodeIfPresent(String.self, forKey: .filename)
        url = try? container.decodeIfPresent(String.self, forKey: .url)
    }
}
