import SwiftUI

struct ServerEditView: View {
    let serverStore: ServerStore
    let existingServer: ServerConfig?

    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showAdvanced = false
    @State private var cfAccessClientId: String = ""
    @State private var cfAccessClientSecret: String = ""
    @State private var isTesting = false
    @State private var testResult: ConnectionManager.TestResult?

    private var isEditing: Bool { existingServer != nil }
    private var isValid: Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    init(serverStore: ServerStore, existingServer: ServerConfig? = nil) {
        self.serverStore = serverStore
        self.existingServer = existingServer
    }

    var body: some View {
        NavigationStack {
            Form {
                urlSection
                displaySection
                authSection
                cfAccessSection
                testSection
            }
            .navigationTitle(isEditing ? "Edit Server" : "Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let existing = existingServer {
                    url = existing.url
                    displayName = existing.displayName ?? ""
                    username = existing.username ?? ""
                    let secrets = existing.secrets()
                    password = secrets.password ?? ""
                    cfAccessClientId = secrets.cfClientId ?? ""
                    cfAccessClientSecret = secrets.cfClientSecret ?? ""
                    showAdvanced = existing.hasCFAccess || existing.hasPassword
                }
            }
        }
    }

    private var urlSection: some View {
        Section {
            TextField("http://localhost:4096", text: $url)
                .font(.body)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Server URL")
        }
    }

    private var displaySection: some View {
        Section {
            TextField("My Server", text: $displayName)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Display Name")
        } footer: {
            Text("Optional. Shows the URL if left empty.")
        }
    }

    private var authSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Username")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("opencode", text: $username)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                SecureField("Password", text: $password)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Authentication")
        }
    }

    private var cfAccessSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                    Text("Cloudflare Zero Trust")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CF-Access-Client-Id")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Client ID", text: $cfAccessClientId)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CF-Access-Client-Secret")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    SecureField("Client Secret", text: $cfAccessClientSecret)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isTesting ? "Testing..." : "Test Connection")
                }
            }
            .disabled(isTesting || !isValid)

            if let result = testResult {
                switch result {
                case .success(let version):
                    Label("Connected (v\(version))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                case .failure(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        let tempConfig = ServerConfig(
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            cfAccessClientId: cfAccessClientId.isEmpty ? nil : cfAccessClientId,
            cfAccessClientSecret: cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret
        )
        let connectionManager = ConnectionManager(serverStore: serverStore)
        testResult = await connectionManager.testConnection(tempConfig)
        isTesting = false
    }

    private func save() {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        if let existing = existingServer {
            var updated = existing
            updated.url = trimmedURL
            updated.displayName = displayName.isEmpty ? nil : displayName
            updated.username = username.isEmpty ? nil : username
            updated.password = password.isEmpty ? nil : password
            updated.cfAccessClientId = cfAccessClientId.isEmpty ? nil : cfAccessClientId
            updated.cfAccessClientSecret = cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret
            updated.hasPassword = !password.isEmpty
            updated.hasCFAccess = !cfAccessClientId.isEmpty
            serverStore.updateServer(updated)
        } else {
            let config = ServerConfig(
                url: trimmedURL,
                displayName: displayName.isEmpty ? nil : displayName,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                cfAccessClientId: cfAccessClientId.isEmpty ? nil : cfAccessClientId,
                cfAccessClientSecret: cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret,
                isDefault: serverStore.servers.isEmpty
            )
            serverStore.addServer(config)
        }
        dismiss()
    }
}
