import Foundation
import XCTest

@testable import SportCore

final class BodyWeightRepositoryTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_892_800_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func measurement(_ grams: Int = 72_400, day: String = "2026-10-13", id: String = "weight")
    -> BodyWeightMeasurement
  {
    BodyWeightMeasurement(id: id, dayKey: day, grams: grams)
  }
  func testDecimalInputPreservesGramsAndRejectsInvalidData() throws {
    for (text, grams) in [
      ("72", 72000), ("72.4", 72400), ("72,45", 72450), (" 72,456 ", 72456), ("0.001", 1),
    ] {
      XCTAssertEqual(try BodyWeightInput.grams(from: text), grams)
    }
    for text in [
      "", "0", "-1", "NaN", "1e2", "72.1234", "1,2.3", "1 000", "999999999999999999999999",
    ] {
      XCTAssertThrowsError(try BodyWeightInput.grams(from: text), text)
    }
  }
  func testSaveReopenEditAndDelete() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let first = measurement()
    try await r.saveBodyWeight(first, original: nil, now: now, calendar: calendar)
    let reopened = try SportRepository(path: path)
    var records = try await reopened.bodyWeightMeasurements()
    XCTAssertEqual(records, [first])
    let changed = measurement(72_100)
    try await reopened.saveBodyWeight(changed, original: first, now: now, calendar: calendar)
    records = try await reopened.bodyWeightMeasurements()
    XCTAssertEqual(records, [changed])
    do {
      try await r.deleteBodyWeight(first)
      XCTFail("Deleted changed value")
    } catch {}
    try await reopened.deleteBodyWeight(changed)
    records = try await r.bodyWeightMeasurements()
    XCTAssertTrue(records.isEmpty)
  }
  func testSameDayCollisionFutureAndStaleEditsLeaveDataUnchanged() async throws {
    let r = try SportRepository(path: ":memory:")
    let first = measurement()
    try await r.saveBodyWeight(first, original: nil, now: now, calendar: calendar)
    for invalid in [
      measurement(73000, id: "duplicate"), measurement(0, id: "zero"),
      measurement(-1, id: "negative"), measurement(day: "2026-10-14", id: "future"),
      measurement(day: "2026-02-30", id: "bad-date"),
    ] {
      do {
        try await r.saveBodyWeight(invalid, original: nil, now: now, calendar: calendar)
        XCTFail("Accepted invalid")
      } catch {}
    }
    let changed = measurement(73000)
    try await r.saveBodyWeight(changed, original: first, now: now, calendar: calendar)
    do {
      try await r.saveBodyWeight(measurement(74000), original: first, now: now, calendar: calendar)
      XCTFail("Stale edit accepted")
    } catch {}
    let records = try await r.bodyWeightMeasurements()
    XCTAssertEqual(records, [changed])
  }
  func testDateChangeCollisionDoesNotReplaceAnotherMeasurement() async throws {
    let r = try SportRepository(path: ":memory:")
    let first = measurement()
    let second = measurement(73000, day: "2026-10-12", id: "second")
    try await r.saveBodyWeight(first, original: nil, now: now, calendar: calendar)
    try await r.saveBodyWeight(second, original: nil, now: now, calendar: calendar)
    do {
      try await r.saveBodyWeight(
        measurement(day: second.dayKey), original: first, now: now, calendar: calendar)
      XCTFail("Date collision accepted")
    } catch {}
    let records = try await r.bodyWeightMeasurements()
    XCTAssertEqual(records, [second, first])
  }
}
