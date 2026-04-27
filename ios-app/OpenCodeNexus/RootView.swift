import SwiftUI

struct RootView: View {
    @Environment(ConnectionManager.self) private var connectionManager

    var body: some View {
        if connectionManager.isConnected {
            ChatView()
        } else {
            ConnectView()
        }
    }
}
