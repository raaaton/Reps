import Foundation
import RepsCore
import XCTest

final class VaultPhotoRegistrationTests: XCTestCase {
  func testOldMetadataHasNoAlignment() throws {
    let data = Data(#"{"dayKey":"2026-11-01","type":"public.jpeg","pose":"back"}"#.utf8)
    XCTAssertNil(try JSONDecoder().decode(VaultPhotoMetadata.self, from: data).alignment)
  }

  func testRegistrationSurvivesMetadataEditingAndCoding() throws {
    let crop = VaultAlignmentRect(x: 0.05, y: 0.03, width: 0.9, height: 0.94)
    let alignment = VaultPhotoRegistration(referenceID: "reference", referenceCrop: crop)
    var metadata = VaultPhotoMetadata(dayKey: "2026-11-06", type: "public.jpeg", pose: .back)
    metadata.alignment = alignment
    metadata.dayKey = "2026-11-07"
    let decoded = try JSONDecoder().decode(
      VaultPhotoMetadata.self, from: JSONEncoder().encode(metadata))
    XCTAssertEqual(decoded.alignment, alignment)
    XCTAssertEqual(decoded.dayKey, "2026-11-07")
  }
}
