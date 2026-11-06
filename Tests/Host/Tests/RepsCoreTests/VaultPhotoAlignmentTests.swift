import Foundation
import XCTest

@testable import RepsCore

final class VaultPhotoAlignmentTests: XCTestCase {
  func testIdentityAndBrightnessChangeAreReliable() {
    let result = VaultPhotoAlignment.register(
      reference: outline(), moving: outline(foreground: 160, background: 55))
    XCTAssertTrue(result.isReliable)
    XCTAssertEqual(result.transform.scale, 1, accuracy: 0.025)
    XCTAssertEqual(result.transform.rotationRadians, 0, accuracy: 0.025)
    XCTAssertTrue(VaultPhotoAlignment.evaluate(reference: outline(), moving: outline()).isReliable)
  }

  func testRecoversTranslationRotationAndUniformScale() {
    let result = VaultPhotoAlignment.register(
      reference: outline(),
      moving: outline(
        angle: 5 * .pi / 180, scale: 1.08, dx: 0.06, dy: -0.04))
    XCTAssertTrue(result.isReliable)
    XCTAssertEqual(result.transform.rotationRadians, -5 * .pi / 180, accuracy: 0.025)
    XCTAssertEqual(result.transform.scale, 1 / 1.08, accuracy: 0.035)
    XCTAssertEqual(result.transform.translationX, -0.06, accuracy: 0.025)
    XCTAssertEqual(result.transform.translationY, 0.04, accuracy: 0.025)
    XCTAssertFalse(
      VaultPhotoAlignment.evaluate(reference: outline(), moving: outline(dx: 0.08)).isReliable)
  }

  func testRejectsBlankUnrelatedAndInvalidImages() {
    let blank = VaultAlignmentImage(
      width: 72, height: 96, pixels: Array(repeating: 120, count: 72 * 96))
    XCTAssertFalse(VaultPhotoAlignment.register(reference: blank, moving: blank).isReliable)
    XCTAssertNil(VaultPhotoAlignment.register(reference: outline(), moving: blank).commonCrop)
    let stripes = VaultAlignmentImage(
      width: 72, height: 96,
      pixels: (0..<(72 * 96)).map { ($0 % 72) % 12 < 6 ? 220 : 25 })
    XCTAssertFalse(VaultPhotoAlignment.register(reference: outline(), moving: stripes).isReliable)
    XCTAssertFalse(
      VaultPhotoAlignment.register(
        reference: outline(),
        moving:
          VaultAlignmentImage(width: 0, height: 0, pixels: [])
      ).isReliable)
  }

  func testOppositeRotationAndScaleRecoverWithoutLiveFalsePositive() {
    let moving = outline(angle: -6 * .pi / 180, scale: 0.91, dx: -0.07, dy: 0.05)
    let result = VaultPhotoAlignment.register(reference: outline(), moving: moving)
    XCTAssertTrue(result.isReliable)
    XCTAssertEqual(result.transform.rotationRadians, 6 * .pi / 180, accuracy: 0.025)
    XCTAssertEqual(result.transform.scale, 1 / 0.91, accuracy: 0.035)
    XCTAssertFalse(VaultPhotoAlignment.evaluate(reference: outline(), moving: moving).isReliable)
  }

  func testUnrelatedSilhouetteAndOutOfBoundsCaptureAreRejected() {
    let triangle = VaultAlignmentImage(
      width: 72, height: 96,
      pixels: (0..<(72 * 96)).map { index in
        let x = Double(index % 72) / 72
        let y = Double(index / 72) / 96
        return y > 0.15 && y < 0.85 && abs(x - 0.5) < (y - 0.15) * 0.45 ? 230 : 20
      })
    XCTAssertFalse(VaultPhotoAlignment.register(reference: outline(), moving: triangle).isReliable)
    XCTAssertFalse(
      VaultPhotoAlignment.register(reference: outline(), moving: outline(dx: 0.3)).isReliable)
  }

  func testMatchingRoomContoursDoNotHideShiftedCentralSubject() {
    func room(subjectShift: Int) -> VaultAlignmentImage {
      var pixels = [UInt8](repeating: 0, count: 72 * 96)
      for x in [8, 20, 50, 62] {
        for y in 5..<91 {
          pixels[y * 72 + x] = 255
          pixels[y * 72 + x + 1] = 255
        }
      }
      for y in 20..<78 {
        for x in (28 + subjectShift)..<(43 + subjectShift) { pixels[y * 72 + x] = 255 }
      }
      return VaultAlignmentImage(width: 72, height: 96, pixels: pixels)
    }
    XCTAssertTrue(
      VaultPhotoAlignment.evaluate(reference: room(subjectShift: 0), moving: room(subjectShift: 0))
        .isReliable)
    XCTAssertFalse(
      VaultPhotoAlignment.register(reference: room(subjectShift: 0), moving: room(subjectShift: 12))
        .isReliable)
    for shift in [4, 8, 12] {
      XCTAssertFalse(
        VaultPhotoAlignment.evaluate(
          reference: room(subjectShift: 0), moving: room(subjectShift: shift)
        ).isReliable,
        "Matching background must not conceal displaced body at shift \(shift)")
    }
  }

  func testCommonCropContainsOnlyCoveredPixelsAndTransformHasUniformScale() throws {
    let transform = VaultAlignmentTransform(
      rotationRadians: 0.12, scale: 0.88,
      translationX: 0.09, translationY: -0.08)
    let crop = try XCTUnwrap(VaultPhotoAlignment.commonCrop(for: transform, aspectRatio: 0.75))
    for y in [crop.y, crop.y + crop.height] {
      for x in [crop.x, crop.x + crop.width] {
        let u = (x - 0.5 - transform.translationX) * 0.75
        let v = y - 0.5 - transform.translationY
        let sourceX = 0.5 + (u * cos(0.12) + v * sin(0.12)) / 0.88 / 0.75
        let sourceY = 0.5 + (-u * sin(0.12) + v * cos(0.12)) / 0.88
        XCTAssertGreaterThanOrEqual(sourceX, -0.00001)
        XCTAssertLessThanOrEqual(sourceX, 1.00001)
        XCTAssertGreaterThanOrEqual(sourceY, -0.00001)
        XCTAssertLessThanOrEqual(sourceY, 1.00001)
        XCTAssertTrue((0...1).contains(x) && (0...1).contains(y))
      }
    }
    let center = transform.applying(x: 0.5, y: 0.5, aspectRatio: 0.75)
    let right = transform.applying(x: 0.7, y: 0.5, aspectRatio: 0.75)
    let down = transform.applying(x: 0.5, y: 0.65, aspectRatio: 0.75)
    XCTAssertEqual(
      hypot((right.x - center.x) * 0.75, right.y - center.y),
      hypot((down.x - center.x) * 0.75, down.y - center.y), accuracy: 0.000001)
  }

  private func outline(
    angle: Double = 0, scale: Double = 1, dx: Double = 0,
    dy: Double = 0, foreground: UInt8 = 230, background: UInt8 = 20
  ) -> VaultAlignmentImage {
    let width = 72
    let height = 96
    let pixels: [UInt8] = (0..<(width * height)).map { index in
      let x = (Double(index % width) + 0.5) / Double(width) - 0.5 - dx
      let y = (Double(index / width) + 0.5) / Double(height) - 0.5 - dy
      let u = (x * 0.75 * cos(angle) + y * sin(angle)) / scale / 0.75 + 0.5
      let v = (-x * 0.75 * sin(angle) + y * cos(angle)) / scale + 0.5
      let head = pow((u - 0.49) / 0.09, 2) + pow((v - 0.18) / 0.07, 2) < 1
      let trunk = v > 0.27 && v < 0.57 && abs(u - 0.5) < 0.13 - (v - 0.27) * 0.12
      let arms = v > 0.3 && v < 0.58 && (abs(u - 0.27) < 0.04 || abs(u - 0.73) < 0.04)
      let legs = v > 0.56 && v < 0.83 && (abs(u - 0.43) < 0.045 || abs(u - 0.58) < 0.045)
      let foot = v > 0.8 && v < 0.86 && u > 0.53 && u < 0.7
      return head || trunk || arms || legs || foot ? foreground : background
    }
    return VaultAlignmentImage(width: width, height: height, pixels: pixels)
  }
}
