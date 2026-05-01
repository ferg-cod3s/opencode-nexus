import SwiftUI
import os

@MainActor
@Observable
final class ServerStore {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "ServerStore")
    var servers: [ServerConfig] = []
    var activeServerId: UUID?

    private let serversKey = "opencode-nexus.servers.v1"
    private let activeKey = "opencode-nexus.active-server"
    private let migratedKey = "opencode-nexus.migrated-v1"

    var activeServer: ServerConfig? {
        guard let activeServerId else {
            return servers.first
        }
        return servers.first { $0.id == activeServerId }
    }

    var defaultServer: ServerConfig? {
        servers.first { $0.isDefault } ?? servers.first
    }

    init() {
        load()
        if servers.isEmpty {
            migrateFromLegacy()
        }
    }

    func addServer(_ config: ServerConfig) {
        if config.isDefault {
            for i in servers.indices { servers[i].isDefault = false }
        }
        if let existingIndex = servers.firstIndex(where: { $0.id == config.id }) {
            servers[existingIndex] = config
        } else {
            servers.append(config)
        }
        save()
    }

    func updateServer(_ config: ServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else { return }
        if config.isDefault {
            for i in servers.indices where i != index { servers[i].isDefault = false }
        }
        servers[index] = config
        save()
    }

    func removeServer(id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        let removed = servers.remove(at: index)
        removed.deleteSecrets()
        if activeServerId == id {
            activeServerId = servers.first?.id
        }
        if removed.isDefault, !servers.isEmpty {
            servers[0].isDefault = true
        }
        save()
    }

    func setActive(id: UUID) {
        guard servers.contains(where: { $0.id == id }) else { return }
        activeServerId = id
        UserDefaults.standard.set(id.uuidString, forKey: activeKey)
    }

    func setDefault(id: UUID) {
        for i in servers.indices { servers[i].isDefault = (servers[i].id == id) }
        save()
    }

    func updateHealth(id: UUID, healthy: Bool?) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].isHealthy = healthy
        servers[index].lastHealthCheck = Date()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(servers)
            UserDefaults.standard.set(data, forKey: serversKey)
        } catch {
            logger.error("Failed to save servers: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: serversKey) else { return }
        do {
            servers = try JSONDecoder().decode([ServerConfig].self, from: data)
            if let activeString = UserDefaults.standard.string(forKey: activeKey),
               let uuid = UUID(uuidString: activeString) {
                activeServerId = servers.contains { $0.id == uuid } ? uuid : nil
            }
        } catch {
            logger.error("Failed to load servers: \(error)")
            servers = []
        }
    }

    private func migrateFromLegacy() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        let legacyURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:4096"
        let trimmed = legacyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cfClientId = KeychainHelper.load(key: "cfAccessClientId")
        let cfClientSecret = KeychainHelper.load(key: "cfAccessClientSecret")

        let config = ServerConfig(
            url: trimmed,
            displayName: trimmed.contains("localhost") ? "Local Server" : nil,
            cfAccessClientId: cfClientId,
            cfAccessClientSecret: cfClientSecret,
            isDefault: true
        )

        servers = [config]
        activeServerId = config.id
        save()

        UserDefaults.standard.set(true, forKey: migratedKey)
        logger.info("Migrated legacy server config to ServerStore")
    }
}
