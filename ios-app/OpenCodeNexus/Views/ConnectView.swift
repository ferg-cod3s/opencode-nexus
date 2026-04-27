import SwiftUI

struct ConnectView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @FocusState private var isURLFocused: Bool
    @State private var showCFAccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                contentView
            }
            .navigationBarHidden(true)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemBackground), location: 0),
                .init(color: .blue.opacity(0.08), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 36) {
                Spacer().frame(height: 40)
                headerSection
                serverInputSection
                cfAccessSection
                testResultBanner
                actionButtons
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .glassEffect(.clear, in: .circle)
                Image(systemName: "terminal.connected")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.blue)
            }

            Text("OpenCode Nexus")
                .font(.largeTitle.bold())

            Text("Connect to your OpenCode server to manage AI coding sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var serverInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server URL")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("http://localhost:4096", text: Bindable(connectionManager).serverURL)
                    .font(.body)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isURLFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }

    private var cfAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showCFAccess.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "shield.locked.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Advanced: Cloudflare Zero Trust")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showCFAccess ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showCFAccess {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CF-Access-Client-Id")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 12) {
                            Image(systemName: "number")
                                .foregroundStyle(.secondary)
                                .font(.body)
                            TextField("Client ID", text: Bindable(connectionManager).cfAccessClientId)
                                .font(.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CF-Access-Client-Secret")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .font(.body)
                            SecureField("Client Secret", text: Bindable(connectionManager).cfAccessClientSecret)
                                .font(.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }

                    Text("Enter service token credentials from your Cloudflare Zero Trust dashboard")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var testResultBanner: some View {
        if let result = connectionManager.testResult {
            switch result {
            case .success(let version):
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection Successful")
                            .font(.subheadline.weight(.semibold))
                        Text("Server version \(version)")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    Spacer()
                }
                .foregroundStyle(.green)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .tint(.green)

            case .failure(let message):
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection Failed")
                            .font(.subheadline.weight(.semibold))
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .tint(.red)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                Task { await connectionManager.testConnection() }
            } label: {
                HStack(spacing: 10) {
                    if connectionManager.isTesting {
                        ProgressView()
                            .tint(.primary)
                            .controlSize(.regular)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Text(connectionManager.isTesting ? "Testing..." : "Test Connection")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .buttonStyle(.glass)
            .disabled(connectionManager.isTesting)

            let canConnect: Bool = {
                if case .success = connectionManager.testResult { return true }
                return false
            }()

            Button {
                connectionManager.connect()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Connect")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
            }
            .buttonStyle(.glassProminent)
            .disabled(!canConnect)
        }
    }
}
