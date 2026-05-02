import Foundation
import SwiftUI

@MainActor
@Observable
class ProviderManagerViewModel {
    var providers: [ProviderInfo] = []
    var connectedProviders: [String] = []
    var isLoading = false
    var errorMessage: String?
    
    private var client: OpenCodeClient?
    
    func configure(with client: OpenCodeClient) {
        self.client = client
    }
    
    func loadProviders() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.listProviders()
            providers = response.all ?? []
            connectedProviders = response.connected ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func connectProvider(_ providerID: String) async {
        guard let client else { return }
        do {
            let oauthResponse = try await client.startProviderOAuth(providerID: providerID)
            if let url = URL(string: oauthResponse.url) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func disconnectProvider(_ providerID: String) async {
        guard let client else { return }
        do {
            try await client.disconnectProvider(providerID: providerID)
            await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProviderManagerView: View {
    @State private var viewModel: ProviderManagerViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: ProviderManagerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading providers...")
                } else if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.errorCritical)
                } else {
                    Section("Connected") {
                        ForEach(viewModel.providers.filter { viewModel.connectedProviders.contains($0.id) }) { provider in
                            ProviderRow(provider: provider, isConnected: true, viewModel: viewModel)
                        }
                    }
                    
                    Section("Available") {
                        ForEach(viewModel.providers.filter { !viewModel.connectedProviders.contains($0.id) }) { provider in
                            ProviderRow(provider: provider, isConnected: false, viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("AI Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadProviders()
            }
        }
    }
}

struct ProviderRow: View {
    let provider: ProviderInfo
    let isConnected: Bool
    let viewModel: ProviderManagerViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name ?? provider.id)
                    .font(.body.weight(.semibold))
                
                if let modelCount = provider.models?.count {
                    Text("\(modelCount) models")
                        .font(.caption)
                        .foregroundStyle(Theme.textWeak)
                }
            }
            
            Spacer()
            
            if isConnected {
                Button("Disconnect") {
                    Task { @MainActor in
                        await viewModel.disconnectProvider(provider.id)
                    }
                }
                .buttonStyle(.borderless)
            } else {
                Button("Connect") {
                    Task { @MainActor in
                        await viewModel.connectProvider(provider.id)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
