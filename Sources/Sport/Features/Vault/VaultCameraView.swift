import AVFoundation
import Foundation
import SwiftUI
import UIKit

// Native camera UI; no automatic save to Photos and no app-authored plaintext file.
struct VaultCameraView: UIViewControllerRepresentable {
  let completion: @MainActor (Data?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.mediaTypes = ["public.image"]
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
  @MainActor
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
  {
    let completion: @MainActor (Data?) -> Void
    init(completion: @escaping @MainActor (Data?) -> Void) { self.completion = completion }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      let data = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.95)
      // Clean only a camera-generated temporary file inside Sport's own tmp directory.
      if let url = info[.imageURL] as? URL {
        let owned =
          URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.resolvingSymlinksInPath()
          .path + "/"
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        if file.path.hasPrefix(owned) {
          do {
            try FileManager.default.setAttributes(
              [.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
            try FileManager.default.removeItem(at: file)
          } catch {
            completion(nil)
            return
          }
        }
      }
      completion(data)
    }
  }
}
