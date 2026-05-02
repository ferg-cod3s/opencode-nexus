import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImageAttachmentPicker: View {
    let onImageAttached: (Data, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageData: Data?
    @State private var selectedImageName: String?
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Add an image to your prompt")
                    .font(.headline)

                Button {
                    showingImagePicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let imageData = selectedImageData,
                   let image = UIImage(data: imageData) {
                    VStack {
                        Text("Selected Image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Attach to Prompt") {
                            if let name = selectedImageName {
                                onImageAttached(imageData, name)
                            }
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Attach Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PhotoPicker(selectedData: $selectedImageData, selectedName: $selectedImageName)
            }
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedData: Data?
    @Binding var selectedName: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) else { return }
                let fileName = "image_\(Int(Date().timeIntervalSince1970)).jpg"
                DispatchQueue.main.async {
                    self?.parent.selectedData = data
                    self?.parent.selectedName = fileName
                }
            }
        }
    }
}
