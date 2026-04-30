import Foundation

struct Project: Codable, Identifiable {
    let id: String
    let worktree: String
    let vcsDir: String?
    let vcs: String?
    let time: ProjectTime
    let sandboxes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, worktree, vcs, time, sandboxes
        case vcsDir = "vcsDir"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        worktree = try container.decode(String.self, forKey: .worktree)
        vcsDir = try? container.decodeIfPresent(String.self, forKey: .vcsDir)
        vcs = try? container.decodeIfPresent(String.self, forKey: .vcs)
        time = try container.decode(ProjectTime.self, forKey: .time)
        sandboxes = try? container.decodeIfPresent([String].self, forKey: .sandboxes)
    }

    struct ProjectTime: Codable {
        let created: Int64
        let updated: Int64?
        let initialized: Int64?
    }

    var displayPath: String {
        let components = worktree.split(separator: "/")
        return components.last.map(String.init) ?? worktree
    }
}
