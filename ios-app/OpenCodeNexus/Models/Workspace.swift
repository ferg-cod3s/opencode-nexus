import Foundation

struct Workspace: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let branch: String?
    let directory: String
    let status: String?
    let projectID: String?
    let time: WorkspaceTime?

    struct WorkspaceTime: Codable {
        let created: Int64?
        let updated: Int64?
    }

    var displayBranch: String {
        branch ?? "main"
    }

    var displayName: String {
        directory.split(separator: "/").last.map(String.init) ?? directory
    }

    var isConnected: Bool {
        status == "connected"
    }

    var isConnecting: Bool {
        status == "connecting"
    }

    var hasError: Bool {
        status == "error"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        branch = try container.decodeIfPresent(String.self, forKey: .branch)
        directory = try container.decodeIfPresent(String.self, forKey: .directory) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status)
        projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
        time = try container.decodeIfPresent(WorkspaceTime.self, forKey: .time)
    }
}

struct WorkspaceStatus: Codable {
    let status: String
    let error: String?
    let workspaceID: String?

    var isConnected: Bool {
        status == "connected"
    }

    var isConnecting: Bool {
        status == "connecting"
    }

    var hasError: Bool {
        status == "error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        error = try container.decodeIfPresent(String.self, forKey: .error)
        workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID)
    }
}

struct WorkspaceAdaptor: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id = "type"
        case name
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}
