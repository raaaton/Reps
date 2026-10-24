import XCTest

@testable import RepsCore

final class BodyWeightEditingTargetTests: XCTestCase {
  let first = BodyWeightMeasurement(id: "a", dayKey: "2026-10-18", grams: 72_000)
  let second = BodyWeightMeasurement(id: "b", dayKey: "2026-10-19", grams: 73_000)

  func testAddingAfterVisitingOccupiedDateReturnsToBlankNewEntry() {
    let occupied = BodyWeightEditingTarget.resolve(adding: true, current: nil, matching: second)
    XCTAssertEqual(occupied.original, second)
    XCTAssertTrue(occupied.resetsInput)
    let free = BodyWeightEditingTarget.resolve(
      adding: true, current: occupied.original, matching: nil)
    XCTAssertNil(free.original)
    XCTAssertTrue(free.resetsInput)
  }
  func testEditingAfterVisitingOccupiedDateMovesTheDisplayedRecord() {
    let occupied = BodyWeightEditingTarget.resolve(adding: false, current: first, matching: second)
    XCTAssertEqual(occupied.original, second)
    XCTAssertTrue(occupied.resetsInput)
    let free = BodyWeightEditingTarget.resolve(
      adding: false, current: occupied.original, matching: nil)
    XCTAssertEqual(free.original, second)
    XCTAssertFalse(free.resetsInput)
  }
  func testRevisitingSameRecordPreservesDraftAndStaleOriginalForSaveValidation() {
    let changed = BodyWeightMeasurement(id: first.id, dayKey: first.dayKey, grams: 74_000)
    let same = BodyWeightEditingTarget.resolve(adding: false, current: first, matching: changed)
    XCTAssertEqual(same.original, first)
    XCTAssertFalse(same.resetsInput)
  }
  func testInitiallyEmptyEntryAndChangingFreeDatesPreserveBlankOrTypedDraft() {
    let new = BodyWeightEditingTarget.resolve(adding: true, current: nil, matching: nil)
    XCTAssertNil(new.original)
    XCTAssertFalse(new.resetsInput)
  }
}
