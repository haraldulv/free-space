import SwiftUI
import UIKit

/// UIImagePickerController-wrapper som lar brukeren velge bilde fra fotobiblioteket
/// OG beskjære det til en kvadrat. Brukes f.eks. til avatar-opplasting.
struct ImageCropPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true  // gir innebygd kvadrat-crop
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropPicker

        init(_ parent: ImageCropPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Bruker editedImage (den beskjærte) hvis tilgjengelig, ellers originalImage
            if let edited = info[.editedImage] as? UIImage {
                parent.onImagePicked(edited)
            } else if let original = info[.originalImage] as? UIImage {
                parent.onImagePicked(original)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
