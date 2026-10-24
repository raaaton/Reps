import Foundation
import XCTest

@testable import RepsCore

final class BackpackWeightTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000

  func testCustomBackpackWeightIsAddedOnceAndBodyweightStaysZero() throws {
    let items = [WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: 2)]
    let loads = try WeightInventory.loads(items: items, backpackGrams: 450)
    XCTAssertEqual(loads.map(\.grams), [0, 450, 550, 650])
    XCTAssertEqual(loads.last?.components.first?.grams, 450)
    XCTAssertEqual(loads.last?.components.first?.quantity, 1)
    XCTAssertEqual(loads.last?.components.filter { $0.id == "base-bag" }.count, 1)
    XCTAssertEqual(loads.first, .bodyweight)
    XCTAssertTrue(
      WeightInventory.isAvailable(try XCTUnwrap(loads.last), items: items, backpackGrams: 450))
    XCTAssertFalse(
      WeightInventory.isAvailable(try XCTUnwrap(loads.last), items: items, backpackGrams: 3000))
  }

  func testDefaultAndEditedBackpackPersistWithoutChangingOtherPreferences() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let before = try await r.snapshot()
    XCTAssertEqual(before.backpackWeightGrams, 3000)
    try await r.saveBackpackWeight(grams: WorkoutWeight.grams("0,725"))
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.snapshot()
    XCTAssertEqual(after.backpackWeightGrams, 725)
    XCTAssertEqual(after.weightItems, before.weightItems)
    XCTAssertEqual(after.maximumWeightObjects, before.maximumWeightObjects)
    let loads = try WeightInventory.loads(
      items: after.weightItems, maximumObjects: after.maximumWeightObjects,
      backpackGrams: after.backpackWeightGrams)
    XCTAssertEqual(loads[1].grams, 725)
    XCTAssertEqual(loads.last?.grams, 5225)
  }

  func testInvalidOrOverflowingBackpackWeightRollsBack() async throws {
    let r = try RepsRepository(path: ":memory:")
    let before = try await r.snapshot()
    for grams in [0, -1, Int.max] {
      do {
        try await r.saveBackpackWeight(grams: grams)
        XCTFail("Invalid backpack accepted")
      } catch {}
      let after = try await r.snapshot()
      XCTAssertEqual(after, before)
    }
    XCTAssertThrowsError(try WeightInventory.loads(items: [], backpackGrams: 0))
  }

  func testChangedBackpackRequiresGoalReviewWithoutRewritingTheSavedComposition() async throws {
    let r = try RepsRepository(path: ":memory:")
    let initial = try await r.snapshot()
    let load = try XCTUnwrap(
      WeightInventory.loads(items: initial.weightItems).first { $0.grams == 3900 })
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    let old = ExerciseGoal(definition: c.exercise, load: load, repetitions: [8, 8, 8, 8])
    try await r.saveGoal(old, original: c.adopted, scheduleID: "push")
    try await r.saveBackpackWeight(grams: 1200)
    let current = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertFalse(current.isAvailable)
    XCTAssertEqual(current.adopted, old)
    let snapshot = try await r.snapshot()
    let loads = try WeightInventory.loads(
      items: snapshot.weightItems, backpackGrams: snapshot.backpackWeightGrams)
    XCTAssertTrue(snapshot.needsGoalReview(for: c.exercise, availableLoads: loads))
    let next = try XCTUnwrap(loads.first { $0.grams == 2100 })
    let edited = ExerciseGoal(definition: c.exercise, load: next, repetitions: [8, 8, 8, 8])
    try await r.saveGoal(edited, original: old, scheduleID: "push")
    let valid = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertTrue(valid.isAvailable)
  }

  func testActiveAndRecordedBackpackSnapshotsSurviveChangingThePreference() async throws {
    let r = try RepsRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await r.saveSchedule(schedule)
    let w = try await r.startWorkout(scheduleID: schedule.id, now: now)
    let e = try XCTUnwrap(w.currentExercise)
    let load = try XCTUnwrap(WeightInventory.loads(items: snapshot.weightItems).last)
    try await r.beginSet(
      workoutID: w.id, exerciseID: e.id, number: 1, weightGrams: load.grams, load: load, now: now)
    let before = try await r.workout(id: w.id)
    try await r.saveBackpackWeight(grams: 500)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after, before)
    try await r.finishTimedSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now + 10_000)
    let saved = try await r.workout(id: w.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.components, load.components)
    let archive = try await r.exportTraining(now: now + 11_000)
    XCTAssertEqual(try TrainingArchive.decode(archive.encoded()).contents, archive.contents)
  }

  func testJSONRestoreAndCSVKeepBackpackAndLegacyEightDefaultsToThreeKilograms() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await r.saveBackpackWeight(grams: 750)
    let archive = try await r.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.version, 9)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now)
    try await target.applyTrainingImport(preview, now: now)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored.backpackWeightGrams, 750)
    let csv = try await target.previewCSVImport([], now: now)
    try await target.applyTrainingImport(csv, now: now)
    let afterCSV = try await target.snapshot()
    XCTAssertEqual(afterCSV.backpackWeightGrams, 750)
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    root["version"] = 8
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var config = try XCTUnwrap(contents["configuration"] as? [String: Any])
    config.removeValue(forKey: "backpackWeightGrams")
    contents["configuration"] = config
    root["contents"] = contents
    let legacy = try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root))
    XCTAssertEqual(legacy.contents.configuration.backpackWeightGrams, 3000)
    root["version"] = 9
    for bad: Any in [0, -1, 1.5, NSNull()] {
      config["backpackWeightGrams"] = bad
      contents["configuration"] = config
      root["contents"] = contents
      XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
    }
  }

  func testMigrationFromNineteenKeepsConfigurationAndDefaultsToThreeKilograms() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let before = try await r.exportTraining(now: now)
    let db = try SQLiteDatabase(path: path)
    try db.execute("ALTER TABLE preferences DROP COLUMN backpack_weight_grams")
    try db.execute("PRAGMA user_version=19")
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.exportTraining(now: now)
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 20)
  }
}
