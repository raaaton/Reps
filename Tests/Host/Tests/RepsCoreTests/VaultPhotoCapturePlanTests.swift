import XCTest

@testable import RepsCore

final class VaultPhotoCapturePlanTests: XCTestCase {
  private func photo(_ id: String, _ day: String, _ pose: VaultPhotoPose?) -> VaultPhotoEntry {
    VaultPhotoEntry(
      id: id, metadata: VaultPhotoMetadata(dayKey: day, type: "public.jpeg", pose: pose))
  }
  func testSessionUsesOnlyPhotosAndReferencesInLatestDailyFolder() {
    let plan = VaultPhotoCapturePlan.latestSession([
      photo("old-front", "2026-10-30", .frontRelaxed),
      photo("back", "2026-11-01", .back),
      photo("other", "2026-11-01", .other),
      photo("old-flexed", "2026-10-30", .frontFlexed),
    ])
    XCTAssertEqual(plan?.referenceDay, "2026-11-01")
    XCTAssertEqual(plan?.steps.map(\.pose), [.back, .other])
    XCTAssertEqual(plan?.steps.map { $0.reference?.id }, ["back", "other"])
  }
  func testEveryPhotoCreatesItsOwnStepIncludingRepeatedAndUnassignedPoses() {
    let plan = VaultPhotoCapturePlan.latestSession([
      photo("a", "2026-11-01", .back), photo("front", "2026-11-01", .frontRelaxed),
      photo("z", "2026-11-01", .back), photo("unknown", "2026-11-01", nil),
    ])
    XCTAssertEqual(
      plan?.steps.map { $0.reference?.metadata.pose }, [.frontRelaxed, .back, .back, nil])
    XCTAssertEqual(plan?.steps.map { $0.reference?.id }, ["front", "a", "z", "unknown"])
    XCTAssertEqual(Set(plan?.steps.map(\.id) ?? []).count, 4)
  }
  func testUnassignedLatestFolderIsRepeatedWithoutInventingPoseOrUsingOlderPhotos() {
    let plan = VaultPhotoCapturePlan.latestSession([
      photo("old", "2026-10-30", .back), photo("unknown", "2026-11-01", nil),
    ])
    XCTAssertEqual(plan?.steps.map { $0.reference?.id }, ["unknown"])
    XCTAssertNil(plan?.steps.first?.pose)
    XCTAssertNil(VaultPhotoCapturePlan.latestSession([]))
  }
  func testSinglePoseUsesMostRecentMatchingDayWithoutOtherPoseFallback() {
    let plan = VaultPhotoCapturePlan.single(
      pose: .back,
      photos: [
        photo("old", "2026-10-30", .back), photo("new", "2026-11-01", .back),
        photo("today-front", "2026-11-02", .frontRelaxed),
      ])
    XCTAssertEqual(plan.steps.map(\.pose), [.back])
    XCTAssertEqual(plan.steps.first?.reference?.id, "new")
    let empty = VaultPhotoCapturePlan.single(pose: .other, photos: [])
    XCTAssertNil(empty.steps.first?.reference)
    XCTAssertEqual(empty.steps.map(\.pose), [.other])
  }
  func testCapturedPhotosCannotChangeFrozenReferencesOrSteps() {
    var photos = [photo("reference", "2026-11-01", .back)]
    let plan = VaultPhotoCapturePlan.latestSession(photos)
    photos.append(photo("new", "2026-11-02", .frontFlexed))
    photos.append(photo("new-back", "2026-11-02", .back))
    XCTAssertEqual(plan?.steps.map(\.pose), [.back])
    XCTAssertEqual(plan?.steps.first?.reference?.id, "reference")
    XCTAssertEqual(plan?.referenceDay, "2026-11-01")
  }
}

final class VaultPhotoFrameTests: XCTestCase {
  func testPortraitAndLandscapeReferencesCropCaptureAtCenterWithoutStretching() {
    XCTAssertEqual(
      VaultPhotoFrame.crop(width: 120, height: 160, aspect: 0.75),
      VaultPhotoFrame(x: 0, y: 0, width: 120, height: 160))
    XCTAssertEqual(
      VaultPhotoFrame.crop(width: 120, height: 160, aspect: 1),
      VaultPhotoFrame(x: 0, y: 20, width: 120, height: 120))
    XCTAssertEqual(
      VaultPhotoFrame.crop(width: 120, height: 160, aspect: 0.5),
      VaultPhotoFrame(x: 20, y: 0, width: 80, height: 160))
    XCTAssertEqual(
      VaultPhotoFrame.crop(width: 120, height: 160, aspect: 2),
      VaultPhotoFrame(x: 0, y: 50, width: 120, height: 60))
  }
  func testInvalidDimensionsAndRatiosAreRejectedBeforeAllocatingImage() {
    XCTAssertNil(VaultPhotoFrame.crop(width: 0, height: 160, aspect: 1))
    XCTAssertNil(VaultPhotoFrame.crop(width: 120, height: 160, aspect: .nan))
    XCTAssertNil(VaultPhotoFrame.crop(width: 120, height: 160, aspect: .infinity))
    XCTAssertNil(VaultPhotoFrame.crop(width: 120, height: 160, aspect: -1))
  }
}
