import SwiftUI

struct NewSessionView: View {
    let chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    TextField("My coding session", text: Bindable(chatVM).newSessionTitle)
                        .font(.body)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                        .focused($isTitleFocused)
                }

                Button {
                    Task {
                        await chatVM.createSession()
                        dismiss()
                    }
                } label: {
                    Text("Create Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                }
                .buttonStyle(.glassProminent)
                .disabled(!canCreate)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }

    private var canCreate: Bool {
        !chatVM.newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
