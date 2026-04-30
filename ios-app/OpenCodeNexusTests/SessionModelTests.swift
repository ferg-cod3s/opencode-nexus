import XCTest
@testable import OpenCodeNexus

final class SessionModelTests: XCTestCase {

    // MARK: - Session Decoding

    func testSessionDecodingFullJSON() throws {
        let json = """
        {
            "id": "ses_abc123",
            "projectID": "proj_xyz",
            "directory": "/Users/dev/myproject",
            "parentID": "ses_parent",
            "title": "Fix authentication bug",
            "version": "1.0.0",
            "time": {
                "created": 1700000000000,
                "updated": 1700001000000
            },
            "summary": {
                "additions": 42,
                "deletions": 10,
                "files": 3,
                "diffs": []
            },
            "share": {
                "url": "https://share.opencode.ai/abc"
            },
            "revert": {
                "messageID": "msg_001",
                "partID": "part_002",
                "snapshot": "abc123",
                "diff": "--- a/file.txt\\n+++ b/file.txt"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(Session.self, from: data)

        XCTAssertEqual(session.id, "ses_abc123")
        XCTAssertEqual(session.projectID, "proj_xyz")
        XCTAssertEqual(session.directory, "/Users/dev/myproject")
        XCTAssertEqual(session.parentID, "ses_parent")
        XCTAssertEqual(session.title, "Fix authentication bug")
        XCTAssertEqual(session.version, "1.0.0")
        XCTAssertEqual(session.time.created, 1_700_000_000_000)
        XCTAssertEqual(session.time.updated, 1_700_001_000_000)
    }

    func testSessionDecodingMinimalJSON() throws {
        let json = """
        {
            "id": "ses_min",
            "directory": "/home/project",
            "title": "My session",
            "time": {
                "created": 1700000000000
            }
        }
        """
        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(Session.self, from: data)

        XCTAssertEqual(session.id, "ses_min")
        XCTAssertEqual(session.projectID, "")
        XCTAssertEqual(session.version, "")
        XCTAssertNil(session.parentID)
        XCTAssertNil(session.summary)
        XCTAssertNil(session.share)
        XCTAssertNil(session.revert)
        XCTAssertNil(session.time.updated)
    }

    // MARK: - Session displayTitle

    func testDisplayTitleWithCustomTitle() throws {
        let session = makeSession(id: "ses_1", title: "Fix auth bug")
        XCTAssertEqual(session.displayTitle, "Fix auth bug")
    }

    func testDisplayTitleWithNewSessionPrefix() throws {
        let session = makeSession(id: "ses_abc123", title: "New session")
        XCTAssertEqual(session.displayTitle, "Abc123")
    }

    func testDisplayTitleWithNewSessionDashPrefix() throws {
        let session = makeSession(id: "ses_a1b2-c3d4", title: "New session")
        XCTAssertEqual(session.displayTitle, "A1B2 C3D4")
    }

    func testDisplayTitleWithEmptyTitle() throws {
        let session = makeSession(id: "ses_xyz", title: "")
        XCTAssertEqual(session.displayTitle, "Xyz")
    }

    func testDisplayTitleWithIdWithoutPrefix() throws {
        let session = makeSession(id: "custom-id-123", title: "")
        XCTAssertEqual(session.displayTitle, "Custom Id 123")
    }

    // MARK: - Session workspaceName

    func testWorkspaceNameExtraction() throws {
        let session = makeSession(directory: "/Users/dev/projects/myapp")
        XCTAssertEqual(session.workspaceName, "myapp")
    }

    func testWorkspaceNameTrailingSlash() throws {
        let session = makeSession(directory: "/Users/dev/projects/myapp/")
        XCTAssertEqual(session.workspaceName, "myapp")
    }

    func testWorkspaceNameEmptyComponents() throws {
        let session = makeSession(directory: "somedir")
        XCTAssertEqual(session.workspaceName, "somedir")
    }

    // MARK: - Session Hash Equality

    func testSessionHashEquality() throws {
        let session1 = makeSession(id: "ses_same", title: "Title A")
        let session2 = makeSession(id: "ses_same", title: "Title B")
        XCTAssertEqual(session1, session2)
        XCTAssertEqual(session1.hashValue, session2.hashValue)
    }

    func testSessionInequality() throws {
        let session1 = makeSession(id: "ses_a")
        let session2 = makeSession(id: "ses_b")
        XCTAssertNotEqual(session1, session2)
    }

    func testSessionInSet() {
        let s1 = makeSession(id: "ses_1")
        let s2 = makeSession(id: "ses_1")
        let s3 = makeSession(id: "ses_2")
        let set: Set<Session> = [s1, s2, s3]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - TimeInfo Date Conversion

    func testTimeInfoCreatedDate() throws {
        let json = """
        {"created": 1700000000000}
        """
        let data = json.data(using: .utf8)!
        let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: data)
        let expected = Date(timeIntervalSince1970: 1_700_000_000_000 / 1000)
        XCTAssertEqual(timeInfo.createdDate, expected)
    }

    func testTimeInfoUpdatedDate() throws {
        let json = """
        {"created": 1700000000000, "updated": 1700005000000}
        """
        let data = json.data(using: .utf8)!
        let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: data)
        let expected = Date(timeIntervalSince1970: 1_700_005_000_000 / 1000)
        XCTAssertEqual(timeInfo.updatedDate, expected)
    }

    func testTimeInfoUpdatedDateNil() throws {
        let json = """
        {"created": 1700000000000}
        """
        let data = json.data(using: .utf8)!
        let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: data)
        XCTAssertNil(timeInfo.updatedDate)
    }

    // MARK: - FileDiff

    func testFileDiffDecoding() throws {
        let json = """
        {
            "file": "src/main.swift",
            "before": "old content",
            "after": "new content",
            "additions": 5,
            "deletions": 2
        }
        """
        let data = json.data(using: .utf8)!
        let diff = try JSONDecoder().decode(FileDiff.self, from: data)
        XCTAssertEqual(diff.file, "src/main.swift")
        XCTAssertEqual(diff.additions, 5)
        XCTAssertEqual(diff.deletions, 2)
    }

    // MARK: - SessionShare

    func testSessionShareDecoding() throws {
        let json = """
        {"url": "https://share.opencode.ai/ses123"}
        """
        let data = json.data(using: .utf8)!
        let share = try JSONDecoder().decode(SessionShare.self, from: data)
        XCTAssertEqual(share.url, "https://share.opencode.ai/ses123")
    }

    // MARK: - SessionSummary

    func testSessionSummaryDecoding() throws {
        let json = """
        {
            "additions": 100,
            "deletions": 50,
            "files": 5,
            "diffs": [
                {"file": "a.swift", "before": "", "after": "code", "additions": 10, "deletions": 0}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let summary = try JSONDecoder().decode(SessionSummary.self, from: data)
        XCTAssertEqual(summary.additions, 100)
        XCTAssertEqual(summary.deletions, 50)
        XCTAssertEqual(summary.files, 5)
        XCTAssertEqual(summary.diffs?.count, 1)
    }

    // MARK: - SessionRevert

    func testSessionRevertDecoding() throws {
        let json = """
        {
            "messageID": "msg_123",
            "partID": "part_456",
            "snapshot": "snap_abc",
            "diff": "--- a\\n+++ b"
        }
        """
        let data = json.data(using: .utf8)!
        let revert = try JSONDecoder().decode(SessionRevert.self, from: data)
        XCTAssertEqual(revert.messageID, "msg_123")
        XCTAssertEqual(revert.partID, "part_456")
        XCTAssertEqual(revert.snapshot, "snap_abc")
        XCTAssertEqual(revert.diff, """
        --- a
        +++ b
        """)
    }

    func testSessionRevertMinimalDecoding() throws {
        let json = """
        {"messageID": "msg_abc"}
        """
        let data = json.data(using: .utf8)!
        let revert = try JSONDecoder().decode(SessionRevert.self, from: data)
        XCTAssertEqual(revert.messageID, "msg_abc")
        XCTAssertNil(revert.partID)
        XCTAssertNil(revert.snapshot)
        XCTAssertNil(revert.diff)
    }

    // MARK: - Helpers

    private func makeSession(
        id: String = "ses_test",
        title: String = "Test Session",
        directory: String = "/test/project",
        projectID: String = "proj_test",
        created: Int64 = 1_700_000_000_000
    ) -> Session {
        let json = """
        {
            "id": "\(id)",
            "projectID": "\(projectID)",
            "directory": "\(directory)",
            "title": "\(title)",
            "time": {"created": \(created)}
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(Session.self, from: data)
    }
}
