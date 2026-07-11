import PhotosUI
import SwiftUI

/// Multi-select photo picker. `PHPickerViewController` runs out-of-process and
/// needs **no** photo-library permission (§10.4), so there's no priming screen
/// or usage-string dependency here.
struct PhotoPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: ([UIImage]) -> Void

        init(onPicked: @escaping ([UIImage]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            let providers = results.map(\.itemProvider).filter { $0.canLoadObject(ofClass: UIImage.self) }
            guard !providers.isEmpty else {
                onPicked([])
                return
            }

            Task {
                var images: [UIImage] = []
                for provider in providers {
                    if let image = try? await Self.loadImage(from: provider) {
                        images.append(image)
                    }
                }
                await MainActor.run { self.onPicked(images) }
            }
        }

        private static func loadImage(from provider: NSItemProvider) async throws -> UIImage? {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: object as? UIImage)
                    }
                }
            }
        }
    }
}
