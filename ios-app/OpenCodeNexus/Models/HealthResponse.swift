import Foundation

struct HealthResponse: Codable {
    let healthy: Bool
    let version: String
}
