import CoreTransferable
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A photo chosen from the library, before it is scaled down for the coach.
struct CoachImageFile: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            CoachImageFile(data: data)
        }
    }
}

/// Scales a photo down, bakes in its orientation, and writes a JPEG without
/// the original metadata. The model session scales again; this keeps the
/// file, and the token cost, bounded.
enum CoachPhotoPrep {
    static let maxLongEdge = 1280

    static func jpegData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
    }
}

/// The system camera. The chat presents it and keeps the JPEG. Dismissal is
/// the cover's binding, so this view does not dismiss itself.
struct CoachCameraPicker: UIViewControllerRepresentable {
    var onImageData: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageData: onImageData, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageData: (Data) -> Void
        let onCancel: () -> Void

        init(onImageData: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onImageData = onImageData
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                onCancel()
                return
            }
            onImageData(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
