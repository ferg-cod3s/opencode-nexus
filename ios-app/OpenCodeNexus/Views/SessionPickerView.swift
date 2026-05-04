import SwiftUI

struct SessionPickerView: View {
    @Observable private var chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(chatVM.sessionGroups, id: \.directory) { group in
                    Section(group.name) {
                        ForEach(group.sessions) { session in
                            Button {
                                Task { await chatVM.selectSession(session.id) }
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.displayTitle)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(session.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Switch Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
