import Foundation

struct Project: Codable, Identifiable {
    let id: String
    let worktree: String
    let vcsDir: String?
    let vcs: String?
    let name: String?
    let icon: ProjectIcon?
    let commands: ProjectCommands?
    let time: ProjectTime
    let sandboxes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, worktree, vcs, time, sandboxes, name, icon, commands
        case vcsDir = "vcsDir"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        worktree = try container.decode(String.self, forKey: .worktree)
        vcsDir = try? container.decodeIfPresent(String.self, forKey: .vcsDir)
        vcs = try? container.decodeIfPresent(String.self, forKey: .vcs)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        icon = try? container.decodeIfPresent(ProjectIcon.self, forKey: .icon)
        commands = try? container.decodeIfPresent(ProjectCommands.self, forKey: .commands)
        time = try container.decode(ProjectTime.self, forKey: .time)
        sandboxes = try? container.decodeIfPresent([String].self, forKey: .sandboxes)
    }

    struct ProjectTime: Codable {
        let created: Int64
        let updated: Int64?
        let initialized: Int64?
    }

    var displayPath: String {
        name ?? worktree.split(separator: "/").last.map(String.init) ?? worktree
    }
}

struct ProjectIcon: Codable {
    let url: String?
    let color: String?
}

struct ProjectCommands: Codable {
    let start: String?
}
