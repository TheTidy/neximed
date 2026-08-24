// Neximed — ShareSheet.swift
// Wrapper de UIActivityViewController para compartir el Dossier PDF

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
