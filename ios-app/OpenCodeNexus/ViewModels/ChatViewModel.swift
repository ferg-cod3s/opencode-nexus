import Sentry
import SwiftUI
import os

@MainActor
@Observable
final class ChatViewModel {
    private let logger = Logger(
        subsystem: "com.agentic-codeflow.opencode-nexus", category: "ChatViewModel")
    var sessions: [Session] = [] {
        didSet { _cachedGroups = nil }
    }
    var archivedSessions: [Session] = []
    var selectedSessionId: String? {
        didSet {
            if isRestoringSelectionDuringSend { return }
            if selectedSessionId == nil && isSending {
                isRestoringSelectionDuringSend = true
                selectedSessionId = oldValue
                isRestoringSelectionDuringSend = false
                logger.warning("Prevented selectedSessionId from being nilled during active send")
                return
            }
            if selectedSessionId != oldValue {
                if let oldValue {
                    sessionSelectedModels[oldValue] = selectedModel
                }
                if let oldId = oldValue {
                    let draft = PromptDraft(text: inputText, attachments: attachedParts)
                    let key = "opencode-nexus.prompt-drafts.v1"
                    Task.detached {
                        var drafts = (try? JSONDecoder().decode([String: PromptDraft].self, from: UserDefaults.standard.data(forKey: key) ?? Data())) ?? [:]
                        if draft.text.isEmpty && draft.attachments.isEmpty {
                            drafts.removeValue(forKey: oldId)
                        } else {
                            drafts[oldId] = draft
                        }
                        if let data = try? JSONEncoder().encode(drafts) {
                            UserDefaults.standard.set(data, forKey: key)
                        }
                    }
                }
                isSending = false
                isStreamingDeltas = false
                debouncedMessageRecoveryTask?.cancel()
                messages = []
                todos = []
                fileDiffs = []
                restoreDraft(for: selectedSessionId)
                refreshPendingStateForSelectedSession()
                let newId = selectedSessionId
                let staleIds =
                    pendingOptimisticMessages
                    .filter { $0.value.sessionID != newId }.map(\.key)
                for id in staleIds {
                    pendingOptimisticMessages[id] = nil
                }
                if let newId {
                    selectedModel = sessionSelectedModels[newId] ?? selectedModel
                }
                optimisticToServerMessageIds.removeAll()
            }
        }
    }
    var messages: [MessageEnvelope] = []
    var isLoadingSessions = false
    var isLoadingMessages = false
    var isSending = false
    var errorMessage: String?
    var newSessionTitle = ""
    var inputText = "" {
        didSet { saveDraft(for: selectedSessionId) }
    }
    var attachedParts: [MessagePartBody] = [] {
        didSet { saveDraft(for: selectedSessionId) }
    }
    var selectedDirectory: String?
    var sessionStatuses: [String: SessionStatus] = [:]
    var pendingPermissions: [Permission] = []
    var pendingQuestions: [Question] = []
    var todos: [Todo] = []
    var isShowingTodos = false
    var selectedModel: ModelRefBody?
    var showAllSessions = true  // Default to showing all; user can filter if needed
    var selectedAgent: String? = "build"
    var vcsBranch: String?
    var currentProject: Project?
    var projects: [Project] = []
    var fileDiffs: [FileDiff] = []
    var queuedMessages: [String: [String]] = [:]

    var availableProviders: [ProviderInfo] = []
    var availableAgents: [AgentInfo] = []
    var availableModels: [(providerID: String, modelID: String, name: String)] = []
    var availableCommands: [CommandInfo] = []
    var providerDefaults: [String: String] = [:]

    var builtInCommands: [CommandInfo] {
        [
            CommandInfo(name: "sessions", description: "List or switch sessions"),
            CommandInfo(name: "resume", description: "Resume a session"),
            CommandInfo(name: "continue", description: "Continue a session"),
            CommandInfo(name: "models", description: "List or select models"),
            CommandInfo(name: "export", description: "Export conversation as Markdown"),
            CommandInfo(name: "help", description: "Show help"),
            CommandInfo(name: "themes", description: "List themes"),
            CommandInfo(name: "connect", description: "Configure AI providers"),
        ]
    }

    var sentMessageHistory: [String] = []
    var historyIndex: Int?

    var sessionSearchText = ""
    var hasMoreMessages = false
    var hasMoreSessions = false
    var childSessions: [String: [Session]] = [:]
    var expandedSessions: Set<String> = []

    private static let popularProviders = [
        "opencode", "opencode-go", "anthropic", "github-copilot", "openai", "google", "openrouter",
        "vercel",
    ]

    private(set) var client: OpenCodeClient?
    private var eventTask: Task<Void, Never>?
    private var sessionReloadTask: Task<Void, Never>?
    private var sendTimeoutTask: Task<Void, Never>?
    private var debouncedMessageRecoveryTask: Task<Void, Never>?
    private var isStreamingDeltas = false
    private var sessionPageLimit = 50
    private var messagePageLimit = 50
    private let pageSize = 50
    private var currentSendOperationID: UUID?
    var pendingOptimisticMessages: [String: PendingOptimisticMessage] = [:]
    private var draftStore = DraftStore()
    private var drafts: [String: PromptDraft] = [:]
    private var permissionsBySession: [String: [Permission]] = [:]
    private var questionsBySession: [String: [Question]] = [:]
    private var respondedPermissionIDs: Set<String> = []
    private var respondedQuestionIDs: Set<String> = []
    private var permissionStore: PermissionStore?
    private var hasPreviouslyLoadedPermissions = false
    private var dismissedPermissionIDs: Set<String> = []
    private var dismissedQuestionIDs: Set<String> = []
    private var bufferedDeltas: [String: [BufferedDelta]] = [:]
    private var isRestoringSelectionDuringSend = false
    private var sessionSelectedModels: [String: ModelRefBody] = [:]
    private var optimisticToServerMessageIds: [String: String] = [:]
    private var sessionDirectoryIndex: [String: String] = [:]
    var settings: SettingsViewModel?
    var nextTUIRequest: TUIControlRequest?

    // Built-in command sheet/picker signals
    var showHelp = false
    var showSessionPicker = false
    var showModelPicker = false
    var showThemePicker = false
    var showConnectionSettings = false
    var exportMarkdown: String? = nil

    @ObservationIgnored
    private var _cachedGroups: [(name: String, directory: String, sessions: [Session])]?

    init() {
        drafts = draftStore.load()
    }

    var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionId }
    }

    var filteredArchivedSessions: [Session] {
        guard !sessionSearchText.isEmpty else { return archivedSessions }
        let query = sessionSearchText.lowercased()
        return archivedSessions.filter {
            $0.displayTitle.lowercased().contains(query)
                || $0.directory.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    var isSessionBusy: Bool {
        guard let id = selectedSessionId else { return false }
        return sessionStatuses[id]?.status == "busy"
    }

    var sessionGroups: [(name: String, directory: String, sessions: [Session])] {
        if let cached = _cachedGroups { return cached }
        let filtered = filteredSessions
        let grouped = Dictionary(grouping: filtered) { $0.directory }
        let result: [(name: String, directory: String, sessions: [Session])] =
            grouped
            .map { (dir, sess) -> (name: String, directory: String, sessions: [Session]) in
                let name = sess.first?.workspaceName ?? dir
                let sessions = sess.sorted { lhs, rhs in
                    (lhs.time.updated ?? lhs.time.created) > (rhs.time.updated ?? rhs.time.created)
                }
                return (name: name, directory: dir, sessions: sessions)
            }
            .sorted { lhs, rhs in
                let lhsTime = lhs.sessions.first.map { $0.time.updated ?? $0.time.created } ?? 0
                let rhsTime = rhs.sessions.first.map { $0.time.updated ?? $0.time.created } ?? 0
                return lhsTime > rhsTime
            }
        _cachedGroups = result
        return result
    }

    var filteredSessions: [Session] {
        let recencyThreshold: TimeInterval = 14 * 24 * 60 * 60  // 14 days in seconds
        let now = Date().timeIntervalSince1970
        let threshold = now - recencyThreshold

        if sessionSearchText.isEmpty && !showAllSessions {
            var filtered = sessions.filter { session in
                let lastActivity = Double(session.time.updated ?? session.time.created) / 1000.0
                return lastActivity >= threshold || session.id == selectedSessionId
            }
            return filtered
        }

        if sessionSearchText.isEmpty {
            return sessions
        }

        let query = sessionSearchText.lowercased()
        return sessions.filter {
            $0.displayTitle.lowercased().contains(query)
                || $0.directory.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    var hasOlderSessionsHidden: Bool {
        guard sessionSearchText.isEmpty && !showAllSessions else { return false }
        let recencyThreshold: TimeInterval = 14 * 24 * 60 * 60
        let now = Date().timeIntervalSince1970
        let threshold = now - recencyThreshold

        let totalRecentCount = sessions.filter { session in
            let lastActivity = Double(session.time.updated ?? session.time.created) / 1000.0
            return lastActivity >= threshold || session.id == selectedSessionId
        }.count

        return totalRecentCount < sessions.count
    }

    var availableDirectories: [(name: String, path: String)] {
        let dirs = Set(sessions.map(\.directory))
        return
            dirs
            .map { path in
                let components = path.split(separator: "/")
                let name = components.last.map(String.init) ?? path
                return (name: name, path: path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var projectDirectories: [(name: String, path: String)] {
        var seen = Set<String>()
        var options: [(name: String, path: String)] = []
        for project in projects {
            if seen.insert(project.worktree).inserted {
                options.append((name: project.displayPath, path: project.worktree))
            }
            for sandbox in project.sandboxes ?? [] where seen.insert(sandbox).inserted {
                let name = sandbox.split(separator: "/").last.map(String.init) ?? sandbox
                options.append((name: name, path: sandbox))
            }
        }
        return options
    }

    var hasQuestion: Bool {
        guard let selectedSessionId else { return false }
        return pendingQuestions.contains { $0.sessionID == selectedSessionId }
    }

    var selectedPendingPermissions: [Permission] {
        guard let selectedSessionId else { return [] }
        return pendingPermissions.filter { $0.sessionID == selectedSessionId }
    }

    var crossSessionPendingPermissions: [Permission] {
        pendingPermissions.filter { $0.sessionID != selectedSessionId && !respondedPermissionIDs.contains($0.id) }
    }

    var activelyPendingPermissions: [Permission] {
        pendingPermissions.filter { !respondedPermissionIDs.contains($0.id) }
    }

    var activelyPendingQuestions: [Question] {
        pendingQuestions.filter { !respondedQuestionIDs.contains($0.id) }
    }

    var selectedPendingQuestions: [Question] {
        guard let selectedSessionId else { return [] }
        return pendingQuestions.filter { $0.sessionID == selectedSessionId && !respondedQuestionIDs.contains($0.id) }
    }

    var crossSessionPendingQuestions: [Question] {
        pendingQuestions.filter { $0.sessionID != selectedSessionId && !respondedQuestionIDs.contains($0.id) }
    }

    var hasDeferredQuestion: Bool {
        crossSessionPendingQuestions.isEmpty == false
    }

    func isQuestionResponded(_ questionID: String) -> Bool {
        respondedQuestionIDs.contains(questionID)
    }

    func dismissPermission(_ permission: Permission) {
        dismissedPermissionIDs.insert(permission.id)
        permissionStore?.saveDismissedPermissions(dismissedPermissionIDs)
        refreshPendingStateForSelectedSession()
    }

    func dismissQuestion(_ question: Question) {
        dismissedQuestionIDs.insert(question.id)
        permissionStore?.saveDismissedQuestions(dismissedQuestionIDs)
        refreshPendingStateForSelectedSession()
    }

    func dismissAllPermissions(for sessionID: String) {
        let ids = permissionsBySession[sessionID]?.map(\.id) ?? []
        dismissedPermissionIDs.formUnion(ids)
        permissionStore?.saveDismissedPermissions(dismissedPermissionIDs)
        refreshPendingStateForSelectedSession()
    }

    func dismissAllQuestions(for sessionID: String) {
        let ids = questionsBySession[sessionID]?.map(\.id) ?? []
        dismissedQuestionIDs.formUnion(ids)
        permissionStore?.saveDismissedQuestions(dismissedQuestionIDs)
        refreshPendingStateForSelectedSession()
    }

    func pendingQuestionCount(for sessionID: String) -> Int {
        pendingQuestions.filter { $0.sessionID == sessionID && !respondedQuestionIDs.contains($0.id) }.count
    }

    // MARK: - Configuration

    func configure(with client: OpenCodeClient?, serverURL: String? = nil) {
        self.client = client
        if let url = serverURL {
            permissionStore = PermissionStore(serverURL: url)
            loadPersistedResponses()
        }
        logger.info("configure: client is \(client != nil ? "set" : "nil")")
    }

    private func loadPersistedResponses() {
        guard let store = permissionStore else { return }
        respondedPermissionIDs = store.loadPermissions()
        respondedQuestionIDs = store.loadQuestions()
        dismissedPermissionIDs = store.loadDismissedPermissions()
        dismissedQuestionIDs = store.loadDismissedQuestions()
        logger.info("Loaded \(self.respondedPermissionIDs.count) persisted permissions, \(self.respondedQuestionIDs.count) questions, \(self.dismissedPermissionIDs.count) dismissed permissions, \(self.dismissedQuestionIDs.count) dismissed questions")
    }

    func loadProjectInfo() async {
        await loadProjects()
    }

    func loadServerInfo() async {
        guard client != nil else { return }
        async let providersTask: () = await loadProviders()
        async let agentsTask: () = await loadAgents()
        async let vcsTask: () = await loadVcs()
        async let commandsTask: () = await loadCommands()
        _ = await (providersTask, agentsTask, vcsTask, commandsTask)
    }

    private func loadProjects() async {
        guard let client else {
            logger.error("loadProjects: no client configured")
            return
        }
        logger.info("loadProjects: fetching current project...")
        do {
            currentProject = try await client.getCurrentProject()
            logger.info(
                "loadProjects: current project = \(self.currentProject?.displayPath ?? "nil")")
        } catch {
            logger.error("loadProjects: failed to load current project: \(error)")
        }
        logger.info("loadProjects: fetching project list...")
        do {
            projects = try await client.listProjects()
            logger.info("loadProjects: loaded \(self.projects.count) projects")
        } catch {
            logger.error("loadProjects: failed to list projects: \(error)")
        }
        let dirs = projectDirectories
        logger.info("loadProjects: resolved \(dirs.count) directories: \(dirs.map(\.path))")
    }

    private func loadProviders() async {
        guard let client else { return }
        do {
            let configResponse = try await client.listConfigProviders()
            availableProviders = configResponse.providers ?? []
            providerDefaults = configResponse.defaultModels ?? [:]
            logger.info("Loaded \(self.availableProviders.count) connected providers")

            if selectedModel == nil {
                let popular = Self.popularProviders
                let sortedDefaults = providerDefaults.sorted { a, b in
                    let aIdx = popular.firstIndex(of: a.key) ?? Int.max
                    let bIdx = popular.firstIndex(of: b.key) ?? Int.max
                    if aIdx != bIdx { return aIdx < bIdx }
                    return a.key < b.key
                }
                if let firstDefault = sortedDefaults.first {
                    selectedModel = ModelRefBody(
                        providerID: firstDefault.key,
                        modelID: firstDefault.value
                    )
                }
            }

            var models: [(providerID: String, modelID: String, name: String)] = []
            for provider in availableProviders {
                if let providerModels = provider.models {
                    let activeModels = providerModels.filter { $0.value.isDeprecated != true }
                    logger.info("Provider \(provider.id): \(activeModels.count) active models")
                    for (modelID, model) in activeModels {
                        let name = model.name ?? modelID
                        models.append((providerID: provider.id, modelID: modelID, name: name))
                    }
                }
            }

            let popular = Self.popularProviders
            models.sort { a, b in
                let aPop = popular.firstIndex(of: a.providerID) ?? Int.max
                let bPop = popular.firstIndex(of: b.providerID) ?? Int.max
                if aPop != bPop { return aPop < bPop }
                if a.providerID != b.providerID {
                    return a.providerID.localizedCaseInsensitiveCompare(b.providerID)
                        == .orderedAscending
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            availableModels = models
            logger.info("Total \(self.availableModels.count) models available")
        } catch {
            logger.error("Failed to load providers: \(error)")
        }
    }

    private func loadAgents() async {
        guard let client else { return }
        do {
            let all = try await client.listAgents()
            availableAgents = all.filter { agent in
                guard agent.builtIn != true else { return false }
                let mode = agent.mode ?? "primary"
                return mode == "primary" || mode == "all"
            }
            logger.info("Loaded \(all.count) agents, \(self.availableAgents.count) selectable")
        } catch {
            logger.error("Failed to load agents: \(error)")
        }
    }

    private func loadVcs() async {
        guard let client else { return }
        do {
            let vcs = try await client.getVcs()
            vcsBranch = vcs.branch
            logger.info("VCS branch: \(vcs.branch ?? "none")")
        } catch {
            logger.error("Failed to load VCS: \(error)")
        }
    }

    private func loadCommands() async {
        guard let client else { return }
        do {
            availableCommands = try await client.listCommands()
            logger.info("Loaded \(self.availableCommands.count) commands")
        } catch {
            logger.error("Failed to load commands: \(error)")
        }
    }

    func loadWorkspaces() async {
        guard let client else { return }
        do {
            _ = try await client.listWorkspaces()
            logger.info("Loaded workspaces")
        } catch {
            logger.error("Failed to load workspaces: \(error)")
        }
    }

    // MARK: - Sessions

    func loadSessions(resetLimit: Bool = true) async {
        let txn = CrashReporter.transaction(name: "chat.loadSessions", operation: "session")
        defer { txn?.finish() }
        guard let client else {
            logger.error("loadSessions: no client configured")
            return
        }
        if resetLimit { sessionPageLimit = pageSize }
        isLoadingSessions = true
        errorMessage = nil
        if projects.isEmpty {
            logger.info("loadSessions: projects empty, loading first...")
            await loadProjects()
        }
        let directories = projectDirectories.map(\.path)
        let sessionLimit = sessionPageLimit
        logger.info("loadSessions: querying \(directories.count) directories: \(directories)")
        if directories.isEmpty {
            logger.warning(
                "loadSessions: no directories to query — projectDirectories returned empty")
        }
        let directoriesToQuery: [String?] = directories.isEmpty ? [nil] : directories
        let results = await withTaskGroup(
            of: (label: String, sessions: [Session], error: String?).self,
            returning: [(label: String, sessions: [Session], error: String?)].self
        ) { group in
            for directory in directoriesToQuery {
                group.addTask {
                    do {
                        let sessions = try await client.listSessions(
                            directory: directory, roots: true, limit: sessionLimit, archived: true)
                        return (label: directory ?? "default", sessions: sessions, error: nil)
                    } catch {
                        return (
                            label: directory ?? "default", sessions: [],
                            error: error.localizedDescription
                        )
                    }
                }
            }
            var results: [(label: String, sessions: [Session], error: String?)] = []
            for await result in group {
                self.logger.info(
                    "loadSessions: directory '\(result.label)' returned \(result.sessions.count) sessions\(result.error != nil ? " error: \(result.error!)" : "")"
                )
                results.append(result)
            }
            return results
        }
        let failures = results.compactMap { result -> String? in
            guard let error = result.error else { return nil }
            logger.error("Failed to load sessions for \(result.label): \(error)")
            let err = NSError(
                domain: "ChatViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: error])
            SentrySDK.capture(error: err) { scope in
                scope.setTag(value: result.label, key: "directory")
                scope.setTag(value: "loadSessions", key: "eventType")
            }
            return "\(result.label): \(error)"
        }
        let allSessions = results.flatMap(\.sessions)
        logger.info(
            "loadSessions: raw total = \(allSessions.count) sessions from \(results.count) directories (\(failures.count) failures)"
        )
        if allSessions.isEmpty && failures.count == results.count {
            errorMessage = "Failed to load sessions: \(failures.first ?? "Unknown error")"
        }
        hasMoreSessions = results.contains { $0.sessions.count >= sessionLimit }
        var seen = Set<String>()
        var deduped = allSessions.filter { session in
            guard !seen.contains(session.id) else { return false }
            seen.insert(session.id)
            return true
        }
        logger.info(
            "loadSessions: after dedup filter = \(deduped.count) (removed \(allSessions.count - deduped.count))"
        )
        var fresh = sortSessions(deduped.filter { !$0.isArchived })
        let archived = sortSessions(deduped.filter(\.isArchived))
        logger.info("loadSessions: active = \(fresh.count), archived = \(archived.count)")
        if isSending,
            let selectedSessionId,
            !fresh.contains(where: { $0.id == selectedSessionId }),
            let selectedSession,
            !selectedSession.isArchived
        {
            fresh.append(selectedSession)
            fresh = sortSessions(fresh)
        }
        cacheDirectories(for: deduped)
        sessions = fresh
        archivedSessions = archived
        if let selectedSessionId, !sessions.contains(where: { $0.id == selectedSessionId }),
            !isSending
        {
            self.selectedSessionId = nil
            messages = []
            todos = []
            fileDiffs = []
        }
        logger.info("loadSessions: final count = \(self.sessions.count) sessions")
        isLoadingSessions = false
    }

    func loadMoreSessions() async {
        guard hasMoreSessions, !isLoadingSessions else { return }
        sessionPageLimit += pageSize
        await loadSessions(resetLimit: false)
    }

    private func enrichSessionsWithSummary() async {
        guard let client else { return }
        let sessionsToFetch = sessions.filter { $0.summary == nil }
        guard !sessionsToFetch.isEmpty else { return }
        logger.info(
            "enrichSessionsWithSummary: fetching details for \(sessionsToFetch.count) sessions without summary"
        )
        let logger = logger
        let updatedSessions = await withTaskGroup(of: Session?.self, returning: [Session].self) {
            group in
            for session in sessionsToFetch {
                group.addTask {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    return try? await client.getSession(session.id, directory: session.directory) ?? nil
                }
            }
            var results: [Session] = []
            for await session in group {
                if let session { results.append(session) }
            }
            return results
        }
        guard !updatedSessions.isEmpty else { return }
        var sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for updated in updatedSessions {
            sessionMap[updated.id] = updated
        }
        sessions = sessions.compactMap { sessionMap[$0.id] }
        logger.info(
            "enrichSessionsWithSummary: updated \(updatedSessions.count) sessions with summary data"
        )
    }

    func selectSession(_ sessionId: String) async {
        selectedSessionId = sessionId
        messagePageLimit = pageSize
        await loadMessages()
        await loadTodos()
        await loadSessionDiffs()
        await loadPendingRequests(for: sessionId)
    }

    func refreshSelectedSession() async {
        guard let client, let sessionId = selectedSessionId else { return }
        let sessionDirectory = directory(for: sessionId)

        do {
            let refreshedSession = try await client.getSession(sessionId, directory: sessionDirectory)
            guard selectedSessionId == sessionId else { return }
            replaceSelectedSession(refreshedSession)
        } catch {
            logger.warning("refreshSelectedSession: failed to refresh session metadata: \(error)")
        }

        await loadMessages()
        await loadTodos()
        await loadSessionDiffs()
        await loadPendingRequests(for: sessionId)
        clearStaleSendingStateIfSessionIsComplete(sessionId: sessionId)
    }

    func directory(for sessionId: String?) -> String? {
        guard let sessionId else { return nil }
        if let activeDirectory = sessions.first(where: { $0.id == sessionId })?.directory {
            return activeDirectory
        }
        if let archivedDirectory = archivedSessions.first(where: { $0.id == sessionId })?.directory
        {
            return archivedDirectory
        }
        return sessionDirectoryIndex[sessionId]
    }

    func createSession() async {
        guard let client else { return }
        let title = newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard let directory = selectedDirectory else {
            errorMessage = "Select a workspace before creating a session"
            return
        }
        newSessionTitle = ""
        isSending = false
        isStreamingDeltas = false
        inputText = ""
        attachedParts = []
        do {
            let session = try await client.createSession(title: title, directory: directory)
            sessions.insert(session, at: 0)
            selectedSessionId = session.id
            messages = []
            clearDraft(for: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleNewSessionCommand() async {
        guard let client, let directory = selectedDirectory else {
            errorMessage = "Select a workspace before creating a session"
            return
        }
        let title = "New Session \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        do {
            let session = try await client.createSession(title: title, directory: directory)
            sessions.insert(session, at: 0)
            selectedSessionId = session.id
            messages = []
            clearDraft(for: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Built-In Command Handlers

    func handleBuiltInCommand(_ commandName: String, arguments: String) async -> Bool {
        switch commandName {
        case "new", "clear":
            await handleNewSessionCommand()
            return true
        case "share":
            await shareSession()
            return true
        case "sessions", "resume", "continue":
            await handleSessionsCommand(arguments)
            return true
        case "models":
            handleModelsCommand(arguments)
            return true
        case "export":
            await handleExportCommand()
            return true
        case "help":
            showHelp = true
            return true
        case "themes":
            showThemePicker = true
            return true
        case "connect":
            showConnectionSettings = true
            return true
        case "editor", "exit", "quit", "q":
            errorMessage = "/\(commandName) is not available on iOS"
            return true
        default:
            return false
        }
    }

    func handleSessionsCommand(_ arguments: String) async {
        guard !arguments.isEmpty else {
            showSessionPicker = true
            return
        }
        let query = arguments.lowercased()
        if let match = sessions.first(where: { $0.displayTitle.lowercased().contains(query) || $0.id == query }) {
            await selectSession(match.id)
        } else {
            showSessionPicker = true
        }
    }

    func handleModelsCommand(_ arguments: String) {
        guard !arguments.isEmpty else {
            showModelPicker = true
            return
        }
        let query = arguments.lowercased()
        if let match = availableModels.first(where: { $0.modelID.lowercased().contains(query) || $0.name.lowercased().contains(query) }) {
            selectedModel = ModelRefBody(providerID: match.providerID, modelID: match.modelID)
        } else {
            showModelPicker = true
        }
    }

    func handleExportCommand() async {
        let markdown = generateMarkdownFromMessages(messages)
        exportMarkdown = markdown
    }

    func shareExportedMarkdown() {
        guard let markdown = exportMarkdown else { return }
        let activityVC = UIActivityViewController(activityItems: [markdown], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        exportMarkdown = nil
    }

    func generateMarkdownFromMessages(_ messages: [MessageEnvelope]) -> String {
        var md = "# OpenCode Session\n\n"
        if let session = selectedSession {
            md += "**Session:** \(session.displayTitle)\n"
            md += "**ID:** \(session.id)\n\n"
        }
        md += "---\n\n"
        for envelope in messages {
            let role = envelope.info.role.displayName
            md += "## \(role)\n\n"
            for part in envelope.parts {
                if part.type == "text", let text = part.text {
                    md += "\(text)\n\n"
                } else if part.type == "tool", let text = part.text {
                    md += "```\n\(text)\n```\n\n"
                }
            }
        }
        return md
    }

    func prepareNewSession() {
        if let session = selectedSession {
            selectedDirectory = session.directory
        } else if selectedDirectory == nil {
            selectedDirectory = projectDirectories.first?.path ?? availableDirectories.first?.path
        }
    }

    func renameSession(_ sessionId: String, title: String) async {
        guard let client else { return }
        do {
            let updated = try await client.updateSession(
                sessionId, title: title, directory: directory(for: sessionId))
            if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[idx] = updated
            } else if let idx = archivedSessions.firstIndex(where: { $0.id == sessionId }) {
                archivedSessions[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(_ sessionId: String) async {
        guard let client else { return }
        do {
            let success = try await client.deleteSession(
                id: sessionId, directory: directory(for: sessionId))
            if success {
                withAnimation {
                    sessions.removeAll { $0.id == sessionId }
                    archivedSessions.removeAll { $0.id == sessionId }
                }
                if selectedSessionId == sessionId {
                    selectedSessionId = nil
                    messages = []
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forkSession(at messageID: String? = nil) async {
        guard let client, let sessionId = selectedSessionId else { return }
        isSending = false
        isStreamingDeltas = false
        inputText = ""
        attachedParts = []
        do {
            let forked = try await client.forkSession(
                sessionId, messageID: messageID, directory: directory(for: sessionId))
            sessions.insert(forked, at: 0)
            selectedSessionId = forked.id
            messages = []
            clearDraft(for: forked.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shareSession(_ sessionId: String? = nil) async {
        guard let client, let sessionId = sessionId ?? selectedSessionId else { return }
        do {
            let updated = try await client.shareSession(
                sessionId, directory: directory(for: sessionId))
            if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[idx] = updated
            } else if let idx = archivedSessions.firstIndex(where: { $0.id == sessionId }) {
                archivedSessions[idx] = updated
            }
            if let url = updated.share?.url {
                UIPasteboard.general.string = url
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func archiveSession(_ sessionId: String? = nil) async {
        guard let client, let sessionId = sessionId ?? selectedSessionId else { return }
        do {
            let updated = try await client.archiveSession(
                sessionId, directory: directory(for: sessionId))
            cacheDirectory(for: updated)
            withAnimation {
                sessions.removeAll { $0.id == sessionId }
                upsertSession(updated, in: &archivedSessions)
            }
            if selectedSessionId == sessionId {
                selectedSessionId = nil
                messages = []
                todos = []
                fileDiffs = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unarchiveSession(_ sessionId: String) async {
        guard let client else { return }
        do {
            let updated = try await client.unarchiveSession(
                sessionId, directory: directory(for: sessionId))
            cacheDirectory(for: updated)
            archivedSessions.removeAll { $0.id == sessionId }
            upsertSession(updated, in: &sessions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sortSessions(_ sessions: [Session]) -> [Session] {
        sessions.sorted { lhs, rhs in
            (lhs.time.updated ?? lhs.time.created) > (rhs.time.updated ?? rhs.time.created)
        }
    }

    private func upsertSession(_ session: Session, in collection: inout [Session]) {
        if let idx = collection.firstIndex(where: { $0.id == session.id }) {
            collection[idx] = session
        } else {
            collection.append(session)
        }
        collection = sortSessions(collection)
    }

    private func cacheDirectories(for sessions: [Session]) {
        for session in sessions {
            cacheDirectory(for: session)
        }
    }

    private func cacheDirectory(for session: Session) {
        sessionDirectoryIndex[session.id] = session.directory
    }

    private func replaceSelectedSession(_ session: Session) {
        cacheDirectory(for: session)
        if session.isArchived {
            sessions.removeAll { $0.id == session.id }
            upsertSession(session, in: &archivedSessions)
        } else {
            archivedSessions.removeAll { $0.id == session.id }
            upsertSession(session, in: &sessions)
        }
    }

    func loadChildSessions(for sessionId: String) async {
        guard let client else { return }
        do {
            let children = try await client.getChildren(
                sessionId, directory: directory(for: sessionId))
            childSessions[sessionId] = children
        } catch {
            logger.error("Failed to load child sessions: \(error)")
        }
    }

    func toggleSessionExpansion(_ sessionId: String) {
        if expandedSessions.contains(sessionId) {
            expandedSessions.remove(sessionId)
        } else {
            expandedSessions.insert(sessionId)
            if childSessions[sessionId] == nil {
                Task { await loadChildSessions(for: sessionId) }
            }
        }
    }

    func revertMessage(_ messageID: String, partID: String? = nil) async {
        guard let client, let sessionId = selectedSessionId else { return }
        do {
            try await client.revertMessage(
                sessionId, messageID: messageID, partID: partID,
                directory: directory(for: sessionId))
            await loadMessages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Messages

    func loadMessages() async {
        guard let client, let sessionId = selectedSessionId else { return }
        let directory = directory(for: sessionId)
        isLoadingMessages = true
        defer {
            if selectedSessionId == sessionId {
                isLoadingMessages = false
            }
        }
        do {
            let loaded = try await client.getMessages(
                sessionId: sessionId, directory: directory, limit: messagePageLimit)
            guard selectedSessionId == sessionId else { return }
            messages = reconciledMessages(loaded: loaded, existing: messages, sessionId: sessionId)
            bufferedDeltas[sessionId] = nil
            applyBufferedDeltas(for: sessionId)
            hasMoreMessages = loaded.count >= messagePageLimit
        } catch {
            logger.error("Failed to load messages: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            SentrySDK.capture(error: error) { scope in
                scope.setTag(value: sessionId, key: "sessionId")
                scope.setTag(value: "loadMessages", key: "eventType")
            }
        }
    }

    func loadMoreMessages() async {
        guard let client, let sessionId = selectedSessionId, hasMoreMessages, !isLoadingMessages
        else { return }
        let directory = directory(for: sessionId)
        isLoadingMessages = true
        defer {
            if selectedSessionId == sessionId {
                isLoadingMessages = false
            }
        }
        do {
            let oldestLoadedId = messages.first { !pendingOptimisticMessages.keys.contains($0.id) }?
                .id
            let older = try await client.getMessages(
                sessionId: sessionId, directory: directory, limit: pageSize, before: oldestLoadedId)
            guard selectedSessionId == sessionId else { return }
            if older.count < pageSize {
                hasMoreMessages = false
            }
            let existingIds = Set(messages.map(\.id))
            let newMessages = older.filter { !existingIds.contains($0.id) }
            if newMessages.isEmpty, !older.isEmpty {
                messagePageLimit += pageSize
                let expanded = try await client.getMessages(
                    sessionId: sessionId, directory: directory, limit: messagePageLimit)
                guard selectedSessionId == sessionId else { return }
                messages = reconciledMessages(
                    loaded: expanded, existing: messages, sessionId: sessionId)
                applyBufferedDeltas(for: sessionId)
                hasMoreMessages = expanded.count >= messagePageLimit
            } else {
                messages = newMessages + messages
            }
        } catch {
            logger.warning(
                "Cursor message pagination failed, falling back to expanded limit: \(error.localizedDescription)"
            )
            do {
                messagePageLimit += pageSize
                let expanded = try await client.getMessages(
                    sessionId: sessionId, directory: directory, limit: messagePageLimit)
                guard selectedSessionId == sessionId else { return }
                messages = reconciledMessages(
                    loaded: expanded, existing: messages, sessionId: sessionId)
                applyBufferedDeltas(for: sessionId)
                hasMoreMessages = expanded.count >= messagePageLimit
            } catch {
                logger.error("Failed to load more messages: \(error)")
            }
        }
    }

    func sendMessage(attachedParts: [MessagePartBody] = []) async {
        let txn = CrashReporter.transaction(name: "chat.sendMessage", operation: "message")
        defer { txn?.finish() }
        guard !isSending else { return }
        let partsToSend = attachedParts.isEmpty ? self.attachedParts : attachedParts
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, let sessionId = selectedSessionId, !text.isEmpty || !partsToSend.isEmpty
        else { return }
        logger.info(
            "sendMessage: session=\(sessionId), text length=\(text.count), parts=\(partsToSend.count), model=\(self.selectedModel?.modelID ?? "nil"), agent=\(self.selectedAgent ?? "nil")"
        )

        if isSlashCommandInput(text) {
            if !partsToSend.isEmpty {
                errorMessage =
                    "Slash commands do not support attachments. Remove attachments or send this as a normal prompt."
                return
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let commandName = String(trimmed.dropFirst()).split(separator: " ").first ?? ""
            if commandName == "new" || commandName == "clear" {
                await handleNewSessionCommand()
                return
            }
            await sendCommand(text: trimmed)
            return
        }

        inputText = ""
        self.attachedParts = []
        isSending = true
        isStreamingDeltas = false
        appendToHistory(text)

        let optimisticId =
            "msg_ios_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        let optimisticMessage = createOptimisticUserMessage(
            id: optimisticId, text: text, attachedParts: partsToSend)
        pendingOptimisticMessages[optimisticId] = PendingOptimisticMessage(
            id: optimisticId, sessionID: sessionId, text: text,
            created: optimisticMessage.info.time.created)
        messages.append(optimisticMessage)

        let sendOperationID = UUID()
        currentSendOperationID = sendOperationID
        do {
            try await client.sendAsyncMessage(
                sessionId: sessionId,
                text: text,
                messageID: optimisticId,
                model: selectedModel,
                agent: selectedAgent,
                parts: partsToSend,
                directory: directory(for: sessionId)
            )
            clearDraft(for: sessionId)
            sendTimeoutTask?.cancel()
            sendTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard let self, self.isSending, self.selectedSessionId == sessionId,
                    self.currentSendOperationID == sendOperationID
                else { return }
                self.resetSendingState(for: sessionId)
                self.errorMessage = "Server took too long to respond. Check connection and try again."
                let timeoutError = NSError(
                    domain: "ChatViewModel", code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Server took too long to respond"
                    ])
                SentrySDK.capture(error: timeoutError) { scope in
                    scope.setTag(value: sessionId, key: "sessionId")
                    scope.setTag(value: "sendTimeout", key: "eventType")
                }
                #if DEBUG
                    print(
                        "[ChatViewModel] sendTimeoutTask fired for session \(sessionId), operationID \(sendOperationID)"
                    )
                #endif
            }
        } catch {
            messages.removeAll { $0.id == optimisticId }
            pendingOptimisticMessages[optimisticId] = nil
            optimisticToServerMessageIds.removeValue(forKey: optimisticId)
            errorMessage = error.localizedDescription
            let sendError = NSError(
                domain: "ChatViewModel", code: -3,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
            SentrySDK.capture(error: sendError) { scope in
                scope.setTag(value: sessionId, key: "sessionId")
                scope.setTag(value: "sendMessageError", key: "eventType")
            }
            inputText = text
            self.attachedParts = partsToSend
            isSending = false
            currentSendOperationID = nil
            #if DEBUG
                print("[ChatViewModel] sendMessage error for session \(sessionId): \(error)")
            #endif
        }
    }

    func sendCommand(text: String) async {
        guard let client, let sessionId = selectedSessionId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return }

        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        guard let firstPart = parts.first else {
            errorMessage = "Enter a slash command name."
            inputText = trimmed
            return
        }
        let commandName = String(firstPart)
        let arguments = parts.count > 1 ? String(parts[1]) : ""

        inputText = ""
        isSending = true
        appendToHistory(trimmed)

        do {
            let _ = try await client.sendCommand(
                sessionId: sessionId,
                command: commandName,
                arguments: arguments,
                model: selectedModel,
                agent: selectedAgent,
                directory: directory(for: sessionId)
            )
            await loadMessages()
            isSending = false
        } catch {
            errorMessage = error.localizedDescription
            inputText = trimmed
            isSending = false
        }
    }

    func deleteMessage(_ messageID: String) async {
        guard let client, let sessionId = selectedSessionId else { return }
        do {
            try await client.deleteMessage(
                sessionId: sessionId, messageID: messageID, directory: directory(for: sessionId))
            messages.removeAll { $0.id == messageID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func abortSession() async {
        guard let client, let sessionId = selectedSessionId else { return }
        do {
            try await client.abortSession(
                sessionId: sessionId, directory: directory(for: sessionId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendShellCommand(_ command: String) async {
        guard let client, let sessionId = selectedSessionId else { return }
        isSending = true
        appendToHistory("! \(command)")
        do {
            let _ = try await client.sendShellCommand(
                sessionId: sessionId,
                command: command,
                model: selectedModel,
                agent: selectedAgent,
                directory: directory(for: sessionId)
            )
            await loadMessages()
            isSending = false
        } catch {
            errorMessage = error.localizedDescription
            isSending = false
        }
    }

    // MARK: - Follow-up Queue

    func queueFollowUpPrompt() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let sessionId = selectedSessionId else { return }
        queuedMessages[sessionId, default: []].append(text)
        inputText = ""
    }

    func submitQueuedPrompt() async {
        guard let sessionId = selectedSessionId else { return }
        guard !(queuedMessages[sessionId] ?? []).isEmpty else { return }
        if !isSending {
            await sendNextQueuedMessage(for: sessionId)
        }
    }

    func clearQueuedPrompt() {
        guard let sessionId = selectedSessionId else { return }
        queuedMessages[sessionId] = []
    }

    private func sendNextQueuedMessage(for sessionId: String) async {
        guard client != nil, !isSending else { return }
        guard var queue = queuedMessages[sessionId], !queue.isEmpty else { return }
        let text = queue.removeFirst()
        queuedMessages[sessionId] = queue
        inputText = text
        await sendMessage(attachedParts: [])
    }

    func respondToTUIRequest(_ body: [String: JSONValue]) async {
        guard let client else { return }
        do {
            _ = try await client.respondToTUIRequest(
                body: body, directory: directory(for: selectedSessionId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Drafts

    private func saveDraft(for sessionId: String?) {
        guard let sessionId else { return }
        let draft = PromptDraft(text: inputText, attachments: attachedParts)
        if draft.text.isEmpty && draft.attachments.isEmpty {
            drafts.removeValue(forKey: sessionId)
        } else {
            drafts[sessionId] = draft
        }
        draftStore.save(drafts)
    }

    private func restoreDraft(for sessionId: String?) {
        guard let sessionId, let draft = drafts[sessionId] else {
            inputText = ""
            attachedParts = []
            return
        }
        inputText = draft.text
        attachedParts = draft.attachments
    }

    private func clearDraft(for sessionId: String) {
        drafts.removeValue(forKey: sessionId)
        draftStore.save(drafts)
    }

    func draft(for sessionId: String) -> PromptDraft? {
        drafts[sessionId]
    }

    // MARK: - Prompt History

    private func appendToHistory(_ text: String) {
        guard !text.isEmpty else { return }
        sentMessageHistory.insert(text, at: 0)
        if sentMessageHistory.count > 100 {
            sentMessageHistory.removeLast()
        }
        historyIndex = nil
    }

    func navigateHistory(_ direction: HistoryDirection) {
        guard !sentMessageHistory.isEmpty else { return }
        switch direction {
        case .up:
            if let idx = historyIndex {
                if idx + 1 < sentMessageHistory.count {
                    historyIndex = idx + 1
                    inputText = sentMessageHistory[idx + 1]
                }
            } else {
                historyIndex = 0
                inputText = sentMessageHistory[0]
            }
        case .down:
            if let idx = historyIndex {
                if idx > 0 {
                    historyIndex = idx - 1
                    inputText = sentMessageHistory[idx - 1]
                } else {
                    historyIndex = nil
                    inputText = ""
                }
            }
        }
    }

    enum HistoryDirection {
        case up, down
    }

    // MARK: - Optimistic Messages

    private func createOptimisticUserMessage(
        id: String, text: String, attachedParts: [MessagePartBody] = []
    ) -> MessageEnvelope {
        let info = MessageInfo(
            id: id, sessionID: selectedSessionId, role: .user,
            time: MessageTimeInfo(created: Int64(Date().timeIntervalSince1970 * 1000)),
            agent: selectedAgent
        )
        let part = Part(
            sessionID: selectedSessionId, messageID: id, type: "text",
            text: text
        )
        let fileParts = attachedParts.map { body in
            Part(
                sessionID: selectedSessionId,
                messageID: id,
                type: body.type,
                text: body.text,
                mime: body.mime,
                filename: body.filename,
                url: body.url
            )
        }
        return MessageEnvelope(info: info, parts: [part] + fileParts)
    }

    func isSlashCommandInput(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
    }

    func reconciledMessages(
        loaded: [MessageEnvelope], existing: [MessageEnvelope], sessionId: String
    ) -> [MessageEnvelope] {
        let fiveMinutesAgo = Int64(Date().timeIntervalSince1970 * 1000) - 300_000
        let expiredIds = pendingOptimisticMessages.filter { $0.value.created < fiveMinutesAgo }.map(
            \.key)
        for id in expiredIds {
            pendingOptimisticMessages[id] = nil
        }
        let serverIds = Set(loaded.map(\.id))
        for id in pendingOptimisticMessages.keys where serverIds.contains(id) {
            pendingOptimisticMessages[id] = nil
        }
        var matchedServerIds = Set<String>()
        let sortedPending = pendingOptimisticMessages.values
            .filter { $0.sessionID == sessionId }
            .sorted(by: { $0.created < $1.created })
        for pending in sortedPending {
            if let matchingServerMessage = loaded.first(where: { message in
                guard message.info.isUser, !matchedServerIds.contains(message.id) else {
                    return false
                }
                if messageText(message) == pending.text { return true }
                return abs(message.info.time.created - pending.created) < 5_000
            }) {
                matchedServerIds.insert(matchingServerMessage.id)
                if matchingServerMessage.id != pending.id {
                    optimisticToServerMessageIds[pending.id] = matchingServerMessage.id
                }
                pendingOptimisticMessages[pending.id] = nil
            }
        }
        let pendingMessages = existing.filter { message in
            guard let pending = pendingOptimisticMessages[message.id],
                pending.sessionID == sessionId
            else { return false }
            return !serverIds.contains(message.id)
        }
        return pendingMessages + loaded
    }

    private func messageText(_ message: MessageEnvelope) -> String {
        message.parts.compactMap(\.text).joined(separator: "\n")
    }

    // MARK: - Questions

    func answerQuestion(_ question: Question, answers: [[String]]) async {
        guard let client else { return }
        respondedQuestionIDs.insert(question.id)
        permissionStore?.saveQuestions(respondedQuestionIDs)
        do {
            try await client.replyQuestion(
                question.id, answers: answers, directory: directory(for: question.sessionID))
            removeQuestion(question)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectQuestion(_ question: Question) async {
        guard let client else { return }
        respondedQuestionIDs.insert(question.id)
        permissionStore?.saveQuestions(respondedQuestionIDs)
        do {
            try await client.rejectQuestion(
                question.id, directory: directory(for: question.sessionID))
            removeQuestion(question)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPendingRequests(for sessionId: String) async {
        guard let client else { return }
        let directory = directory(for: sessionId)
        async let permissionsTask: [Permission]? = try? client.listPermissions(directory: directory)
        async let questionsTask: [Question]? = try? client.listQuestions(directory: directory)
        var loadedPermissions = await permissionsTask ?? []
        let loadedQuestions = await questionsTask ?? []
        if let dir = directory, !loadedPermissions.isEmpty {
            loadedPermissions = loadedPermissions.map { perm in
                var mergedMetadata = perm.metadata ?? [:]
                mergedMetadata["directory"] = .string(dir)
                return Permission(
                    id: perm.id,
                    type: perm.type,
                    pattern: perm.pattern,
                    sessionID: perm.sessionID,
                    messageID: perm.messageID,
                    callID: perm.callID,
                    title: perm.title,
                    metadata: mergedMetadata,
                    time: perm.time
                )
            }
        }
        if hasPreviouslyLoadedPermissions && loadedPermissions.isEmpty && !respondedPermissionIDs.isEmpty {
            logger.info("Server appears to have restarted, clearing \(self.respondedPermissionIDs.count) stale permission IDs")
            respondedPermissionIDs.removeAll()
            permissionStore?.savePermissions([])
        }
        if hasPreviouslyLoadedPermissions && loadedQuestions.isEmpty && !respondedQuestionIDs.isEmpty {
            logger.info("Server appears to have restarted, clearing \(self.respondedQuestionIDs.count) stale question IDs")
            respondedQuestionIDs.removeAll()
            permissionStore?.saveQuestions([])
        }
        hasPreviouslyLoadedPermissions = true
        mergePermissions(loadedPermissions)
        mergeQuestions(loadedQuestions.filter { $0.sessionID == sessionId })
    }

    func mergePermissions(_ permissions: [Permission]) {
        for permission in permissions {
            var list = permissionsBySession[permission.sessionID] ?? []
            if !list.contains(where: { $0.id == permission.id }) {
                list.append(permission)
            }
            permissionsBySession[permission.sessionID] = list
        }
        refreshPendingStateForSelectedSession()
    }

    func mergeQuestions(_ questions: [Question]) {
        for question in questions {
            var list = questionsBySession[question.sessionID] ?? []
            if !list.contains(where: { $0.id == question.id }) {
                list.append(question)
            }
            questionsBySession[question.sessionID] = list
        }
        refreshPendingStateForSelectedSession()
    }

    private func removeQuestion(_ question: Question) {
        questionsBySession[question.sessionID]?.removeAll { $0.id == question.id }
        refreshPendingStateForSelectedSession()
    }

    private func removeQuestion(requestID: String, sessionID: String) {
        questionsBySession[sessionID]?.removeAll { $0.id == requestID }
        refreshPendingStateForSelectedSession()
    }

    private func refreshPendingStateForSelectedSession() {
        pendingPermissions = permissionsBySession.values.flatMap { $0 }.filter { !respondedPermissionIDs.contains($0.id) && !dismissedPermissionIDs.contains($0.id) }
        pendingQuestions = questionsBySession.values.flatMap { $0 }.filter { !respondedQuestionIDs.contains($0.id) && !dismissedQuestionIDs.contains($0.id) }
    }

    // MARK: - Todos

    func loadTodos() async {
        guard let client, let sessionId = selectedSessionId else { return }
        do {
            let loaded = try await client.getTodos(sessionId, directory: directory(for: sessionId))
            guard selectedSessionId == sessionId else { return }
            todos = loaded
        } catch {}
    }

    // MARK: - Diffs

    func loadSessionDiffs() async {
        guard let client, let sessionId = selectedSessionId else { return }
        do {
            let loaded = try await client.getSessionDiff(
                sessionId, directory: directory(for: sessionId))
            guard selectedSessionId == sessionId else { return }
            fileDiffs = loaded
        } catch {}
    }

    // MARK: - Permissions

    func approvePermission(_ permission: Permission, always: Bool = false) async {
        guard let client else { return }
        let response = always ? "always" : "once"
        respondedPermissionIDs.insert(permission.id)
        permissionStore?.savePermissions(respondedPermissionIDs)
        do {
            try await client.replyPermission(
                permission.id, response: response, sessionID: permission.sessionID,
                directory: directory(for: permission.sessionID))
            permissionsBySession[permission.sessionID]?.removeAll { $0.id == permission.id }
            refreshPendingStateForSelectedSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectPermission(_ permission: Permission) async {
        guard let client else { return }
        respondedPermissionIDs.insert(permission.id)
        permissionStore?.savePermissions(respondedPermissionIDs)
        do {
            try await client.replyPermission(
                permission.id, response: "reject", sessionID: permission.sessionID,
                directory: directory(for: permission.sessionID))
            permissionsBySession[permission.sessionID]?.removeAll { $0.id == permission.id }
            refreshPendingStateForSelectedSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Event Stream

    func startEventStream() {
        let txn = CrashReporter.transaction(name: "chat.startEventStream", operation: "event")
        defer { txn?.finish() }
        guard let client else { return }
        eventTask?.cancel()
        eventTask = Task {
            var attempt = 0
            while !Task.isCancelled {
                do {
                    attempt = 0
                    logger.info("SSE: connecting to event stream")
                    for try await event in client.eventStream() {
                        guard !Task.isCancelled else { return }
                        handleEvent(event)
                    }
                    logger.info("SSE: stream ended normally, reconnecting")
                } catch {
                    attempt += 1
                    let delay = min(30.0, pow(2.0, Double(min(attempt, 5))))
                    logger.warning(
                        "SSE: error (attempt \(attempt)): \(error.localizedDescription), retrying in \(delay)s"
                    )
                    #if DEBUG
                        print(
                            "[ChatViewModel] SSE disconnect (attempt \(attempt)): \(error). isSending=\(self.isSending), selectedSession=\(self.selectedSessionId ?? "nil")"
                        )
                    #endif
                    if self.isSending, let sessionId = self.selectedSessionId {
                        Task { [weak self] in
                            guard let self else { return }
                            await self.loadMessages()
                            let hasPending = self.pendingOptimisticMessages.values.contains {
                                $0.sessionID == sessionId
                            }
                            if hasPending && self.isSending {
                                self.isSending = false
                                self.errorMessage =
                                    "Message may not have been delivered. Please try again."
                                #if DEBUG
                                    print(
                                        "[ChatViewModel] SSE reconnect: stuck message detected for session \(sessionId)"
                                    )
                                #endif
                            }
                        }
                    }
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
    }

    func stopEventStream() {
        eventTask?.cancel()
        eventTask = nil
    }

    func handleForegroundReconnect() async {
        guard client != nil else { return }
        logger.info("Foreground reconnect: cancelling stale event stream")
        eventTask?.cancel()
        eventTask = nil
        startEventStream()
        await refreshSelectedSession()
    }

    func handleEvent(_ event: SSEEvent) {
        let rawType = event.eventType
        let type = normalizedEventType(rawType)

        switch type {
        case "message.part.delta":
            guard let eventSessionID = event.sessionID,
                eventSessionID == selectedSessionId
            else { return }
            logger.info(
                "SSE: message.part.delta for session \(eventSessionID), message \(event.messageID ?? "nil")"
            )
            applyDelta(event)

        case "message.created":
            guard let eventSessionID = event.sessionID,
                eventSessionID == selectedSessionId
            else { return }
            if let messageData = event.properties?["message"],
                let data = try? JSONEncoder().encode(messageData),
                let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data)
            {
                if !messages.contains(where: { $0.id == envelope.id }) {
                    if envelope.info.isUser {
                        let optimisticKey = pendingOptimisticMessages.first(where: { key, pending in
                            pending.sessionID == eventSessionID
                                && (messageText(envelope) == pending.text
                                    || abs(envelope.info.time.created - pending.created) < 5_000)
                        })?.key
                        if let key = optimisticKey {
                            optimisticToServerMessageIds[key] = envelope.id
                            pendingOptimisticMessages[key] = nil
                            messages.removeAll { $0.id == key }
                        }
                    }
                    messages.append(envelope)
                }
                if !envelope.info.isUser {
                    isSending = false
                }
            }

        case "message.updated", "message.part.updated":
            guard let eventSessionID = event.sessionID,
                eventSessionID == selectedSessionId
            else { return }
            logger.info(
                "SSE: \(rawType) for session \(eventSessionID), streaming=\(self.isStreamingDeltas)"
            )

            if type == "message.updated",
                let infoData = event.properties?["info"]
            {
                applyMessageUpdate(infoData)
            }

            if type == "message.part.updated",
                let partData = event.properties?["part"]
            {
                applyPartUpdate(partData)
            }

        case "session.created", "session.updated", "session.deleted":
            if isSending && type == "session.updated" { break }
            sessionReloadTask?.cancel()
            sessionReloadTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await loadSessions(resetLimit: false)
            }

        case "session.status":
            if let eventSessionID = event.sessionID,
                let statusObj = event.properties?["status"]?.objectValue,
                let statusType = statusObj["type"]?.stringValue
            {
                logger.info(
                    "SSE: session.status = \(statusType) for session \(eventSessionID), selected=\(self.selectedSessionId ?? "nil")"
                )
                sessionStatuses[eventSessionID] = SessionStatus(status: statusType)
                if eventSessionID == selectedSessionId && statusType == "idle" {
                    let wasStillSending = isSending
                    let wasStreaming = isStreamingDeltas
                    resetSendingState(for: eventSessionID)
                    Task {
                        if wasStreaming {
                            try? await Task.sleep(for: .milliseconds(150))
                        }
                        await loadMessages()
                        if wasStillSending {
                            let hasPendingAfterReload = self.pendingOptimisticMessages.values
                                .contains { $0.sessionID == eventSessionID }
                            if hasPendingAfterReload {
                                self.isSending = false
                                self.errorMessage =
                                    "Message may not have been delivered. Please try again."
                                #if DEBUG
                                    print(
                                        "[ChatViewModel] session.status idle: stuck message detected for session \(eventSessionID)"
                                    )
                                #endif
                            }
                        }
                        await loadSessions(resetLimit: false)
                        await sendNextQueuedMessage(for: eventSessionID)
                    }
                }
            }

        case "session.error":
            if let eventSessionID = event.sessionID,
                eventSessionID == selectedSessionId
            {
                resetSendingState(for: eventSessionID)
                errorMessage = extractErrorMessage(from: event)
                let errorForSentry = NSError(
                    domain: "ChatViewModel", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Session error occurred"])
                SentrySDK.capture(error: errorForSentry) { scope in
                    scope.setTag(value: eventSessionID, key: "sessionId")
                    scope.setTag(value: "session.error", key: "eventType")
                }
                #if DEBUG
                    print(
                        "[ChatViewModel] session.error for session \(eventSessionID): \(self.errorMessage ?? "unknown")"
                    )
                #endif
                Task { await loadMessages() }
            }

        case "session.diff":
            if event.sessionID == selectedSessionId {
                Task { await loadSessionDiffs() }
            }

        case "tui.request":
            if let props = event.properties,
                let data = try? JSONEncoder().encode(props),
                let req = try? JSONDecoder().decode(TUIControlRequest.self, from: data)
            {
                nextTUIRequest = req
            }

        case "permission.asked":
            if let props = event.properties,
                let permData = try? JSONEncoder().encode(props),
                let perm = try? JSONDecoder().decode(Permission.self, from: permData)
            {
                if respondedPermissionIDs.contains(perm.id) { return }
                var permissionToMerge = perm
                if let dir = event.directory {
                    var mergedMetadata = perm.metadata ?? [:]
                mergedMetadata["directory"] = .string(dir)
                permissionToMerge = Permission(
                    id: perm.id,
                    type: perm.type,
                    pattern: perm.pattern,
                    sessionID: perm.sessionID,
                    messageID: perm.messageID,
                    callID: perm.callID,
                    title: perm.title,
                    metadata: mergedMetadata,
                    time: perm.time
                )
                }
                if settings?.autoAcceptPermissions == true {
                    Task { await approvePermission(permissionToMerge) }
                } else {
                    mergePermissions([permissionToMerge])
                }
            }

        case "question.asked":
            if let props = event.properties,
                let sessionID = event.sessionID,
                let questionID = props["id"]?.stringValue
            {
                if respondedQuestionIDs.contains(questionID) { return }
                let items = parseQuestionItems(props["questions"])
                let first = items.first
                let question = Question(
                    id: questionID,
                    sessionID: sessionID,
                    messageID: event.messageID,
                    title: first?.header ?? "Question",
                    description: first?.question,
                    questions: items.isEmpty ? [fallbackQuestionInfo(props)] : items
                )
                mergeQuestions([question])
            }

        case "question.replied", "question.rejected":
            if let props = event.properties,
                let requestID = props["requestID"]?.stringValue,
                let sessionID = event.sessionID ?? props["sessionID"]?.stringValue
            {
                removeQuestion(requestID: requestID, sessionID: sessionID)
            }

        case "todo.updated":
            if event.sessionID == selectedSessionId {
                Task { await loadTodos() }
            }

        case "vcs.branch.updated":
            Task { await loadVcs() }

        case "message.removed":
            if let eventSessionID = event.sessionID,
                let messageID = event.messageID,
                eventSessionID == selectedSessionId
            {
                messages.removeAll { $0.id == messageID }
            }

        case "server.connected":
            logger.info("SSE: connected to server")

        case "server.heartbeat":
            break

        case "workspace.ready", "workspace.failed", "workspace.status":
            logger.info("SSE: workspace event \(rawType)")
            Task { await loadWorkspaces() }

        case "worktree.ready", "worktree.failed":
            logger.info("SSE: worktree event \(rawType)")
            Task { await loadWorkspaces() }

        default:
            if rawType != "sync" {
                logger.info("SSE: unhandled event type \(rawType)")
            }
        }
    }

    private func normalizedEventType(_ type: String) -> String {
        if type.hasSuffix(".1") {
            return String(type.dropLast(2))
        }
        return type
    }

    private func applyMessageUpdate(_ infoData: JSONValue) {
        guard let infoJSON = try? JSONEncoder().encode(infoData),
            let info = try? JSONDecoder().decode(MessageInfo.self, from: infoJSON)
        else {
            logger.warning("applyMessageUpdate: failed to decode info from event")
            return
        }

        let resolvedMessageID = optimisticToServerMessageIds[info.id] ?? info.id

        if let msgIdx = messages.firstIndex(where: { $0.id == resolvedMessageID }) {
            let existing = messages[msgIdx]
            messages[msgIdx] = MessageEnvelope(info: info, parts: existing.parts)
            logger.info("applyMessageUpdate: updated existing message \(resolvedMessageID)")
        } else {
            let newMessage = MessageEnvelope(info: info, parts: [])
            let created = info.time.created
            if let insertIdx = messages.firstIndex(where: { $0.info.time.created > created }) {
                messages.insert(newMessage, at: insertIdx)
            } else {
                messages.append(newMessage)
            }
            logger.info(
                "applyMessageUpdate: created new message \(resolvedMessageID) with empty parts")
        }

        if let error = info.error, let sessionId = info.sessionID, sessionId == selectedSessionId {
            errorMessage = error.displayMessage
            if isSending {
                resetSendingState(for: sessionId)
            }
        }
    }

    private func applyPartUpdate(_ partData: JSONValue) {
        guard let partJSON = try? JSONEncoder().encode(partData),
            let part = try? JSONDecoder().decode(Part.self, from: partJSON)
        else {
            logger.warning("applyPartUpdate: failed to decode part from event")
            return
        }

        let resolvedMessageID = optimisticToServerMessageIds[part.messageID ?? ""] ?? part.messageID

        guard let msgIdx = messages.firstIndex(where: { $0.id == resolvedMessageID }) else {
            logger.warning(
                "applyPartUpdate: message \(part.messageID ?? "nil") (resolved: \(resolvedMessageID ?? "nil")) not found"
            )
            if let sessionID = part.sessionID ?? selectedSessionId {
                scheduleDebouncedMessageRecovery(for: sessionID)
            }
            return
        }

        let message = messages[msgIdx]
        var updatedParts = message.parts

        if let existingIdx = updatedParts.firstIndex(where: { $0.id == part.id }) {
            updatedParts[existingIdx] = part
            logger.info("applyPartUpdate: updated existing part \(part.id ?? "nil")")
        } else {
            updatedParts.append(part)
            logger.info(
                "applyPartUpdate: created new part \(part.id ?? "nil") for message \(resolvedMessageID ?? "nil")"
            )
        }

        messages[msgIdx] = MessageEnvelope(info: message.info, parts: updatedParts)

        if let sessionID = selectedSessionId {
            applyBufferedDeltas(for: sessionID)
        }
    }

    private func applyDelta(_ event: SSEEvent) {
        guard let messageID = event.messageID,
            let partID = event.properties?["partID"]?.stringValue,
            let delta = event.properties?["delta"]?.stringValue
        else {
            logger.warning("applyDelta: missing messageID/partID/delta — event: \(event.eventType)")
            return
        }

        let resolvedMessageID = optimisticToServerMessageIds[messageID] ?? messageID

        guard let msgIdx = messages.firstIndex(where: { $0.id == resolvedMessageID }) else {
            logger.warning(
                "applyDelta: message \(messageID) (resolved: \(resolvedMessageID)) not found in current messages (\(self.messages.count) loaded)"
            )
            if let sessionID = event.sessionID {
                bufferedDeltas[sessionID, default: []].append(
                    BufferedDelta(messageID: resolvedMessageID, partID: partID, delta: delta))
                scheduleDebouncedMessageRecovery(for: sessionID)
            }
            return
        }

        isStreamingDeltas = true
        var message = messages[msgIdx]

        guard let partIdx = message.parts.firstIndex(where: { $0.id == partID }) else {
            if let sessionID = event.sessionID {
                bufferedDeltas[sessionID, default: []].append(
                    BufferedDelta(messageID: resolvedMessageID, partID: partID, delta: delta))
                scheduleDebouncedMessageRecovery(for: sessionID)
            }
            return
        }
        let part = message.parts[partIdx]
        let existingText = part.text ?? ""
        let updatedPart = part.withText(existingText + delta)
        message = MessageEnvelope(
            info: message.info,
            parts: message.parts.enumerated().map { idx, p in idx == partIdx ? updatedPart : p }
        )
        messages[msgIdx] = message
    }

    func applyBufferedDeltas(for sessionId: String) {
        guard var deltas = bufferedDeltas[sessionId], !deltas.isEmpty else { return }
        var unapplied: [BufferedDelta] = []
        var applied = false

        for delta in deltas {
            let resolvedMessageID = optimisticToServerMessageIds[delta.messageID] ?? delta.messageID
            guard let msgIdx = messages.firstIndex(where: { $0.id == resolvedMessageID }) else {
                unapplied.append(delta)
                continue
            }
            let message = messages[msgIdx]

            if let partIdx = message.parts.firstIndex(where: { $0.id == delta.partID }) {
                let part = message.parts[partIdx]
                let existingText = part.text ?? ""
                let updatedPart = part.withText(existingText + delta.delta)
                var updatedParts = message.parts
                updatedParts[partIdx] = updatedPart
                messages[msgIdx] = MessageEnvelope(info: message.info, parts: updatedParts)
                applied = true
            } else {
                unapplied.append(delta)
            }
        }

        bufferedDeltas[sessionId] = unapplied.isEmpty ? nil : unapplied
        if applied {
            isStreamingDeltas = true
        }
        if !unapplied.isEmpty {
            logger.info(
                "applyBufferedDeltas: \(unapplied.count) deltas still unapplied for session \(sessionId)"
            )
            scheduleDebouncedMessageRecovery(for: sessionId)
        }
    }

    private func scheduleDebouncedMessageRecovery(for sessionId: String) {
        guard selectedSessionId == sessionId else { return }

        debouncedMessageRecoveryTask?.cancel()
        debouncedMessageRecoveryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }

            guard let self, !Task.isCancelled, self.selectedSessionId == sessionId else { return }
            await self.loadMessages()
        }
    }

    private func clearStaleSendingStateIfSessionIsComplete(sessionId: String) {
        guard selectedSessionId == sessionId else { return }

        let hasPendingOptimisticMessage = pendingOptimisticMessages.values.contains {
            $0.sessionID == sessionId
        }
        let latestAssistantMessageIsComplete = messages.last(where: { $0.info.isAssistant })?
            .info.time.completed != nil
        let sessionIsIdle = sessionStatuses[sessionId]?.isIdle == true

        guard !hasPendingOptimisticMessage, sessionIsIdle || latestAssistantMessageIsComplete else {
            return
        }

        sendTimeoutTask?.cancel()
        sendTimeoutTask = nil
        currentSendOperationID = nil
        isSending = false
        isStreamingDeltas = false
    }

    private func parseQuestionItems(_ value: JSONValue?) -> [QuestionInfo] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item in
            guard case .object(let object) = item else { return nil }
            let options: [QuestionOption]
            if case .array(let optionValues) = object["options"] {
                options = optionValues.compactMap { optionValue in
                    guard case .object(let optionObject) = optionValue,
                        let label = optionObject["label"]?.stringValue
                    else { return nil }
                    return QuestionOption(
                        label: label, description: optionObject["description"]?.stringValue ?? "")
                }
            } else {
                options = []
            }
            return QuestionInfo(
                question: object["question"]?.stringValue ?? object["description"]?.stringValue
                    ?? "",
                header: object["header"]?.stringValue ?? object["title"]?.stringValue ?? "Question",
                options: options,
                multiple: object["multiple"]?.boolValue ?? false,
                custom: object["custom"]?.boolValue ?? true
            )
        }
    }

    private func fallbackQuestionInfo(_ props: [String: JSONValue]) -> QuestionInfo {
        QuestionInfo(
            question: props["description"]?.stringValue ?? props["title"]?.stringValue ?? "",
            header: props["title"]?.stringValue ?? "Question",
            options: [],
            multiple: false,
            custom: true
        )
    }

    private func resetSendingState(for sessionId: String) {
        isSending = false
        isStreamingDeltas = false
        currentSendOperationID = nil
        sendTimeoutTask?.cancel()
        sendTimeoutTask = nil
        let stale = pendingOptimisticMessages.filter { $0.value.sessionID == sessionId }
        for (id, _) in stale {
            messages.removeAll { $0.id == id }
            pendingOptimisticMessages[id] = nil
            optimisticToServerMessageIds.removeValue(forKey: id)
        }
    }

    private func extractErrorMessage(from event: SSEEvent) -> String {
        if let errorString = event.properties?["error"]?.stringValue {
            return errorString
        }
        if let errorObj = event.properties?["error"]?.objectValue {
            if let dataObj = errorObj["data"]?.objectValue,
                let msg = dataObj["message"]?.stringValue
            {
                return msg
            }
            if let name = errorObj["name"]?.stringValue {
                return name
            }
            logger.error("session.error: unrecognized error structure: \(errorObj)")
            return "Session error occurred"
        }
        if let messageString = event.properties?["message"]?.stringValue {
            return messageString
        }
        logger.error("session.error: missing error payload in properties: \(String(describing: event.properties))")
        return "Session error occurred"
    }
}

struct PendingOptimisticMessage {
    let id: String
    let sessionID: String
    let text: String
    let created: Int64
}

struct PromptDraft: Codable, Equatable {
    let text: String
    let attachments: [MessagePartBody]
}

private struct BufferedDelta {
    let messageID: String
    let partID: String
    let delta: String
}

private struct DraftStore {
    private let key = "opencode-nexus.prompt-drafts.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: PromptDraft] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: PromptDraft].self, from: data)) ?? [:]
    }

    func save(_ drafts: [String: PromptDraft]) {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        defaults.set(data, forKey: key)
    }
}
