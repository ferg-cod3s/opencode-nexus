import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel
    let chatVM: ChatViewModel?
    
    init(viewModel: SettingsViewModel, chatVM: ChatViewModel? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.chatVM = chatVM
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Reasoning Summaries", isOn: $viewModel.reasoningSummariesEnabled)
                        .onChange(of: viewModel.reasoningSummariesEnabled) { _, _ in
                            viewModel.save()
                        }
                    
                    Toggle("Session Progress Bar", isOn: $viewModel.sessionProgressBarEnabled)
                        .onChange(of: viewModel.sessionProgressBarEnabled) { _, _ in
                            viewModel.save()
                        }
                    
                    Toggle("Expand Shell Tool Parts", isOn: $viewModel.shellToolPartsExpanded)
                        .onChange(of: viewModel.shellToolPartsExpanded) { _, _ in
                            viewModel.save()
                        }
                    
                    Toggle("Expand Edit Tool Parts", isOn: $viewModel.editToolPartsExpanded)
                        .onChange(of: viewModel.editToolPartsExpanded) { _, _ in
                            viewModel.save()
                        }
                }
                
                Section("Permissions") {
                    Toggle("Auto-Accept Permissions", isOn: $viewModel.autoAcceptPermissions)
                        .onChange(of: viewModel.autoAcceptPermissions) { _, _ in
                            viewModel.save()
                        }
                    
                    if let chatVM = chatVM {
                        Button(role: .destructive) {
                            chatVM.clearAllPersistedResponses()
                        } label: {
                            Text("Clear Persisted Responses")
                        }
                        if let lastCleared = chatVM.lastClearedDate {
                            Text("Last cleared: " + relativeDateString(for: lastCleared))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Theme") {
                    Text("Theme selection coming soon")
                        .foregroundStyle(.secondary)
                }
                
                Section("Language") {
                    Text("Language selection coming soon")
                        .foregroundStyle(.secondary)
                }
                
                Section("Models") {
                    Text("Model visibility management coming soon")
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(version)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        HStack {
                            Text("Build")
                            Spacer()
                            Text(build)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let gitHash = Bundle.main.infoDictionary?["GitHash"] as? String {
                        HStack {
                            Text("Git Hash")
                            Spacer()
                            Text(gitHash)
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
