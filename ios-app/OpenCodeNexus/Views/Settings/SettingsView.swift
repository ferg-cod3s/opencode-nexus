import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
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
