import SwiftUI

struct ConnectView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @FocusState private var isURLFocused: Bool

    @State private var url: String = "http://localhost:4096"
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showAdvanced = false
    @State private var cfAccessClientId: String = ""
    @State private var cfAccessClientSecret: String = ""

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
                .init(color: Theme.interactiveBlue.opacity(0.08), location: 1)
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
                urlSection
                displaySection
                authSection
                cfAccessSection
                testResultBanner
                connectButton
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
                    .fill(Theme.brandYuzu.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .glassEffect(.clear, in: .circle)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.brandYuzu)
            }

            Text("OpenCode Nexus")
                .font(.largeTitle.bold())

            Text("Connect to your OpenCode server to manage AI coding sessions")
                .font(.subheadline)
                .foregroundStyle(Theme.textBase)
                .multilineTextAlignment(.center)
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server URL")
                .font(.caption)
                .foregroundStyle(Theme.textBase)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(Theme.textBase)
                    .font(.body)
                TextField("http://localhost:4096", text: $url)
                    .font(.body)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isURLFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(.caption)
                .foregroundStyle(Theme.textBase)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .foregroundStyle(Theme.textBase)
                    .font(.body)
                TextField("My Server", text: $displayName)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Authentication")
                .font(.caption)
                .foregroundStyle(Theme.textBase)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 12) {
                Image(systemName: "person")
                    .foregroundStyle(Theme.textBase)
                    .font(.body)
                TextField("Username (optional)", text: $username)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }

            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(Theme.textBase)
                    .font(.body)
                SecureField("Password (optional)", text: $password)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay { Theme.borderOverlay(radius: 12) }
        }
    }

    private var cfAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(Theme.textBase)
                    Text("Advanced: Cloudflare Zero Trust")
                        .font(.caption)
                        .foregroundStyle(Theme.textBase)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.textWeak)
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CF-Access-Client-Id")
                            .font(.caption2)
                            .foregroundStyle(Theme.textWeak)
                        HStack(spacing: 12) {
                            Image(systemName: "number")
                                .foregroundStyle(Theme.textBase)
                                .font(.body)
                            TextField("Client ID", text: $cfAccessClientId)
                                .font(.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .overlay { Theme.borderOverlay(radius: 12) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CF-Access-Client-Secret")
                            .font(.caption2)
                            .foregroundStyle(Theme.textWeak)
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(Theme.textBase)
                                .font(.body)
                            SecureField("Client Secret", text: $cfAccessClientSecret)
                                .font(.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        .overlay { Theme.borderOverlay(radius: 12) }
                    }

                    Text("Enter service token credentials from your Cloudflare Zero Trust dashboard")
                        .font(.caption2)
                        .foregroundStyle(Theme.textWeak)
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
                        Text("Connected")
                            .font(.subheadline.weight(.semibold))
                        Text("Server version \(version)")
                            .font(.caption)
                            .foregroundStyle(Theme.success.opacity(0.8))
                    }
                    Spacer()
                }
                .foregroundStyle(Theme.success)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay { Theme.borderOverlay(radius: 12) }
                .tint(Theme.success)

            case .failure(let message):
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection Failed")
                            .font(.subheadline.weight(.semibold))
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Theme.errorCritical.opacity(0.8))
                    }
                    Spacer()
                }
                .foregroundStyle(Theme.errorCritical)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay { Theme.borderOverlay(radius: 12) }
                .tint(Theme.errorCritical)
            }
        }
    }

    private var connectButton: some View {
        Button {
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            let config = ServerConfig(
                url: trimmedURL,
                displayName: displayName.isEmpty ? (trimmedURL.contains("localhost") ? "Local Server" : nil) : displayName,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                cfAccessClientId: cfAccessClientId.isEmpty ? nil : cfAccessClientId,
                cfAccessClientSecret: cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret,
                isDefault: connectionManager.serverStore.servers.isEmpty
            )
            connectionManager.serverStore.addServer(config)
            Task { @MainActor in await connectionManager.connect(to: config) }
        } label: {
            HStack(spacing: 10) {
                if connectionManager.isConnecting {
                    ProgressView()
                        .tint(Theme.buttonPrimaryText)
                        .controlSize(.regular)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(connectionManager.isConnecting ? "Connecting..." : "Connect")
            }
            .font(.headline)
            .foregroundStyle(Theme.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.buttonPrimaryBG)
            }
        }
        .disabled(connectionManager.isConnecting || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
