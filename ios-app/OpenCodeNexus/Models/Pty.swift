import Foundation

struct Pty: Codable, Identifiable {
    let id: String
    let title: String
    let command: String
    let args: [String]?
    let cwd: String?
    let status: String
    let pid: Int?

    var isRunning: Bool { status == "running" }
    var hasExited: Bool { status == "exited" }
}
