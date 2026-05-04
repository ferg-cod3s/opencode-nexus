import SwiftUI

struct ModelPickerView: View {
    @Bindable private var chatVM: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(chatVM.availableModels, id: \.modelID) { model in
                    Button {
                        chatVM.selectedModel = ModelRefBody(
                            providerID: model.providerID, modelID: model.modelID)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name)
                                    .font(.body)
                                Text("\(model.providerID) · \(model.modelID)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chatVM.selectedModel?.modelID == model.modelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.interactiveBlue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
