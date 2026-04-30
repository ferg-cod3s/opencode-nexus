import SwiftUI

struct RootView: View {
    @Environment(ConnectionManager.self) private var connectionManager

    var body: some View {
        Group {
            if connectionManager.isConnected {
                ChatView()
                    .transition(.opacity)
            } else if connectionManager.serverStore.servers.isEmpty {
                ConnectView()
                    .transition(.opacity)
            } else {
                ServerListView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: connectionManager.isConnected)
        .animation(.easeInOut(duration: 0.3), value: connectionManager.serverStore.servers.isEmpty)
    }
}
