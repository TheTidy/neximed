// Neximed — CameraPicker.swift
// Captura de foto con la cámara directamente (sin guardar en el carrete).
// Usa UIImagePickerController con sourceType .camera; la imagen se devuelve
// en memoria y se usa al momento (no se guarda en Photos).

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {

    var onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        // NO guardar en el carrete (no tocar photoLibrary): la foto se usa en memoria
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    Color.black.overlay(
        Text("CameraPicker — solo disponible en dispositivo físico")
    )
}