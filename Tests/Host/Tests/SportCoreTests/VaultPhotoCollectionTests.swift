import Foundation
import XCTest

@testable import SportCore

final class VaultPhotoCollectionTests: XCTestCase {
  private func photo(_ id: String, _ day: String, _ pose: VaultPhotoPose?) -> VaultPhotoEntry {
    VaultPhotoEntry(
      id: id, metadata: VaultPhotoMetadata(dayKey: day, type: "public.heic", pose: pose))
  }
  func testLegacyMetadataKeepsDateAndTypeWithoutInventingPose() throws {
    let bytes = Data(#"{"dayKey":"2026-10-01","type":"public.heic"}"#.utf8)
    let old = try JSONDecoder().decode(VaultPhotoMetadata.self, from: bytes)
    XCTAssertEqual(old.dayKey, "2026-10-01")
    XCTAssertEqual(old.type, "public.heic")
    XCTAssertNil(old.pose)
    var edited = old
    edited.pose = .frontFlexed
    let restored = try JSONDecoder().decode(
      VaultPhotoMetadata.self, from: JSONEncoder().encode(edited))
    XCTAssertEqual(restored, edited)
    XCTAssertEqual(restored.type, old.type)
  }
  func testOtherPoseDecodesAndRoundTripsWithoutChangingLegacyMetadata() throws {
    let bytes = Data(#"{"dayKey":"2026-10-01","type":"public.heic","pose":"other"}"#.utf8)
    let metadata = try JSONDecoder().decode(VaultPhotoMetadata.self, from: bytes)
    XCTAssertEqual(metadata.pose?.rawValue, "other")
    XCTAssertEqual(
      try JSONDecoder().decode(VaultPhotoMetadata.self, from: JSONEncoder().encode(metadata)),
      metadata)
  }
  func testOtherPoseSortsBeforeUnassignedAndComparesOnlySameTypeAcrossDates() {
    let other = photo("z", "2026-10-01", .other)
    let oldOther = photo("old", "2026-09-01", .other)
    let unassigned = photo("a", "2026-10-01", nil)
    let front = photo("f", "2026-10-01", .frontRelaxed)
    let entries = [unassigned, other, oldOther, front]
    XCTAssertEqual(VaultPhotoCollection.days(entries).first?.photos.map(\.id), ["f", "z", "a"])
    XCTAssertEqual(VaultPhotoCollection.candidates(entries, pose: .other).map(\.id), ["old", "z"])
    XCTAssertTrue(VaultPhotoCollection.canCompare(oldOther, other))
    XCTAssertFalse(VaultPhotoCollection.canCompare(front, other))
    XCTAssertFalse(VaultPhotoCollection.canCompare(unassigned, other))
    XCTAssertFalse(VaultPhotoCollection.canCompare(other, photo("copy", "2026-10-01", .other)))
  }
  func testDaysGroupWithoutDiscardingDuplicatesOrUnclassifiedPhotos() {
    let photos = [
      photo("a", "2026-09-01", .back), photo("b", "2026-10-01", .frontRelaxed),
      photo("c", "2026-09-01", .back), photo("d", "2026-10-01", nil),
    ]
    let days = VaultPhotoCollection.days(photos)
    XCTAssertEqual(days.map(\.id), ["2026-10-01", "2026-09-01"])
    XCTAssertEqual(Set(days.flatMap(\.photos).map(\.id)), Set(photos.map(\.id)))
    XCTAssertEqual(days.first?.photos.map(\.id), ["b", "d"])
  }
  func testComparisonFiltersPoseAndRequiresTwoDifferentDates() {
    let older = photo("a", "2026-09-01", .frontFlexed)
    let newer = photo("b", "2026-10-01", .frontFlexed)
    let duplicate = photo("c", "2026-10-01", .frontFlexed)
    let otherPose = photo("d", "2026-10-01", .back)
    let unclassified = photo("e", "2026-08-01", nil)
    let candidates = VaultPhotoCollection.candidates(
      [newer, otherPose, older, duplicate, unclassified], pose: .frontFlexed)
    XCTAssertEqual(candidates.map(\.id), ["a", "b", "c"])
    XCTAssertTrue(VaultPhotoCollection.canCompare(older, newer))
    XCTAssertFalse(VaultPhotoCollection.canCompare(newer, duplicate))
    XCTAssertFalse(VaultPhotoCollection.canCompare(older, otherPose))
    XCTAssertFalse(VaultPhotoCollection.canCompare(older, older))
    XCTAssertFalse(VaultPhotoCollection.canCompare(unclassified, photo("f", "2026-09-01", nil)))
  }
}
