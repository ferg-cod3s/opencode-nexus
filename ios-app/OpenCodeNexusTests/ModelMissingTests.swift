import XCTest
@testable import OpenCodeNexus

final class ModelMissingTests: XCTestCase {

    // MARK: - SessionStatus

    func testSessionStatusIsBusy() {
        let status = SessionStatus(status: "busy")
        XCTAssertTrue(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }

    func testSessionStatusIsIdle() {
        let status = SessionStatus(status: "idle")
        XCTAssertFalse(status.isBusy)
        XCTAssertTrue(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }

    func testSessionStatusIsRetry() {
        let status = SessionStatus(status: "retry")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertTrue(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }

    func testSessionStatusIsWaitingForInput() {
        let status = SessionStatus(status: "waiting-for-input")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertTrue(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertTrue(status.needsAttention)
    }

    func testSessionStatusIsError() {
        let status = SessionStatus(status: "error")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertTrue(status.isFailed)
        XCTAssertTrue(status.needsAttention)
    }

    func testSessionStatusIsFailed() {
        let status = SessionStatus(status: "failed")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertTrue(status.isFailed)
        XCTAssertTrue(status.needsAttention)
    }

    func testSessionStatusUnknown() {
        let status = SessionStatus(status: "unknown")
        XCTAssertFalse(status.isBusy)
        XCTAssertFalse(status.isIdle)
        XCTAssertFalse(status.isRetry)
        XCTAssertFalse(status.isWaitingForInput)
        XCTAssertFalse(status.isFailed)
        XCTAssertFalse(status.needsAttention)
    }

    // MARK: - Pty

    func testPtyIsRunning() {
        let pty = Pty(id: "1", title: "T", command: "bash", args: nil, cwd: nil, status: "running", pid: 123)
        XCTAssertTrue(pty.isRunning)
        XCTAssertFalse(pty.hasExited)
    }

    func testPtyHasExited() {
        let pty = Pty(id: "1", title: "T", command: "bash", args: ["-c"], cwd: "/tmp", status: "exited", pid: nil)
        XCTAssertFalse(pty.isRunning)
        XCTAssertTrue(pty.hasExited)
    }

    func testPtyDecodingMinimal() throws {
        let json = """
        {"id":"1","title":"T","command":"bash","status":"running"}
        """
        let pty = try JSONDecoder().decode(Pty.self, from: Data(json.utf8))
        XCTAssertEqual(pty.id, "1")
        XCTAssertEqual(pty.command, "bash")
        XCTAssertNil(pty.args)
        XCTAssertNil(pty.cwd)
        XCTAssertNil(pty.pid)
    }

    func testPtyDecodingFull() throws {
        let json = """
        {"id":"1","title":"T","command":"bash","args":["-c"],"cwd":"/tmp","status":"running","pid":123}
        """
        let pty = try JSONDecoder().decode(Pty.self, from: Data(json.utf8))
        XCTAssertEqual(pty.pid, 123)
        XCTAssertEqual(pty.args, ["-c"])
        XCTAssertEqual(pty.cwd, "/tmp")
    }

    // MARK: - Project

    func testProjectDisplayPathSimple() throws {
        let json = """
        {"id":"1","worktree":"/Users/dev/project","time":{"created":1}}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(project.displayPath, "project")
    }

    func testProjectDisplayPathTrailingSlash() throws {
        let json = """
        {"id":"1","worktree":"/Users/dev/project/","time":{"created":1}}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(project.displayPath, "project")
    }

    func testProjectDisplayPathSingleComponent() throws {
        let json = """
        {"id":"1","worktree":"project","time":{"created":1}}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(project.displayPath, "project")
    }

    func testProjectDecodingWithVcsDir() throws {
        let json = """
        {"id":"1","worktree":"/project","vcsDir":".git","vcs":"git","time":{"created":1},"sandboxes":["sandbox1"]}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(project.vcsDir, ".git")
        XCTAssertEqual(project.vcs, "git")
        XCTAssertEqual(project.sandboxes, ["sandbox1"])
    }

    func testProjectDecodingWithoutVcsDir() throws {
        let json = """
        {"id":"1","worktree":"/project","time":{"created":1}}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertNil(project.vcsDir)
        XCTAssertNil(project.vcs)
        XCTAssertNil(project.sandboxes)
    }

    // MARK: - HealthResponse

    func testHealthResponseDecoding() throws {
        let json = """
        {"healthy":true,"version":"1.0.0"}
        """
        let health = try JSONDecoder().decode(HealthResponse.self, from: Data(json.utf8))
        XCTAssertTrue(health.healthy)
        XCTAssertEqual(health.version, "1.0.0")
    }

    func testHealthResponseDecodingUnhealthy() throws {
        let json = """
        {"healthy":false,"version":"2.0.0"}
        """
        let health = try JSONDecoder().decode(HealthResponse.self, from: Data(json.utf8))
        XCTAssertFalse(health.healthy)
        XCTAssertEqual(health.version, "2.0.0")
    }
}
