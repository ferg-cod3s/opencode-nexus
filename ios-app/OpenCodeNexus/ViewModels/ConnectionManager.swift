import SwiftUI

@Observable
final class ConnectionManager {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var cfAccessClientId: String {
        didSet { UserDefaults.standard.set(cfAccessClientId, forKey: "cfAccessClientId") }
    }
    var cfAccessClientSecret: String {
        didSet { UserDefaults.standard.set(cfAccessClientSecret, forKey: "cfAccessClientSecret") }
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
        let defaults = UserDefaults.standard
        self.serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:4096"
        self.cfAccessClientId = defaults.string(forKey: "cfAccessClientId") ?? ""
        self.cfAccessClientSecret = defaults.string(forKey: "cfAccessClientSecret") ?? ""
    }

    private var cfCredentials: (clientId: String, clientSecret: String)? {
        let id = cfAccessClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = cfAccessClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return nil }
        return (id, secret)
    }

    func testConnection() async {
        isTesting = true
        testResult = nil

        guard let url = resolveURL() else {
            testResult = .failure("Invalid URL")
            isTesting = false
            return
        }

        let testClient = makeClient(url: url)
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
        client = makeClient(url: url)
        isConnected = true
    }

    func disconnect() {
        client = nil
        isConnected = false
        testResult = nil
    }

    private func makeClient(url: URL) -> OpenCodeClient {
        if let creds = cfCredentials {
            return OpenCodeClient(baseURL: url, cfAccessClientId: creds.clientId, cfAccessClientSecret: creds.clientSecret)
        }
        return OpenCodeClient(baseURL: url)
    }

    private func resolveURL() -> URL? {
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://" + urlString
        }
        return URL(string: urlString)
    }
}
