import Foundation

struct Session: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let slug: String
    let projectID: String
    let time: TimeInfo

    enum CodingKeys: String, CodingKey {
        case id, title, slug, time
        case projectID = "projectID"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

struct TimeInfo: Codable {
    let created: Int64
    let updated: Int64?

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created) / 1000)
    }

    var updatedDate: Date? {
        updated.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }
}
