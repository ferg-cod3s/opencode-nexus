import SwiftUI
import os

@MainActor
@Observable
final class ConnectionManager {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "ConnectionManager")
    let serverStore: ServerStore
    var isConnected = false
    var isConnecting = false
    var testResult: TestResult?

    private(set) var client: OpenCodeClient?
    private var connectTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?

    enum TestResult {
        case success(version: String)
        case failure(String)
    }

    init(serverStore: ServerStore) {
        self.serverStore = serverStore
    }

    func connect(to config: ServerConfig) async {
        connectTask?.cancel()
        let task = Task {
            isConnecting = true
            testResult = nil

            guard !Task.isCancelled else {
                isConnecting = false
                return
            }

            guard let url = resolveURL(config.url) else {
                testResult = .failure("Invalid URL")
                isConnecting = false
                return
            }

            let testClient = makeClient(for: config, url: url)
            do {
                let health = try await testClient.healthCheck()
                guard !Task.isCancelled else {
                    isConnecting = false
                    return
                }
                if health.healthy {
                    client = testClient
                    testResult = .success(version: health.version)
                    isConnected = true
                    serverStore.setActive(id: config.id)
                    serverStore.updateHealth(id: config.id, healthy: true)
                    startHealthPolling()
                } else {
                    testResult = .failure("Server reports unhealthy status")
                    serverStore.updateHealth(id: config.id, healthy: false)
                }
            } catch {
                guard !Task.isCancelled else {
                    isConnecting = false
                    return
                }
                testResult = .failure(error.localizedDescription)
                serverStore.updateHealth(id: config.id, healthy: false)
            }
            isConnecting = false
        }
        connectTask = task
        defer { connectTask = nil }
        await task.value
    }

    func connectAndTest() async {
        guard let config = serverStore.activeServer else {
            testResult = .failure("No server configured")
            return
        }
        await connect(to: config)
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        stopHealthPolling()
        client = nil
        isConnected = false
        testResult = nil
    }

    func testConnection(_ config: ServerConfig) async -> TestResult {
        guard let url = resolveURL(config.url) else {
            return .failure("Invalid URL")
        }
        let testClient = makeClient(for: config, url: url)
        do {
            let health = try await testClient.healthCheck()
            if health.healthy {
                return .success(version: health.version)
            } else {
                return .failure("Server reports unhealthy status")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func startHealthPolling(interval: TimeInterval = 10) {
        stopHealthPolling()
        healthPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await pollAllServers()
            }
        }
    }

    func stopHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = nil
    }

    private func pollAllServers() async {
        for config in serverStore.servers {
            guard let url = resolveURL(config.url) else {
                serverStore.updateHealth(id: config.id, healthy: false)
                continue
            }
            let pollClient = makeClient(for: config, url: url)
            do {
                let health = try await pollClient.healthCheck()
                serverStore.updateHealth(id: config.id, healthy: health.healthy)
            } catch {
                serverStore.updateHealth(id: config.id, healthy: false)
            }
        }
    }

    private func makeClient(for config: ServerConfig, url: URL) -> OpenCodeClient {
        let secrets = config.secrets()
        return OpenCodeClient(
            baseURL: url,
            cfAccessClientId: secrets.cfClientId,
            cfAccessClientSecret: secrets.cfClientSecret,
            username: config.username,
            password: secrets.password
        )
    }

    private func resolveURL(_ string: String) -> URL? {
        var urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        return URL(string: urlString)
    }
}
