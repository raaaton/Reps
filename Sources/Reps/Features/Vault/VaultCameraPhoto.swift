import Foundation
import RepsCore
import UIKit

// Normalize EXIF orientation and crop to exactly the preview's aspect ratio in memory.
// The stencil is never a rendering input, so it cannot appear in saved bytes.
enum VaultCameraPhoto {
  static func prepare(_ bytes: Data, aspect: Double) throws -> Data {
    _ = try VaultCryptography.imageSource(bytes)
    guard let image = UIImage(data: bytes),
      let frame = VaultPhotoFrame.crop(
        width: Int(image.size.width), height: Int(image.size.height), aspect: aspect)
    else { throw VaultMediaError.captureFailed }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    let result = UIGraphicsImageRenderer(
      size: CGSize(width: frame.width, height: frame.height), format: format
    ).jpegData(withCompressionQuality: 0.95) { _ in
      image.draw(
        in: CGRect(
          x: -frame.x, y: -frame.y, width: Int(image.size.width), height: Int(image.size.height)))
    }
    _ = try VaultCryptography.imageSource(result)
    return result
  }
}
