import SwiftUI

/// In-app log viewer + share sheet. The TestFlight escape hatch:
/// when a crash happens, users can come here and AirDrop us the log file.
struct LogsView: View {
    @State private var logTail: String = ""
    @State private var refreshing = false

    private var logFileURLs: [URL] { FileLogger.shared.currentLogFiles() }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(logTail.isEmpty ? "(no log entries yet)" : logTail)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal)
                        .id("logBottom")
                }
            }
            .onAppear {
                refresh()
                DispatchQueue.main.async { proxy.scrollTo("logBottom", anchor: .bottom) }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !logFileURLs.isEmpty {
                        ForEach(logFileURLs, id: \.self) { url in
                            ShareLink(item: url) {
                                Label(url.lastPathComponent, systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    Button {
                        refresh()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Log actions")
            }
        }
    }

    private func refresh() {
        refreshing = true
        // Block briefly on a background queue read so we don't stall the UI.
        DispatchQueue.global(qos: .userInitiated).async {
            let snapshot = FileLogger.shared.currentLogContents()
            DispatchQueue.main.async {
                self.logTail = snapshot
                self.refreshing = false
            }
        }
    }
}
