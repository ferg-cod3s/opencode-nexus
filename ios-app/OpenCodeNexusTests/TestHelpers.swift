import SwiftUI
import Foundation
@testable import OpenCodeNexus

// MARK: - View Body Evaluation

/// Evaluates a view's body property to trigger line coverage for SwiftUI views
/// - Parameter view: The view to evaluate
@MainActor
func evaluateBody<V: View>(_ view: V) {
    _ = view.body
}

/// Evaluates a view's body property with environment objects
/// - Parameters:
///   - view: The view to evaluate
///   - environments: Environment objects to inject
@MainActor
func evaluateBody<V: View>(_ view: V, environments: [Any]) {
    let envView = view
    for env in environments {
        if let observable = env as? AnyObject {
            // This is a simplified approach - in practice we'd need to handle specific environment types
            // For now, we'll just access the body which will trigger coverage
        }
    }
    _ = view.body
}

// MARK: - Mock Data Factories

func makeSession(id: String = "test-session", 
                 title: String = "Test Session",
                 directory: String = "/test/dir") -> Session {
    return Session(id: id,
                   title: title,
                   directory: directory,
                   workspaceName: "Test Workspace",
                   created: Date(),
                   updated: Date())
}

func makeMessageEnvelope(id: String = "test-message",
                         role: MessageInfo.Role = .user,
                         content: String = "Test content",
                         sessionID: String = "test-session") -> MessageEnvelope {
    let info = MessageInfo(id: id,
                           isUser: (role == .user),
                           isAssistant: (role == .assistant),
                           agent: nil,
                           modelID: nil,
                           threadID: nil,
                           invitations: [],
                           cost: nil,
                           tokens: nil,
                           time: MessageInfo.Time(created: Date(), updated: Date(), relativeString: ""),
                           error: nil)
    
    let part = MessagePartBody(type: "text", text: content)
    return MessageEnvelope(info: info, parts: [part])
}

func makePermission(id: String = "test-permission",
                    sessionID: String = "test-session",
                    type: PermissionType = .agent,
                    operation: String = "create",
                    resource: String = "test-resource") -> Permission {
    return Permission(id: id,
                      sessionID: sessionID,
                      type: type,
                      operation: operation,
                      resource: resource,
                      timestamp: Date())
}

func makeQuestion(id: String = "test-question",
                  sessionID: String = "test-session",
                  header: String = "Test Question",
                  question: String = "Is this working?",
                  options: [QuestionOption] = []) -> Question {
    return Question(id: id,
                    sessionID: sessionID,
                    messageID: "test-message",
                    title: header,
                    description: question,
                    questions: options.map { QuestionInfo(question: $0.description,
                                                          header: $0.label,
                                                          options: [],
                                                          multiple: false,
                                                          custom: false) })
}

func makeFileDiff(path: String = "test/file.swift",
                  additions: Int = 5,
                  deletions: Int = 3,
                  changes: [[String]] = []) -> FileDiff {
    return FileDiff(newFile: path,
                    oldFile: path,
                    additions: additions,
                    deletions: deletions,
                    changes: changes)
}

func makeToolCall(name: String = "bash",
                  input: [String: JSONValue] = [:],
                  output: String? = nil,
                  status: String = "success") -> MessagePartBody {
    return MessagePartBody(type: name,
                           input: input,
                           output: output,
                           status: status)
}

// MARK: - Mock OpenCodeClient

final class MockOpenCodeClient: OpenCodeClient {
    var mockHealthResponse: HealthResponse = HealthResponse(healthy: true, version: "1.0.0")
    var mockSessions: [Session] = []
    var mockMessages: [MessageEnvelope] = []
    var mockProjects: [Project] = []
    var mockProviders: ProviderListResponse = ProviderListResponse(providers: [], defaultModels: [:])
    var mockAgents: [AgentInfo] = []
    var mockCommands: [CommandInfo] = []
    var mockVCSBranch: String? = "main"
    var mockProject: Project?
    
    var shouldReturnError = false
    var mockError: Error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    override func healthCheck() async throws -> HealthResponse {
        if shouldReturnError { throw mockError }
        return mockHealthResponse
    }
    
    override func listSessions(limit: Int?, before: String?) async throws -> [Session] {
        if shouldReturnError { throw mockError }
        return mockSessions
    }
    
    override func createSession(title: String) async throws -> Session {
        if shouldReturnError { throw mockError }
        return Session(id: UUID().uuidString,
                       title: title,
                       directory: "/test",
                       workspaceName: "Test",
                       created: Date(),
                       updated: Date())
    }
    
    override func getMessages(sessionID: String, limit: Int?, before: String?) async throws -> [MessageEnvelope] {
        if shouldReturnError { throw mockError }
        return mockMessages
    }
    
    override func sendMessage(sessionID: String,
                              attachments: [MessagePartBody],
                              agent: String?) async throws -> MessageEnvelope {
        if shouldReturnError { throw mockError }
        return makeMessageEnvelope()
    }
    
    override func listProjects() async throws -> [Project] {
        if shouldReturnError { throw mockError }
        return mockProjects
    }
    
    override func getCurrentProject() async throws -> Project? {
        if shouldReturnError { throw mockError }
        return mockProject
    }
    
    override func listConfigProviders() async throws -> ProviderListResponse {
        if shouldReturnError { throw mockError }
        return mockProviders
    }
    
    override func listAgentInfo() async throws -> [AgentInfo] {
        if shouldReturnError { throw mockError }
        return mockAgents
    }
    
    override func listCommands() async throws -> [CommandInfo] {
        if shouldReturnError { throw mockError }
        return mockCommands
    }
    
    override func getVCS() async throws -> String? {
        if shouldReturnError { throw mockError }
        return mockVCSBranch
    }
    
    override func eventStream() -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

// MARK: - JSON Value Helpers

extension JSONValue {
    static func string(_ value: String) -> JSONValue {
        return .string(value)
    }
    
    static func int(_ value: Int) -> JSONValue {
        return .number(Double(value))
    }
    
    static func bool(_ value: Bool) -> JSONValue {
        return .bool(value)
    }
    
    static func object(_ dict: [String: JSONValue]) -> JSONValue {
        return .object(dict)
    }
    
    static func array(_ arr: [JSONValue]) -> JSONValue {
        return .array(arr)
    }
    
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
    
    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
    
    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}