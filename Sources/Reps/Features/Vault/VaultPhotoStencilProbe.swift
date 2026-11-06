#if DEBUG
  import CryptoKit
  import Foundation
  import ImageIO
  import RepsCore
  import UIKit
  import UniformTypeIdentifiers

  // Fixed, generated pixels and temporary keys only; never starts the camera or opens a vault.
  @MainActor
  enum VaultPhotoStencilProbe {
    static func run() throws -> String {
      try VaultCameraAlignmentProbe.run()
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let source = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 16), format: format)
        .jpegData(withCompressionQuality: 0.95) { context in
          UIColor.red.setFill()
          context.fill(CGRect(x: 0, y: 0, width: 12, height: 8))
          UIColor.blue.setFill()
          context.fill(CGRect(x: 0, y: 8, width: 12, height: 8))
        }
      VaultVideoProbe.step = "stencil centered crop"
      let square = try VaultCameraPhoto.prepare(source, aspect: 1)
      guard let image = UIImage(data: square), image.size == CGSize(width: 12, height: 12),
        image.imageOrientation == .up
      else { throw VaultMediaError.captureFailed }
      guard let raw = UIImage(data: source)?.cgImage else { throw VaultMediaError.captureFailed }
      let rotated = NSMutableData()
      guard
        let writer = CGImageDestinationCreateWithData(
          rotated, UTType.jpeg.identifier as CFString, 1, nil)
      else { throw VaultMediaError.captureFailed }
      CGImageDestinationAddImage(writer, raw, [kCGImagePropertyOrientation: 6] as CFDictionary)
      guard CGImageDestinationFinalize(writer) else { throw VaultMediaError.captureFailed }
      VaultVideoProbe.step = "stencil EXIF rotation normalization"
      let normalized = try VaultCameraPhoto.prepare(rotated as Data, aspect: 4.0 / 3.0)
      guard let turned = UIImage(data: normalized), turned.size == CGSize(width: 16, height: 12),
        turned.imageOrientation == .up
      else { throw VaultMediaError.captureFailed }
      VaultVideoProbe.step = "stencil encrypted metadata and image round-trip"
      let key = SymmetricKey(size: .bits256)
      let keyID = UUID().uuidString
      var photos: [VaultPhotoEntry] = []
      let alignment = VaultPhotoRegistration(
        referenceID: "generated-reference",
        referenceCrop: VaultAlignmentRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9))
      for pose: VaultPhotoPose? in [.back, .back, nil] {
        let record = try VaultCryptography.prepare(
          square, day: "2026-11-02", pose: pose, key: key, keyID: keyID, alignment: alignment)
        let metadata = try JSONDecoder().decode(
          VaultPhotoMetadata.self,
          from:
            VaultCryptography.open(
              record.metadata, key: key, keyID: keyID, id: record.id, role: "metadata"))
        guard metadata.pose == pose, metadata.alignment == alignment,
          try VaultCryptography.open(
            record.original, key: key, keyID: keyID, id: record.id, role: "original") == square
        else { throw VaultFailure.damaged }
        photos.append(VaultPhotoEntry(id: record.id, metadata: metadata))
      }
      VaultVideoProbe.step = "stencil repeated and unassigned photo steps"
      let plan = VaultPhotoCapturePlan.latestSession(photos)
      guard plan?.steps.count == 3, Set(plan?.steps.map(\.id) ?? []).count == 3,
        plan?.steps.filter({ $0.pose == .back }).count == 2,
        plan?.steps.filter({ $0.pose == nil }).count == 1
      else { throw VaultFailure.damaged }
      return
        "PASS stencil: native similarity registration and shared crop, top-left grayscale, flat-image rejection, centered crop, EXIF normalization, encrypted metadata round-trip and per-photo steps; generated pixels only, no camera or personal vault access."
    }
  }
#endif
