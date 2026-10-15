import XCTest

@testable import SportCore

final class AccentColorTests: XCTestCase {
  func testOnlyFixedIcyCyanRemains() {
    XCTAssertEqual(AccentChoice.allCases, [.icyCyan])
    XCTAssertEqual(AccentChoice.resolve(nil), .icyCyan)
    XCTAssertEqual(AccentChoice.resolve("mint"), .icyCyan)
    XCTAssertEqual(AccentChoice.icyCyan.rgb, AccentRGB(hex: 0x4DD9E8))
  }

  func testCustomColorsRemainReadableOnLightDarkAndElevatedSurfaces() throws {
    for choice in AccentChoice.allCases {
      let base = try XCTUnwrap(choice.rgb)
      XCTAssertGreaterThanOrEqual(base.contrast(with: base.ink), 4.5)
      for hex: UInt32 in [0xFFFFFF, 0xF2F2F7, 0x000000, 0x1C1C1E, 0x38383A] {
        let background = AccentRGB(hex: hex)
        for target in [4.5, 7.0] {
          let adjusted = base.readable(on: background, target: target)
          XCTAssertGreaterThanOrEqual(adjusted.contrast(with: background), target)
          for component in [adjusted.red, adjusted.green, adjusted.blue] {
            XCTAssertTrue((0...1).contains(component))
          }
        }
      }
    }
  }

  func testLuminanceAndContrastReferenceValues() {
    XCTAssertEqual(AccentRGB(hex: 0xFFFFFF).luminance, 1, accuracy: 0.000001)
    XCTAssertEqual(AccentRGB(hex: 0x000000).luminance, 0)
    XCTAssertEqual(AccentRGB(hex: 0xFF0000).luminance, 0.2126, accuracy: 0.000001)
    XCTAssertEqual(
      AccentRGB(hex: 0x000000).contrast(with: AccentRGB(hex: 0xFFFFFF)), 21, accuracy: 0.000001)
  }
}
