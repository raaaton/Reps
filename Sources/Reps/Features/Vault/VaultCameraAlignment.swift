import CoreGraphics
import Foundation
import RepsCore
import UIKit

// All coordinates are top-left. Only similarity transforms reach the renderer;
// pixels outside the shared valid rectangle never enter the saved image.
enum VaultCameraAlignment {
  struct Prepared: Sendable {
    let bytes: Data
    let crop: VaultAlignmentRect
  }

  static func grayscale(_ image: CGImage, aspect: Double) throws -> VaultAlignmentImage {
    guard let crop = VaultPhotoFrame.crop(width: image.width, height: image.height, aspect: aspect),
      let source = image.cropping(
        to: CGRect(
          x: crop.x, y: crop.y, width: crop.width, height: crop.height))
    else { throw VaultMediaError.captureFailed }
    let factor = 96.0 / Double(max(source.width, source.height))
    let width = max(8, Int((Double(source.width) * factor).rounded()))
    let height = max(8, Int((Double(source.height) * factor).rounded()))
    var pixels = [UInt8](repeating: 0, count: width * height)
    let valid = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
      else { return false }
      context.interpolationQuality = .medium
      // Bitmap CGImage rows already use the top-left pixel order expected by
      // registration. A UIKit-style CTM flip here would invert rotation/translation.
      context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard valid else { throw VaultMediaError.captureFailed }
    return VaultAlignmentImage(width: width, height: height, pixels: pixels)
  }

  static func prepare(_ bytes: Data, reference: CGImage) throws -> Prepared? {
    guard let moving = UIImage(data: bytes)?.cgImage else { throw VaultMediaError.captureFailed }
    let aspect = Double(reference.width) / Double(reference.height)
    let result = VaultPhotoAlignment.register(
      reference: try grayscale(reference, aspect: aspect),
      moving: try grayscale(moving, aspect: aspect))
    guard !Task.isCancelled, result.isReliable, let crop = result.commonCrop else { return nil }
    let width = Double(moving.width)
    let height = Double(moving.height)
    let x = ceil(crop.x * width)
    let y = ceil(crop.y * height)
    let endX = floor((crop.x + crop.width) * width)
    let endY = floor((crop.y + crop.height) * height)
    guard endX > x, endY > y else { return nil }
    // Store the exact pixel-rounded normalized crop used by both images.
    let actual = VaultAlignmentRect(
      x: x / width, y: y / height, width: (endX - x) / width, height: (endY - y) / height)
    let transform = result.transform
    let c = cos(transform.rotationRadians) * transform.scale
    let s = sin(transform.rotationRadians) * transform.scale
    let affine = CGAffineTransform(
      a: c, b: s, c: -s, d: c,
      tx: (1 - c) * width / 2 + s * height / 2 + transform.translationX * width,
      ty: (1 - c) * height / 2 - s * width / 2 + transform.translationY * height)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    let aligned = UIGraphicsImageRenderer(
      size: CGSize(width: endX - x, height: endY - y), format: format
    ).jpegData(withCompressionQuality: 0.95) { context in
      context.cgContext.translateBy(x: -x, y: -y)
      context.cgContext.concatenate(affine)
      UIImage(cgImage: moving).draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    _ = try VaultCryptography.imageSource(aligned)
    return Prepared(bytes: aligned, crop: actual)
  }

  static func cropReference(_ image: UIImage, crop: VaultAlignmentRect) throws -> UIImage {
    guard let source = image.cgImage,
      [crop.x, crop.y, crop.width, crop.height].allSatisfy(\.isFinite),
      crop.x >= 0, crop.y >= 0, crop.width > 0, crop.height > 0,
      crop.x + crop.width <= 1.000001, crop.y + crop.height <= 1.000001,
      let result = source.cropping(
        to: CGRect(
          x: crop.x * Double(source.width), y: crop.y * Double(source.height),
          width: crop.width * Double(source.width), height: crop.height * Double(source.height)))
    else { throw VaultMediaError.captureFailed }
    return UIImage(cgImage: result)
  }
}
