import SwiftUI

@main
struct OpenCodeNexusApp: App {
    @State private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(connectionManager)
        }
    }
}
