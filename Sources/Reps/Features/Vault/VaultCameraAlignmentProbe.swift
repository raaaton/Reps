#if DEBUG
  import Foundation
  import RepsCore
  import UIKit

  // Generated geometry only. Exercises the actual CoreGraphics pixel adapters and
  // JPEG renderer, never the live camera, Photos or the owner's vault.
  @MainActor
  enum VaultCameraAlignmentProbe {
    static func run() throws {
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      let size = CGSize(width: 192, height: 256)
      let reference = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        UIColor.white.setFill()
        context.fill(CGRect(x: 4, y: 4, width: 10, height: 10))
        context.fill(CGRect(x: 60, y: 70, width: 72, height: 88))
        context.fill(CGRect(x: 52, y: 142, width: 28, height: 85))
        context.fill(CGRect(x: 109, y: 142, width: 31, height: 74))
        context.fill(CGRect(x: 28, y: 80, width: 26, height: 68))
        context.fill(CGRect(x: 139, y: 81, width: 23, height: 80))
        context.cgContext.fillEllipse(in: CGRect(x: 75, y: 24, width: 43, height: 38))
        UIColor.gray.setFill()
        context.fill(CGRect(x: 89, y: 88, width: 14, height: 29))
      }
      guard let raw = reference.cgImage else { throw VaultMediaError.captureFailed }
      VaultVideoProbe.step = "alignment top-left grayscale coordinates"
      let grid = try VaultCameraAlignment.grayscale(raw, aspect: 0.75)
      // A white square exists in the top left only; vertical flips reverse the transform.
      guard grid.pixels[2 * grid.width + 2] > 180,
        grid.pixels[(grid.height - 3) * grid.width + 2] < 30
      else { throw VaultMediaError.captureFailed }
      let moving = UIGraphicsImageRenderer(size: size, format: format).jpegData(
        withCompressionQuality: 0.95
      ) { context in
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        context.cgContext.translateBy(x: size.width / 2 + 7, y: size.height / 2 - 6)
        context.cgContext.rotate(by: 0.045)
        context.cgContext.scaleBy(x: 1.04, y: 1.04)
        reference.draw(
          in: CGRect(
            x: -size.width / 2, y: -size.height / 2,
            width: size.width, height: size.height))
      }
      VaultVideoProbe.step = "alignment native translation rotation scale and shared crop"
      guard let aligned = try VaultCameraAlignment.prepare(moving, reference: raw),
        let alignedImage = UIImage(data: aligned.bytes)?.cgImage,
        let matchingReference = try VaultCameraAlignment.cropReference(
          reference, crop: aligned.crop
        ).cgImage,
        let movingImage = UIImage(data: moving)?.cgImage
      else { throw VaultMediaError.captureFailed }
      let alignedAspect = Double(alignedImage.width) / Double(alignedImage.height)
      let expected = try VaultCameraAlignment.grayscale(matchingReference, aspect: alignedAspect)
      let actual = try VaultCameraAlignment.grayscale(alignedImage, aspect: alignedAspect)
      let before = try VaultCameraAlignment.grayscale(movingImage, aspect: 0.75)
      func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count else { return .infinity }
        return zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count)
      }
      guard difference(expected.pixels, actual.pixels) < 13,
        difference(expected.pixels, actual.pixels) < difference(grid.pixels, before.pixels) * 0.7
      else { throw VaultMediaError.captureFailed }
      VaultVideoProbe.step = "alignment flat-photo rejection"
      let blank = UIGraphicsImageRenderer(size: size, format: format).jpegData(
        withCompressionQuality: 0.95
      ) { context in
        UIColor.black.setFill()
        context.fill(CGRect(origin: .zero, size: size))
      }
      guard try VaultCameraAlignment.prepare(blank, reference: raw) == nil else {
        throw VaultMediaError.captureFailed
      }
    }
  }
#endif
