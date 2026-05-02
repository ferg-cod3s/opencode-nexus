import Foundation
import os

final class OpenCodeClient: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let cfAccessClientId: String?
    private let cfAccessClientSecret: String?
    private let username: String?
    private let password: String?
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "OpenCodeClient")

    init(baseURL: URL, cfAccessClientId: String? = nil, cfAccessClientSecret: String? = nil, username: String? = nil, password: String? = nil, configuration: URLSessionConfiguration = .default) {
        self.baseURL = baseURL
        self.cfAccessClientId = cfAccessClientId
        self.cfAccessClientSecret = cfAccessClientSecret
        self.username = username
        self.password = password
        let config = configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    private func addAuthHeaders(to request: inout URLRequest) {
        if let clientId = cfAccessClientId, !clientId.isEmpty,
           let clientSecret = cfAccessClientSecret, !clientSecret.isEmpty {
            request.setValue(clientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
        if let username, !username.isEmpty, let password {
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
    }

    private func queryItems(directory: String? = nil, workspace: String? = nil) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let directory { items.append(URLQueryItem(name: "directory", value: directory)) }
        if let workspace { items.append(URLQueryItem(name: "workspace", value: workspace)) }
        return items
    }

    private func shellAgent(_ agent: String?) -> String {
        let trimmed = agent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "build" : trimmed
    }

    private func request<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        if data.isEmpty, T.self == Bool.self {
            return true as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, query: [URLQueryItem] = []) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        if data.isEmpty, T.self == Bool.self {
            return true as! T
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Decoding failed for POST \(path): \(error)")
            throw OpenCodeError.decodingError(String(describing: error))
        }
    }

    private func postVoid(_ path: String, body: some Encodable, query: [URLQueryItem] = []) async throws {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func putVoid(_ path: String, body: some Encodable, query: [URLQueryItem] = []) async throws {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func postEmpty(_ path: String, query: [URLQueryItem] = []) async throws {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func postEmpty<B: Encodable>(_ path: String, body: B, query: [URLQueryItem] = []) async throws {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    private func patch<T: Decodable, B: Encodable>(_ path: String, body: B, query: [URLQueryItem] = []) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        if data.isEmpty, T.self == Bool.self {
            return true as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeaders(to: &request)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        if data.isEmpty, T.self == Bool.self {
            return true as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Global

    func healthCheck() async throws -> HealthResponse {
        try await request("global/health")
    }

    // MARK: - Projects

    func listProjects() async throws -> [Project] {
        try await request("project")
    }

    func getCurrentProject() async throws -> Project {
        try await request("project/current")
    }

    // MARK: - Path & VCS

    func getPath() async throws -> PathInfo {
        try await request("path")
    }

    func getVcs() async throws -> VcsInfo {
        try await request("vcs")
    }

    func getVcsDiff() async throws -> VcsDiffResponse {
        try await request("vcs/diff")
    }

    func initSession(_ id: String, directory: String? = nil) async throws {
        try await postEmpty("session/\(id)/init", query: queryItems(directory: directory))
    }

    // MARK: - Workspaces

    func listWorkspaces() async throws -> [Workspace] {
        try await request("experimental/workspace")
    }

    func createWorkspace(type: String, branch: String? = nil) async throws -> Workspace {
        try await post("experimental/workspace", body: CreateWorkspaceBody(type: type, branch: branch))
    }

    func removeWorkspace(id: String) async throws {
        let _: Bool = try await delete("experimental/workspace/\(id)")
    }

    func resetWorkspace(id: String) async throws {
        try await postEmpty("experimental/workspace/\(id)/reset")
    }

    func getWorkspaceStatus() async throws -> [String: WorkspaceStatus] {
        try await request("experimental/workspace/status")
    }

    func listWorkspaceAdaptors() async throws -> [WorkspaceAdaptor] {
        try await request("experimental/workspace/adaptor")
    }

    func restoreWorkspaceSession(id: String) async throws {
        try await postEmpty("experimental/workspace/\(id)/session-restore")
    }

    // MARK: - Sessions

    func listSessions(directory: String? = nil, roots: Bool? = nil, limit: Int? = nil) async throws -> [Session] {
        var items = queryItems(directory: directory)
        if let roots { items.append(URLQueryItem(name: "roots", value: String(roots))) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await request("session", query: items)
    }

    func createSession(title: String, directory: String? = nil, parentID: String? = nil) async throws -> Session {
        try await post("session", body: CreateSessionBody(title: title, parentID: parentID), query: queryItems(directory: directory))
    }

    func getSession(_ id: String, directory: String? = nil) async throws -> Session {
        try await request("session/\(id)", query: queryItems(directory: directory))
    }

    func updateSession(_ id: String, title: String? = nil, directory: String? = nil) async throws -> Session {
        try await patch("session/\(id)", body: UpdateSessionBody(title: title), query: queryItems(directory: directory))
    }

    func deleteSession(id: String, directory: String? = nil) async throws -> Bool {
        try await delete("session/\(id)", query: queryItems(directory: directory))
    }

    func getSessionStatus(directory: String? = nil) async throws -> [String: SessionStatus] {
        try await request("session/status", query: queryItems(directory: directory))
    }

    func getChildren(_ sessionId: String, directory: String? = nil) async throws -> [Session] {
        try await request("session/\(sessionId)/children", query: queryItems(directory: directory))
    }

    func forkSession(_ sessionId: String, messageID: String? = nil, directory: String? = nil) async throws -> Session {
        try await post("session/\(sessionId)/fork", body: ForkBody(messageID: messageID), query: queryItems(directory: directory))
    }

    func shareSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
        try await postEmpty("session/\(sessionId)/share", query: queryItems(directory: directory))
        return try await getSession(sessionId, directory: directory)
    }

    func unshareSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
        return try await delete("session/\(sessionId)/share", query: queryItems(directory: directory))
    }

    func getSessionDiff(_ sessionId: String, messageID: String? = nil, directory: String? = nil) async throws -> [FileDiff] {
        var query = queryItems(directory: directory)
        if let messageID { query.append(URLQueryItem(name: "messageID", value: messageID)) }
        return try await request("session/\(sessionId)/diff", query: query)
    }

    func summarizeSession(_ sessionId: String, providerID: String? = nil, modelID: String? = nil, directory: String? = nil) async throws {
        let _: Bool = try await post("session/\(sessionId)/summarize", body: SummarizeBody(providerID: providerID, modelID: modelID), query: queryItems(directory: directory))
    }

    func revertMessage(_ sessionId: String, messageID: String, partID: String? = nil, directory: String? = nil) async throws {
        let _: Bool = try await post("session/\(sessionId)/revert", body: RevertBody(messageID: messageID, partID: partID), query: queryItems(directory: directory))
    }

    func unrevertMessages(_ sessionId: String, directory: String? = nil) async throws {
        try await postEmpty("session/\(sessionId)/unrevert", query: queryItems(directory: directory))
    }

    func abortSession(sessionId: String, directory: String? = nil) async throws {
        try await postEmpty("session/\(sessionId)/abort", query: queryItems(directory: directory))
    }

    func getTodos(_ sessionId: String, directory: String? = nil) async throws -> [Todo] {
        try await request("session/\(sessionId)/todo", query: queryItems(directory: directory))
    }

    // MARK: - Messages

    func getMessages(sessionId: String, directory: String? = nil, limit: Int? = nil, before: String? = nil) async throws -> [MessageEnvelope] {
        var query = queryItems(directory: directory)
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        return try await request("session/\(sessionId)/message", query: query)
    }

    func sendMessage(sessionId: String, text: String, messageID: String? = nil, model: ModelRefBody? = nil, agent: String? = nil, directory: String? = nil) async throws -> MessageEnvelope {
        let parts = [MessagePartBody(type: "text", text: text)]
        return try await post("session/\(sessionId)/message", body: SendMessageBody(messageID: messageID, parts: parts, model: model, agent: agent), query: queryItems(directory: directory))
    }

    func sendAsyncMessage(sessionId: String, text: String, messageID: String? = nil, model: ModelRefBody? = nil, agent: String? = nil, parts: [MessagePartBody]? = nil, directory: String? = nil) async throws {
        var messageParts: [MessagePartBody] = []
        if !text.isEmpty {
            messageParts.append(MessagePartBody(type: "text", text: text))
        }
        if let parts {
            messageParts.append(contentsOf: parts)
        }
        guard !messageParts.isEmpty else { return }
        var url = baseURL.appendingPathComponent("session/\(sessionId)/prompt_async")
        let query = queryItems(directory: directory)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(SendMessageBody(messageID: messageID, parts: messageParts, model: model, agent: agent))
        let (_, response) = try await session.data(for: request)
        try validateResponse(response, data: nil)
    }

    func sendCommand(sessionId: String, command: String, arguments: String = "", model: ModelRefBody? = nil, agent: String? = nil, directory: String? = nil) async throws -> MessageEnvelope {
        try await post("session/\(sessionId)/command", body: CommandBody(command: command, arguments: arguments, model: model?.wireValue, agent: agent), query: queryItems(directory: directory))
    }

    func sendShellCommand(sessionId: String, command: String, model: ModelRefBody? = nil, agent: String? = nil, directory: String? = nil) async throws -> MessageEnvelope {
        try await post("session/\(sessionId)/shell", body: ShellBody(command: command, model: model, agent: shellAgent(agent)), query: queryItems(directory: directory))
    }

    func deleteMessage(sessionId: String, messageID: String, directory: String? = nil) async throws {
        let _: Bool = try await delete("session/\(sessionId)/message/\(messageID)", query: queryItems(directory: directory))
    }

    func deleteMessagePart(sessionId: String, messageID: String, partID: String, directory: String? = nil) async throws {
        let _: Bool = try await delete("session/\(sessionId)/message/\(messageID)/part/\(partID)", query: queryItems(directory: directory))
    }

    func updateMessagePart(sessionId: String, messageID: String, partID: String, body: [String: JSONValue], directory: String? = nil) async throws {
        let _: Bool = try await patch("session/\(sessionId)/message/\(messageID)/part/\(partID)", body: UpdatePartBody(data: body), query: queryItems(directory: directory))
    }

    // MARK: - Files

    func listFiles(path: String? = nil, directory: String? = nil, workspace: String? = nil) async throws -> [FileNode] {
        var query = queryItems(directory: directory, workspace: workspace)
        query.append(URLQueryItem(name: "path", value: path ?? ""))
        return try await request("file", query: query)
    }

    func getFileContent(path: String, directory: String? = nil, workspace: String? = nil) async throws -> FileContent {
        var query = queryItems(directory: directory, workspace: workspace)
        query.append(URLQueryItem(name: "path", value: path))
        return try await request("file/content", query: query)
    }

    func getFileStatus(directory: String? = nil, workspace: String? = nil) async throws -> [FileStatus] {
        try await request("file/status", query: queryItems(directory: directory, workspace: workspace))
    }

    func findText(pattern: String, directory: String? = nil, workspace: String? = nil) async throws -> [SearchResult] {
        var query = queryItems(directory: directory, workspace: workspace)
        query.append(URLQueryItem(name: "pattern", value: pattern))
        return try await request("find", query: query)
    }

    func findFiles(query: String, directory: String? = nil, workspace: String? = nil) async throws -> [String] {
        var items = queryItems(directory: directory, workspace: workspace)
        items.append(URLQueryItem(name: "query", value: query))
        return try await request("find/file", query: items)
    }

    func writeFile(path: String, content: String, directory: String? = nil, workspace: String? = nil) async throws {
        try await postEmpty("file/write", body: WriteFileBody(path: path, content: content), query: queryItems(directory: directory, workspace: workspace))
    }

    func archiveSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
        try await postEmpty("session/\(sessionId)/archive", query: queryItems(directory: directory))
        return try await getSession(sessionId, directory: directory)
    }

    func unarchiveSession(_ sessionId: String, directory: String? = nil) async throws -> Session {
        try await postEmpty("session/\(sessionId)/unarchive", query: queryItems(directory: directory))
        return try await getSession(sessionId, directory: directory)
    }

    // MARK: - Permissions

    func listPermissions(directory: String? = nil) async throws -> [Permission] {
        try await request("permission", query: queryItems(directory: directory))
    }

    func replyPermission(_ permissionID: String, response: String, sessionID: String, directory: String? = nil) async throws {
        let _: Bool = try await post("session/\(sessionID)/permissions/\(permissionID)", body: PermissionReplyBody(response: response), query: queryItems(directory: directory))
    }

    func replyQuestion(_ requestID: String, answers: [[String]], directory: String? = nil) async throws {
        let _: Bool = try await post("question/\(requestID)/reply", body: QuestionReplyBody(answers: answers), query: queryItems(directory: directory))
    }

    func listQuestions(directory: String? = nil) async throws -> [Question] {
        let requests: [QuestionRequest] = try await request("question", query: queryItems(directory: directory))
        return requests.map(\.question)
    }

    func rejectQuestion(_ requestID: String, directory: String? = nil) async throws {
        let _: Bool = try await post("question/\(requestID)/reject", body: EmptyBody(), query: queryItems(directory: directory))
    }

    // MARK: - TUI

    func getNextTUIRequest(directory: String? = nil) async throws -> TUIControlRequest {
        try await request("tui/control/next", query: queryItems(directory: directory))
    }

    func respondToTUIRequest(body: [String: JSONValue], directory: String? = nil) async throws -> Bool {
        try await post("tui/control/response", body: body, query: queryItems(directory: directory))
    }

    func appendPrompt(_ text: String, directory: String? = nil) async throws {
        let _: Bool = try await post("tui/append-prompt", body: AppendPromptBody(text: text), query: queryItems(directory: directory))
    }

    func submitPrompt(directory: String? = nil) async throws {
        let _: Bool = try await post("tui/submit-prompt", body: EmptyBody(), query: queryItems(directory: directory))
    }

    func clearPrompt(directory: String? = nil) async throws {
        let _: Bool = try await post("tui/clear-prompt", body: EmptyBody(), query: queryItems(directory: directory))
    }

    // MARK: - Provider & Agent

    func listProviders() async throws -> ProviderListResponse {
        try await request("provider")
    }

    func listConfigProviders() async throws -> ConfigProvidersResponse {
        try await request("config/providers")
    }

    func listAgents() async throws -> [AgentInfo] {
        try await request("agent")
    }

    func listCommands() async throws -> [CommandInfo] {
        try await request("command")
    }

    func listSkills() async throws -> [SkillInfo] {
        try await request("skill")
    }

    // MARK: - MCP

    func listMcpServers() async throws -> [McpServerStatus] {
        try await request("mcp")
    }

    func addMcpServer(name: String, command: String, args: [String] = [], env: [String: String] = [:]) async throws {
        try await postEmpty("mcp", body: AddMcpServerBody(name: name, command: command, args: args, env: env))
    }

    func connectMcpServer(name: String) async throws {
        try await postEmpty("mcp/\(name)/connect")
    }

    func disconnectMcpServer(name: String) async throws {
        try await postEmpty("mcp/\(name)/disconnect")
    }

    func removeMcpServer(name: String) async throws {
        let _: Bool = try await delete("mcp/\(name)")
    }

    func startMcpOAuth(name: String) async throws -> McpOAuthResponse {
        try await post("mcp/\(name)/auth", body: EmptyBody())
    }

    func completeMcpOAuth(name: String, code: String, state: String) async throws {
        try await postEmpty("mcp/\(name)/auth/callback", body: McpOAuthCallbackBody(code: code, state: state))
    }

    func removeMcpOAuth(name: String) async throws {
        let _: Bool = try await delete("mcp/\(name)/auth")
    }

    // MARK: - Provider Auth

    func listProviderAuthMethods() async throws -> [ProviderAuthMethod] {
        try await request("provider/auth")
    }

    func startProviderOAuth(providerID: String) async throws -> ProviderOAuthResponse {
        try await post("provider/\(providerID)/oauth/authorize", body: EmptyBody())
    }

    func completeProviderOAuth(providerID: String, code: String, state: String) async throws {
        try await postEmpty("provider/\(providerID)/oauth/callback", body: ProviderOAuthCallbackBody(code: code, state: state))
    }

    func disconnectProvider(providerID: String) async throws {
        try await postEmpty("provider/\(providerID)/disconnect")
    }

    // MARK: - Config

    func getConfig() async throws -> ServerConfigResponse {
        try await request("config")
    }

    func updateConfig(_ config: ConfigUpdate) async throws {
        let _: Bool = try await patch("config", body: config)
    }

    // MARK: - SSE

    // MARK: - PTY

    func listPtys(directory: String? = nil) async throws -> [Pty] {
        try await request("pty", query: queryItems(directory: directory))
    }

    func createPty(command: String? = nil, args: [String]? = nil, cwd: String? = nil, title: String? = nil, directory: String? = nil) async throws -> Pty {
        try await post("pty", body: CreatePtyBody(command: command, args: args, cwd: cwd, title: title), query: queryItems(directory: directory))
    }

    func getPty(_ id: String, directory: String? = nil) async throws -> Pty {
        try await request("pty/\(id)", query: queryItems(directory: directory))
    }

    func removePty(_ id: String, directory: String? = nil) async throws {
        let _: Bool = try await delete("pty/\(id)", query: queryItems(directory: directory))
    }

    func resizePty(_ id: String, rows: Int, cols: Int, directory: String? = nil) async throws {
        try await putVoid("pty/\(id)", body: ResizePtyBody(size: PtySize(rows: rows, cols: cols)), query: queryItems(directory: directory))
    }

    func ptyConnectRequest(ptyID: String, directory: String? = nil) -> URLRequest {
        let path = "pty/\(ptyID)/connect"
        var url = baseURL.appendingPathComponent(path)
        let query = queryItems(directory: directory)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        if let scheme = url.scheme {
            let wsScheme = scheme == "https" ? "wss" : "ws"
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.scheme = wsScheme
            url = components.url!
        }
        var request = URLRequest(url: url)
        addAuthHeaders(to: &request)
        return request
    }

    var urlSession: URLSession { session }

    // MARK: - SSE

    func eventStream(directory: String? = nil, workspace: String? = nil) -> AsyncThrowingStream<SSEEvent, Error> {
        var url = baseURL.appendingPathComponent("event")
        let query = queryItems(directory: directory, workspace: workspace)
        if !query.isEmpty {
            url = url.appending(queryItems: query)
        }
        var mutableRequest = URLRequest(url: url)
        mutableRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        addAuthHeaders(to: &mutableRequest)
        mutableRequest.timeoutInterval = TimeInterval.infinity
        let request = mutableRequest
        let clientLogger = self.logger
        let session = self.session

        return AsyncThrowingStream { @Sendable continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        clientLogger.error("SSE: non-2xx response")
                        throw OpenCodeError.invalidResponse
                    }
                    clientLogger.info("SSE: stream connected")
                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        switch parser.processLine(line) {
                        case .event(let event):
                            if event.eventType == "done" {
                                clientLogger.info("SSE: received done event")
                                continuation.finish()
                                return
                            }
                            continuation.yield(event)
                        case .malformed(let data):
                            clientLogger.warning("SSE: malformed event, data: \(data.prefix(200))")
                        case .none:
                            break
                        }
                    }
                    // Flush any remaining buffered event
                    switch parser.flush() {
                    case .event(let event):
                        if event.eventType == "done" {
                            clientLogger.info("SSE: received done event at stream end")
                        } else {
                            continuation.yield(event)
                        }
                    case .malformed(let data):
                        clientLogger.warning("SSE: malformed event at stream end, data: \(data.prefix(200))")
                    case .none:
                        break
                    }
                    clientLogger.info("SSE: stream ended")
                    continuation.finish()
                } catch {
                    clientLogger.error("SSE: stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Validation

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCodeError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("HTTP \(httpResponse.statusCode) for \(response.url?.path ?? "unknown")")
            let bodySnippet = data.flatMap { String(data: $0.prefix(512), encoding: .utf8) }
            throw OpenCodeError.httpError(httpResponse.statusCode, bodySnippet)
        }
    }
}

// MARK: - Request Bodies

private struct CreateSessionBody: Encodable {
    let title: String
    let parentID: String?
}

private struct UpdateSessionBody: Encodable {
    let title: String?
}

struct SendMessageBody: Encodable {
    let messageID: String?
    let parts: [MessagePartBody]
    let model: ModelRefBody?
    let agent: String?
}

struct MessagePartBody: Codable, Hashable {
    let type: String
    let text: String?
    let mime: String?
    let url: String?
    let filename: String?

    init(type: String, text: String? = nil, mime: String? = nil, url: String? = nil, filename: String? = nil) {
        self.type = type
        self.text = text
        self.mime = mime
        self.url = url
        self.filename = filename
    }
}

struct ModelRefBody: Codable {
    let providerID: String?
    let modelID: String?

    var wireValue: String? {
        guard let providerID, let modelID, !providerID.isEmpty, !modelID.isEmpty else { return nil }
        return "\(providerID)/\(modelID)"
    }
}

private struct ForkBody: Encodable {
    let messageID: String?
}

private struct RevertBody: Encodable {
    let messageID: String
    let partID: String?
}

private struct SummarizeBody: Encodable {
    let providerID: String?
    let modelID: String?
}

private struct PermissionReplyBody: Encodable {
    let response: String
}

private struct QuestionReplyBody: Encodable {
    let answers: [[String]]
}

private struct EmptyBody: Encodable {}

private struct AppendPromptBody: Encodable {
    let text: String
}

private struct CommandBody: Encodable {
    let command: String
    let arguments: String
    let model: String?
    let agent: String?
}

private struct ShellBody: Encodable {
    let command: String
    let model: ModelRefBody?
    let agent: String
}

private struct CreatePtyBody: Encodable {
    let command: String?
    let args: [String]?
    let cwd: String?
    let title: String?
}

private struct ResizePtyBody: Encodable {
    let size: PtySize
}

private struct PtySize: Encodable {
    let rows: Int
    let cols: Int
}

private struct WriteFileBody: Encodable {
    let path: String
    let content: String
}

private struct CreateWorkspaceBody: Encodable {
    let type: String
    let branch: String?
}

// MARK: - Errors

enum OpenCodeError: LocalizedError {
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code, let bodySnippet):
            if let snippet = bodySnippet {
                return "Server error (HTTP \(code)): \(snippet)"
            } else {
                return "Server error (HTTP \(code))"
            }
        case .decodingError(let detail): return "Failed to parse response: \(detail)"
        }
    }
}
