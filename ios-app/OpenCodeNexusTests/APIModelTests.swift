import XCTest
@testable import OpenCodeNexus

final class APIModelTests: XCTestCase {

    // MARK: - HealthResponse

    func testHealthResponseDecoding() throws {
        let json = """
        {"healthy": true, "version": "1.2.3"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(HealthResponse.self, from: data)
        XCTAssertTrue(response.healthy)
        XCTAssertEqual(response.version, "1.2.3")
    }

    func testHealthResponseUnhealthy() throws {
        let json = """
        {"healthy": false, "version": "0.0.1"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(HealthResponse.self, from: data)
        XCTAssertFalse(response.healthy)
    }

    // MARK: - Project

    func testProjectDecoding() throws {
        let json = """
        {
            "id": "proj_1",
            "worktree": "/Users/dev/projects/myapp",
            "vcsDir": ".git",
            "vcs": "git",
            "time": {"created": 1700000000000, "updated": 1700001000000},
            "sandboxes": ["sandbox1"]
        }
        """
        let data = json.data(using: .utf8)!
        let project = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(project.id, "proj_1")
        XCTAssertEqual(project.worktree, "/Users/dev/projects/myapp")
        XCTAssertEqual(project.vcs, "git")
        XCTAssertEqual(project.sandboxes?.count, 1)
    }

    func testProjectDisplayPath() throws {
        let project = try makeProject(worktree: "/Users/dev/myproject")
        XCTAssertEqual(project.displayPath, "myproject")
    }

    func testProjectDisplayPathTrailingSlash() throws {
        let project = try makeProject(worktree: "/Users/dev/myproject/")
        XCTAssertEqual(project.displayPath, "myproject")
    }

    func testProjectMinimalDecoding() throws {
        let json = """
        {
            "id": "proj_min",
            "worktree": "/home",
            "time": {"created": 0}
        }
        """
        let data = json.data(using: .utf8)!
        let project = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertNil(project.vcsDir)
        XCTAssertNil(project.vcs)
        XCTAssertNil(project.sandboxes)
    }

    // MARK: - VcsInfo

    func testVcsInfoDecoding() throws {
        let json = """
        {"branch": "main"}
        """
        let data = json.data(using: .utf8)!
        let vcs = try JSONDecoder().decode(VcsInfo.self, from: data)
        XCTAssertEqual(vcs.branch, "main")
        XCTAssertEqual(vcs.displayBranch, "main")
    }

    func testVcsInfoEmptyBranch() throws {
        let json = """
        {"branch": ""}
        """
        let data = json.data(using: .utf8)!
        let vcs = try JSONDecoder().decode(VcsInfo.self, from: data)
        XCTAssertEqual(vcs.branch, "")
        XCTAssertNil(vcs.displayBranch)
    }

    func testVcsInfoNilBranch() throws {
        let json = """
        {}
        """
        let data = json.data(using: .utf8)!
        let vcs = try JSONDecoder().decode(VcsInfo.self, from: data)
        XCTAssertNil(vcs.branch)
        XCTAssertNil(vcs.displayBranch)
    }

    // MARK: - Todo

    func testTodoStatusChecks() throws {
        let completed = try makeTodo(status: "completed")
        XCTAssertTrue(completed.isCompleted)
        XCTAssertFalse(completed.isInProgress)

        let inProgress = try makeTodo(status: "in_progress")
        XCTAssertFalse(inProgress.isCompleted)
        XCTAssertTrue(inProgress.isInProgress)

        let pending = try makeTodo(status: "pending")
        XCTAssertFalse(pending.isCompleted)
        XCTAssertFalse(pending.isInProgress)
    }

    // MARK: - Permission

    func testPermissionDecoding() throws {
        let json = """
        {
            "id": "perm_1",
            "type": "file_write",
            "pattern": "src/main.swift",
            "sessionID": "ses_abc",
            "messageID": "msg_123",
            "callID": "call_456",
            "title": "Write to file",
            "metadata": {"key": "value"},
            "time": {"created": 1700000000000}
        }
        """
        let data = json.data(using: .utf8)!
        let permission = try JSONDecoder().decode(Permission.self, from: data)
        XCTAssertEqual(permission.id, "perm_1")
        XCTAssertEqual(permission.type, "file_write")
        XCTAssertEqual(permission.sessionID, "ses_abc")
        XCTAssertEqual(permission.callID, "call_456")
    }

    // MARK: - PatternValue

    func testPatternValueString() throws {
        let json = """
        "src/main.swift"
        """
        let data = json.data(using: .utf8)!
        let pattern = try JSONDecoder().decode(PatternValue.self, from: data)
        let encoded = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(String.self, from: encoded)
        XCTAssertEqual(decoded, "src/main.swift")
    }

    func testPatternValueArray() throws {
        let json = """
        ["src/a.swift", "src/b.swift"]
        """
        let data = json.data(using: .utf8)!
        let pattern = try JSONDecoder().decode(PatternValue.self, from: data)
        let encoded = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode([String].self, from: encoded)
        XCTAssertEqual(decoded, ["src/a.swift", "src/b.swift"])
    }

    func testPatternValueEncodingRoundtrip() throws {
        let original = PatternValue.array(["a", "b"])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String].self, from: encoded)
        XCTAssertEqual(decoded, ["a", "b"])
    }

    // MARK: - ProviderInfo

    func testProviderInfoDecoding() throws {
        let json = """
        {
            "id": "openai",
            "name": "OpenAI",
            "models": {
                "gpt-4o": {"id": "gpt-4o", "name": "GPT-4o", "status": "active"},
                "gpt-4o-mini": {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "status": "active"}
            }
        }
        """
        let data = json.data(using: .utf8)!
        let provider = try JSONDecoder().decode(ProviderInfo.self, from: data)
        XCTAssertEqual(provider.id, "openai")
        XCTAssertEqual(provider.name, "OpenAI")
        XCTAssertEqual(provider.models?.count, 2)
        XCTAssertEqual(provider.models?["gpt-4o"]?.name, "GPT-4o")
    }

    func testProviderInfoNoModels() throws {
        let json = """
        {"id": "custom", "name": "Custom Provider"}
        """
        let data = json.data(using: .utf8)!
        let provider = try JSONDecoder().decode(ProviderInfo.self, from: data)
        XCTAssertEqual(provider.id, "custom")
        XCTAssertNil(provider.models)
    }

    // MARK: - ProviderModelInfo

    func testProviderModelInfoStatusChecks() throws {
        let json = """
        {"id": "old-model", "name": "Old Model", "status": "deprecated", "cost": {"input": 0, "output": 0}}
        """
        let data = json.data(using: .utf8)!
        let model = try JSONDecoder().decode(ProviderModelInfo.self, from: data)
        XCTAssertTrue(model.isDeprecated)
        XCTAssertTrue(model.isFree)
    }

    func testProviderModelInfoNotFree() throws {
        let json = """
        {"id": "gpt-4o", "name": "GPT-4o", "status": "active", "cost": {"input": 5.0, "output": 15.0}}
        """
        let data = json.data(using: .utf8)!
        let model = try JSONDecoder().decode(ProviderModelInfo.self, from: data)
        XCTAssertFalse(model.isDeprecated)
        XCTAssertFalse(model.isFree)
    }

    // MARK: - ConfigProvidersResponse

    func testConfigProvidersResponseDecoding() throws {
        let json = """
        {
            "providers": [
                {"id": "openai", "name": "OpenAI", "models": {}},
                {"id": "anthropic", "name": "Anthropic", "models": {}}
            ],
            "default": {"openai": "gpt-4o", "anthropic": "claude-3.5-sonnet"}
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConfigProvidersResponse.self, from: data)
        XCTAssertEqual(response.providers?.count, 2)
        XCTAssertEqual(response.defaultModels?["openai"], "gpt-4o")
        XCTAssertEqual(response.defaultModels?["anthropic"], "claude-3.5-sonnet")
    }

    func testConfigProvidersResponseEmptyProviders() throws {
        let json = """
        {"providers": [], "default": {}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConfigProvidersResponse.self, from: data)
        XCTAssertNil(response.providers)
    }

    // MARK: - AgentInfo

    func testAgentInfoDecoding() throws {
        let json = """
        {
            "name": "coder",
            "description": "Writes code",
            "mode": "code",
            "builtIn": true,
            "permission": [
                {"permission": "file_write", "action": "allow", "pattern": "src/*"}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let agent = try JSONDecoder().decode(AgentInfo.self, from: data)
        XCTAssertEqual(agent.id, "coder")
        XCTAssertEqual(agent.name, "coder")
        XCTAssertEqual(agent.description, "Writes code")
        XCTAssertEqual(agent.mode, "code")
        XCTAssertEqual(agent.builtIn, true)
        XCTAssertEqual(agent.permission?.count, 1)
        XCTAssertEqual(agent.permission?.first?.permission, "file_write")
    }

    // MARK: - SearchResult

    func testSearchResultDecoding() throws {
        let json = """
        {"path": "src/main.swift", "line": 42, "text": "func hello() {"}
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertEqual(result.path, "src/main.swift")
        XCTAssertEqual(result.line, 42)
        XCTAssertEqual(result.text, "func hello() {")
    }

    func testSearchResultPartialDecoding() throws {
        let json = """
        {"path": "README.md"}
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertEqual(result.path, "README.md")
        XCTAssertNil(result.line)
        XCTAssertNil(result.text)
    }

    func testSearchResultDecodesCurrentOpenAPIShape() throws {
        let json = """
        {"path": {"text": "src/main.swift"}, "lines": {"text": "func hello() {"}, "line_number": 42}
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertEqual(result.path, "src/main.swift")
        XCTAssertEqual(result.line, 42)
        XCTAssertEqual(result.text, "func hello() {")
    }

    // MARK: - Additional API Models

    func testPathInfoDecoding() throws {
        let json = """
        {"home": "/Users/dev", "state": "/Users/dev/.local/state", "config": "/Users/dev/.config", "directory": "/Users/dev/project"}
        """
        let data = json.data(using: .utf8)!
        let pathInfo = try JSONDecoder().decode(PathInfo.self, from: data)
        XCTAssertEqual(pathInfo.home, "/Users/dev")
        XCTAssertEqual(pathInfo.state, "/Users/dev/.local/state")
        XCTAssertEqual(pathInfo.config, "/Users/dev/.config")
    }

    func testFileNodeDecoding() throws {
        let json = """
        {"name": "src", "path": "src", "absolute": "/project/src", "type": "directory", "ignored": false}
        """
        let data = json.data(using: .utf8)!
        let node = try JSONDecoder().decode(FileNode.self, from: data)
        XCTAssertEqual(node.name, "src")
        XCTAssertTrue(node.isDirectory)
        XCTAssertEqual(node.id, "src")
        XCTAssertFalse(node.ignored)
    }

    func testFileStatusDecoding() throws {
        let json = """
        {"path": "main.swift", "added": 10, "removed": 5, "status": "modified"}
        """
        let data = json.data(using: .utf8)!
        let status = try JSONDecoder().decode(FileStatus.self, from: data)
        XCTAssertEqual(status.path, "main.swift")
        XCTAssertEqual(status.added, 10)
        XCTAssertEqual(status.status, "modified")
    }

    func testFileContentDecoding() throws {
        let json = """
        {"type": "file", "content": "hello world", "diff": null, "encoding": "utf-8", "mimeType": "text/plain"}
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(FileContent.self, from: data)
        XCTAssertEqual(content.type, "file")
        XCTAssertEqual(content.content, "hello world")
    }

    func testCommandInfoDecoding() throws {
        let json = """
        {"name": "edit", "description": "Edit a file"}
        """
        let data = json.data(using: .utf8)!
        let cmd = try JSONDecoder().decode(CommandInfo.self, from: data)
        XCTAssertEqual(cmd.name, "edit")
        XCTAssertEqual(cmd.description, "Edit a file")
    }

    // MARK: - Helpers

    private func makeProject(worktree: String) throws -> Project {
        let json = """
        {"id": "proj_test", "worktree": "\(worktree)", "time": {"created": 0}}
        """
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Project.self, from: data)
    }

    private func makeTodo(status: String) throws -> Todo {
        let json = """
        {"id": "todo_1", "content": "Do something", "status": "\(status)", "priority": "high"}
        """
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(Todo.self, from: data)
    }

    // MARK: - New Models (Phase 1)

    func testMcpServerStatusDecoding() throws {
        let json = """
        {"name": "filesystem", "status": "connected", "tools": [{"name": "read_file", "description": "Read a file"}]}
        """
        let data = json.data(using: .utf8)!
        let server = try JSONDecoder().decode(McpServerStatus.self, from: data)
        XCTAssertEqual(server.id, "filesystem")
        XCTAssertEqual(server.name, "filesystem")
        XCTAssertTrue(server.isConnected)
        XCTAssertFalse(server.hasError)
        XCTAssertEqual(server.tools?.count, 1)
        XCTAssertEqual(server.tools?.first?.name, "read_file")
    }

    func testMcpServerStatusError() throws {
        let json = """
        {"name": "broken", "status": "error", "error": "Connection failed"}
        """
        let data = json.data(using: .utf8)!
        let server = try JSONDecoder().decode(McpServerStatus.self, from: data)
        XCTAssertFalse(server.isConnected)
        XCTAssertTrue(server.hasError)
        XCTAssertEqual(server.error, "Connection failed")
    }

    func testMcpServerStatusConnecting() throws {
        let json = """
        {"name": "loading", "status": "connecting"}
        """
        let data = json.data(using: .utf8)!
        let server = try JSONDecoder().decode(McpServerStatus.self, from: data)
        XCTAssertTrue(server.isConnecting)
        XCTAssertFalse(server.isConnected)
    }

    func testVcsDiffResponseDecoding() throws {
        let json = """
        {"files": [{"path": "main.swift", "additions": 10, "deletions": 5, "status": "modified"}]}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(VcsDiffResponse.self, from: data)
        XCTAssertEqual(response.files.count, 1)
        XCTAssertEqual(response.files.first?.path, "main.swift")
        XCTAssertEqual(response.files.first?.additions, 10)
        XCTAssertEqual(response.files.first?.deletions, 5)
    }

    func testServerConfigResponseDecoding() throws {
        let json = """
        {"theme": "dark", "language": "en", "autoAcceptPermissions": true, "reasoningSummaries": false, "sessionProgressBar": true}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ServerConfigResponse.self, from: data)
        XCTAssertEqual(config.theme, "dark")
        XCTAssertEqual(config.language, "en")
        XCTAssertEqual(config.autoAcceptPermissions, true)
        XCTAssertEqual(config.reasoningSummaries, false)
        XCTAssertEqual(config.sessionProgressBar, true)
    }

    func testConfigUpdateEncoding() throws {
        let config = ConfigUpdate(
            theme: "light",
            language: "es",
            autoAcceptPermissions: true,
            reasoningSummaries: false,
            shellToolParts: true,
            editToolParts: false,
            sessionProgressBar: true,
            visibleModels: ["gpt-4"],
            hiddenModels: ["gpt-3.5"]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ConfigUpdate.self, from: data)
        XCTAssertEqual(decoded.theme, "light")
        XCTAssertEqual(decoded.language, "es")
        XCTAssertEqual(decoded.autoAcceptPermissions, true)
        XCTAssertEqual(decoded.visibleModels, ["gpt-4"])
        XCTAssertEqual(decoded.hiddenModels, ["gpt-3.5"])
    }

    func testProviderOAuthResponseDecoding() throws {
        let json = """
        {"url": "https://github.com/login/oauth/authorize?client_id=abc"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ProviderOAuthResponse.self, from: data)
        XCTAssertEqual(response.url, "https://github.com/login/oauth/authorize?client_id=abc")
    }

    func testMcpOAuthResponseDecoding() throws {
        let json = """
        {"url": "https://mcp.example.com/oauth/authorize"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(McpOAuthResponse.self, from: data)
        XCTAssertEqual(response.url, "https://mcp.example.com/oauth/authorize")
    }

    func testProviderAuthMethodDecoding() throws {
        let json = """
        {"type": "oauth", "providerID": "github-copilot", "name": "GitHub"}
        """
        let data = json.data(using: .utf8)!
        let method = try JSONDecoder().decode(ProviderAuthMethod.self, from: data)
        XCTAssertEqual(method.id, "oauth")
        XCTAssertEqual(method.type, "oauth")
        XCTAssertEqual(method.providerID, "github-copilot")
        XCTAssertEqual(method.name, "GitHub")
    }

    func testFileDiffInfoDecoding() throws {
        let json = """
        {"path": "src/main.swift", "additions": 15, "deletions": 3, "status": "modified"}
        """
        let data = json.data(using: .utf8)!
        let diff = try JSONDecoder().decode(FileDiffInfo.self, from: data)
        XCTAssertEqual(diff.path, "src/main.swift")
        XCTAssertEqual(diff.additions, 15)
        XCTAssertEqual(diff.deletions, 3)
        XCTAssertEqual(diff.status, "modified")
    }
}
