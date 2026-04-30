import SwiftUI

struct PermissionSheet: View {
    let chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if chatVM.selectedPendingPermissions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.success)
                        Text("All permissions resolved")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textBase)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                ForEach(chatVM.selectedPendingPermissions) { permission in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .foregroundStyle(Theme.brandYuzu)
                            Text(permission.title)
                                .font(.body.weight(.medium))
                        }

                        Text("Type: \(permission.type)")
                            .font(.caption)
                            .foregroundStyle(Theme.textBase)

                        HStack(spacing: 12) {
                            Button {
                                Task { await chatVM.approvePermission(permission) }
                            } label: {
                                Text("Allow")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.success)

                            Button {
                                Task { await chatVM.approvePermission(permission, always: true) }
                            } label: {
                                Text("Always Allow")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.success)

                            Button(role: .destructive) {
                                Task { await chatVM.rejectPermission(permission) }
                            } label: {
                                Text("Deny")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.errorCritical)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
                }
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: chatVM.selectedPendingPermissions.isEmpty) {
                if chatVM.selectedPendingPermissions.isEmpty { dismiss() }
            }
        }
    }
}
