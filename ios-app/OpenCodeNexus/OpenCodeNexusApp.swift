import SwiftUI

@main
struct OpenCodeNexusApp: App {
    @State private var serverStore: ServerStore
    @State private var connectionManager: ConnectionManager

    init() {
        let store = ServerStore()
        _serverStore = State(initialValue: store)
        _connectionManager = State(initialValue: ConnectionManager(serverStore: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(connectionManager)
                .environment(serverStore)
        }
    }
}
