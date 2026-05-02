import SwiftUI
import os

@MainActor
@Observable
final class TerminalTabManager {
    private let logger = Logger(subsystem: "com.agentic-codeflow.opencode-nexus", category: "TerminalTabManager")

    struct TerminalTab: Identifiable, Equatable {
        let id: String
        var title: String
        var viewModel: TerminalViewModel

        static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
            lhs.id == rhs.id
        }
    }

    var tabs: [TerminalTab] = []
    var selectedTabId: String?

    private let client: OpenCodeClient?
    private let sessionId: String?
    private let directory: String?
    private let agent: String?
    private var tabCounter = 0

    init(client: OpenCodeClient?, sessionId: String?, directory: String?, agent: String?) {
        self.client = client
        self.sessionId = sessionId
        self.directory = directory
        self.agent = agent
    }

    var selectedTab: TerminalTab? {
        guard let selectedTabId else { return nil }
        return tabs.first { $0.id == selectedTabId }
    }

    func addTerminal() {
        tabCounter += 1
        let id = "terminal_\(tabCounter)"
        let vm = TerminalViewModel()
        vm.configure(client: client, sessionId: sessionId, directory: directory, agent: agent)
        let tab = TerminalTab(id: id, title: "Terminal \(tabCounter)", viewModel: vm)
        tabs.append(tab)
        selectedTabId = id
        Task { await vm.startTerminal() }
    }

    func closeTerminal(id: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        Task { await tab.viewModel.closeTerminal() }
        tabs.remove(at: index)

        if selectedTabId == id {
            if let newSelected = tabs.last {
                selectedTabId = newSelected.id
            } else {
                selectedTabId = nil
            }
        }
    }

    func selectTerminal(id: String) {
        selectedTabId = id
    }

    func closeAll() async {
        for tab in tabs {
            await tab.viewModel.closeTerminal()
        }
        tabs.removeAll()
        selectedTabId = nil
        tabCounter = 0
    }
}
