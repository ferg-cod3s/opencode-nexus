import Foundation

struct Session: Codable, Identifiable, Hashable {
    let id: String
    let projectID: String
    let directory: String
    let parentID: String?
    let summary: SessionSummary?
    let share: SessionShare?
    let title: String
    let version: String
    let time: TimeInfo
    let revert: SessionRevert?

    enum CodingKeys: String, CodingKey {
        case id, title, directory, time, summary, share, version, revert
        case projectID = "projectID"
        case parentID = "parentID"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        projectID = (try? container.decode(String.self, forKey: .projectID)) ?? ""
        directory = try container.decode(String.self, forKey: .directory)
        parentID = try? container.decodeIfPresent(String.self, forKey: .parentID)
        summary = try? container.decodeIfPresent(SessionSummary.self, forKey: .summary)
        share = try? container.decodeIfPresent(SessionShare.self, forKey: .share)
        title = try container.decode(String.self, forKey: .title)
        version = (try? container.decode(String.self, forKey: .version)) ?? ""
        time = try container.decode(TimeInfo.self, forKey: .time)
        revert = try? container.decodeIfPresent(SessionRevert.self, forKey: .revert)
    }

    var displayTitle: String {
        if title.hasPrefix("New session") || title.isEmpty {
            let slug = id.hasPrefix("ses_") ? String(id.dropFirst(4)) : id
            return slug.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return title
    }

    var workspaceName: String {
        let components = directory.split(separator: "/")
        if let last = components.last, !last.isEmpty {
            return String(last)
        }
        return directory
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

struct SessionSummary: Codable {
    let additions: Int
    let deletions: Int
    let files: Int
    let diffs: [FileDiff]?
}

struct SessionShare: Codable {
    let url: String
}

struct SessionRevert: Codable {
    let messageID: String
    let partID: String?
    let snapshot: String?
    let diff: String?
}

struct FileDiff: Codable {
    let file: String
    let before: String
    let after: String
    let additions: Int
    let deletions: Int
}

struct TimeInfo: Codable {
    let created: Int64
    let updated: Int64?
    let compacting: Int64?
    let archived: Int64?

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created) / 1000)
    }

    var updatedDate: Date? {
        updated.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }
}
