import Foundation
import XCTest

@testable import RepsCore

final class WeightLimitPreferenceTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  func books(_ quantity: Int = 20) -> WeightItem {
    WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: quantity)
  }
  func clear(_ r: RepsRepository) async throws {
    for item in try await r.snapshot().weightItems { try await r.deleteWeightItem(id: item.id) }
  }

  func testSettingPersistsAndChangesCombinationsAndValidationAboveAndBelowTen() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let initial = try await r.snapshot()
    XCTAssertEqual(initial.maximumWeightObjects, 10)
    try await clear(r)
    try await r.saveWeightItem(books())
    try await r.saveMaximumWeightObjects(3)
    var snapshot = try await RepsRepository(path: path).snapshot()
    XCTAssertEqual(snapshot.maximumWeightObjects, 3)
    XCTAssertEqual(
      try WeightInventory.loads(
        items: snapshot.weightItems, maximumObjects: snapshot.maximumWeightObjects
      ).last?.grams, 3300)
    try await r.saveMaximumWeightObjects(20)
    snapshot = try await r.snapshot()
    let all = try WeightInventory.loads(
      items: snapshot.weightItems, maximumObjects: snapshot.maximumWeightObjects)
    let twenty = try XCTUnwrap(all.last)
    XCTAssertEqual(twenty.grams, 5000)
    XCTAssertEqual(twenty.components.last?.quantity, 20)
    XCTAssertTrue(
      WeightInventory.isAvailable(twenty, items: snapshot.weightItems, maximumObjects: 20))
    XCTAssertFalse(
      WeightInventory.isAvailable(twenty, items: snapshot.weightItems, maximumObjects: 3))
  }

  func testInvalidAndOverComplexSettingChangesRollBack() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await clear(r)
    try await r.saveMaximumWeightObjects(1)
    for i in 0..<13 {
      try await r.saveWeightItem(
        WeightItem(id: "p-\(i)", name: "Power", grams: 1 << i, isEnabled: true))
    }
    let before = try await r.snapshot()
    for value in [0, -1, 1001, Int.max, 1000] {
      do {
        try await r.saveMaximumWeightObjects(value)
        XCTFail("Invalid or oversized policy accepted")
      } catch {}
      let after = try await r.snapshot()
      XCTAssertEqual(after, before)
    }
  }

  func testLoweringLimitPreservesPendingAndRecordedSnapshots() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await clear(r)
    try await r.saveWeightItem(books())
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await r.saveSchedule(schedule)
    let w = try await r.startWorkout(scheduleID: schedule.id, now: now)
    let e = try XCTUnwrap(w.currentExercise)
    let selected = try XCTUnwrap(WeightInventory.loads(items: [books()]).last)
    try await r.beginSet(
      workoutID: w.id, exerciseID: e.id, number: 1, weightGrams: selected.grams, load: selected,
      now: now)
    let before = try await r.workout(id: w.id)
    try await r.saveMaximumWeightObjects(3)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after, before)
    try await r.finishTimedSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now + 10_000)
    let saved = try await r.workout(id: w.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.components, selected.components)
    let archive = try await r.exportTraining(now: now + 11_000)
    XCTAssertEqual(try TrainingArchive.decode(archive.encoded()).contents, archive.contents)
  }

  func testArchiveRestoresLimitAndLegacySevenDefaultsToTen() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await r.saveMaximumWeightObjects(20)
    let archive = try await r.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.version, 9)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now)
    try await target.applyTrainingImport(preview, now: now)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored.maximumWeightObjects, 20)
    let csv = try await target.previewCSVImport([], now: now)
    try await target.applyTrainingImport(csv, now: now)
    let afterCSV = try await target.snapshot()
    XCTAssertEqual(afterCSV.maximumWeightObjects, 20)
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    root["version"] = 7
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var config = try XCTUnwrap(contents["configuration"] as? [String: Any])
    config.removeValue(forKey: "maximumWeightObjects")
    config.removeValue(forKey: "backpackWeightGrams")
    contents["configuration"] = config
    root["contents"] = contents
    let old = try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root))
    XCTAssertEqual(old.contents.configuration.maximumWeightObjects, 10)
    root["version"] = 8
    for invalid: Any in [0, -1, 1001, 1.5, NSNull()] {
      config["maximumWeightObjects"] = invalid
      contents["configuration"] = config
      root["contents"] = contents
      XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
    }
  }

  func testSchemaEighteenMigrationPreservesTrainingAndDefaultsToTen() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let before = try await r.exportTraining(now: now)
    let db = try SQLiteDatabase(path: path)
    try db.execute("ALTER TABLE preferences DROP COLUMN maximum_weight_objects")
    try db.execute("PRAGMA user_version=18")
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.exportTraining(now: now)
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 20)
  }
}
