import SwiftUI

@Observable
final class ConnectionManager {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var isConnected = false
    var isTesting = false
    var testResult: TestResult?

    private(set) var client: OpenCodeClient?

    enum TestResult {
        case success(version: String)
        case failure(String)
    }

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:4096"
    }

    func testConnection() async {
        isTesting = true
        testResult = nil

        guard let url = resolveURL() else {
            testResult = .failure("Invalid URL")
            isTesting = false
            return
        }

        let testClient = OpenCodeClient(baseURL: url)
        do {
            let health = try await testClient.healthCheck()
            if health.healthy {
                testResult = .success(version: health.version)
            } else {
                testResult = .failure("Server reports unhealthy status")
            }
        } catch {
            testResult = .failure(error.localizedDescription)
        }
        isTesting = false
    }

    func connect() {
        guard let url = resolveURL() else { return }
        client = OpenCodeClient(baseURL: url)
        isConnected = true
    }

    func disconnect() {
        client = nil
        isConnected = false
        testResult = nil
    }

    private func resolveURL() -> URL? {
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://" + urlString
        }
        return URL(string: urlString)
    }
}
