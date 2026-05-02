import Foundation

protocol HealthCheckable: Sendable {
    func healthCheck() async throws -> HealthResponse
}

extension OpenCodeClient: HealthCheckable {}

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    func checkForUpdate(client: some HealthCheckable) async -> UpdateInfo? {
        do {
            let health = try await client.healthCheck()
            let serverVersion = health.version
            
            if isNewerVersion(serverVersion, than: currentVersion) {
                return UpdateInfo(
                    currentVersion: currentVersion,
                    serverVersion: serverVersion,
                    releaseNotes: "Server update available"
                )
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func isNewerVersion(_ version: String, than current: String) -> Bool {
        let serverComponents = version.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(serverComponents.count, currentComponents.count) {
            let serverPart = i < serverComponents.count ? serverComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            
            if serverPart > currentPart {
                return true
            } else if serverPart < currentPart {
                return false
            }
        }
        return false
    }
}

struct UpdateInfo {
    let currentVersion: String
    let serverVersion: String
    let releaseNotes: String
}
