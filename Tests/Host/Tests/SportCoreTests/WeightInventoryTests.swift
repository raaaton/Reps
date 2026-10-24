import Foundation
import XCTest

@testable import SportCore

final class WeightInventoryTests: XCTestCase, @unchecked Sendable {
  func testVersionThreeMigrationPreservesRecordedLoadAndSeedsOnlyOnce() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    // Independent v3 column fixture, not produced by the new migrator.
    try db.execute(
      "CREATE TABLE workout_sets(id TEXT,exercise_id TEXT,number INTEGER,repetitions INTEGER,duration_ms INTEGER,weight_grams INTEGER,completed_at INTEGER)"
    )
    try db.execute("CREATE TABLE workout_exercises(id TEXT,set_weight_grams INTEGER)")
    try db.execute("INSERT INTO workout_sets VALUES('old','exercise',1,12,NULL,2375,12345)")
    try db.execute("CREATE TABLE workouts(day_key TEXT,started_at INTEGER)")
    try db.execute("CREATE TABLE exercises(id TEXT PRIMARY KEY,set_count INTEGER)")
    try db.execute(
      "CREATE TABLE schedule_exercises(schedule_id TEXT,exercise_id TEXT,position INTEGER)")
    try db.execute("CREATE TABLE preferences(id INTEGER PRIMARY KEY,rest_seconds INTEGER)")
    try db.execute("INSERT INTO preferences VALUES(1,180)")
    try db.execute("PRAGMA user_version=3")
    _ = try SportRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 17)
    XCTAssertEqual(
      try db.query("SELECT weight_grams FROM workout_sets").first?.integer("weight_grams"), 2375)
    XCTAssertEqual(try db.query("SELECT count(*) AS n FROM weight_items").first?.integer("n"), 3)
    try db.execute("DELETE FROM weight_items WHERE id='river-book'")
    _ = try SportRepository(path: path)
    XCTAssertEqual(try db.query("SELECT count(*) AS n FROM weight_items").first?.integer("n"), 2)
  }

  func testSeededLoadsAreExactSortedAndBagOccursOnce() async throws {
    let repository = try SportRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    XCTAssertEqual(loads.map(\.grams), [0, 3000, 3900, 4500, 5100, 5400, 6000, 6600, 7500])
    XCTAssertEqual(loads.last?.components.filter { $0.id == "base-bag" }.count, 1)
    XCTAssertEqual(loads.last?.components.reduce(0) { $0 + $1.grams }, 7500)
    XCTAssertEqual(loads.first?.components, [])
  }

  func testDeduplicationDisabledItemsOverflowAndComplexityGuard() throws {
    let items = [
      WeightItem(id: "a", name: "A", grams: 1000, isEnabled: true),
      WeightItem(id: "b", name: "B", grams: 1000, isEnabled: true),
      WeightItem(id: "c", name: "C", grams: 2500, isEnabled: false),
    ]
    XCTAssertEqual(try WeightInventory.loads(items: items).map(\.grams), [0, 3000, 4000, 5000])
    XCTAssertThrowsError(
      try WeightInventory.loads(items: [
        WeightItem(id: "max", name: "Max", grams: Int.max, isEnabled: true)
      ]))
    let large = (0..<13).map {
      WeightItem(id: "p\($0)", name: "P", grams: 1 << $0, isEnabled: true)
    }
    XCTAssertThrowsError(try WeightInventory.loads(items: large))
  }

  func testInventoryCRUDPersistsAndRejectsInvalidOrTooComplexInputAtomically() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SportRepository(path: path)
    let item = WeightItem(
      id: "custom", name: " Petit livre ", grams: try WorkoutWeight.grams("0,125"), isEnabled: true)
    try await repository.saveWeightItem(item)
    let reopened = try SportRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.weightItems.first { $0.id == "custom" }?.grams, 125)
    XCTAssertEqual(snapshot.weightItems.first { $0.id == "custom" }?.name, "Petit livre")
    do {
      try await repository.saveWeightItem(
        WeightItem(id: "invalid", name: " ", grams: 0, isEnabled: true))
      XCTFail("Invalid item saved")
    } catch {}
    do {
      try await repository.saveWeightItem(
        WeightItem(id: "invalid", name: "Overflow", grams: Int.max, isEnabled: true))
      XCTFail("Overflow item saved")
    } catch {}
    let after = try await repository.snapshot()
    XCTAssertEqual(after.weightItems, snapshot.weightItems)
    try await reopened.deleteWeightItem(id: "custom")
    let final = try await repository.snapshot()
    XCTAssertFalse(final.weightItems.contains { $0.id == "custom" })
  }

  func testTimedLoadCompositionSurvivesInventoryDeletionAndRelaunch() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SportRepository(path: path)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = 1_791_720_000_000
    let snapshot = try await repository.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await repository.saveSchedule(schedule)
    let session = try await repository.startWorkout(
      scheduleID: schedule.id, now: now, calendar: calendar)
    let exercise = try XCTUnwrap(session.currentExercise)
    let load = try XCTUnwrap(WeightInventory.loads(items: snapshot.weightItems).last)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, weightGrams: load.grams,
      load: load, now: now)
    for item in snapshot.weightItems { try await repository.deleteWeightItem(id: item.id) }
    let reopened = try SportRepository(path: path)
    try await reopened.finishTimedSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now + 10_000)
    let saved = try await reopened.workout(id: session.id)
    let set = try XCTUnwrap(saved.currentExercise?.sets.first)
    XCTAssertEqual(set.weightGrams, 7500)
    XCTAssertEqual(set.components, load.components)
    XCTAssertEqual(set.durationMS, 7000)
    try await reopened.cancelWorkout(id: session.id, now: now + 11_000)
    let original = try await reopened.workout(id: session.id)
    var edited = ManualWorkout(
      id: session.id, name: "Corrigée", performedAt: now,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "l-sit", tracking: .duration,
          sets: [ManualWorkoutSet(durationMS: 7000, weightGrams: 7500, sourceID: set.id)],
          feelingTenths: nil)
      ])
    try await reopened.updateHistoricalWorkout(
      edited, original: original, now: now + 12_000, calendar: calendar)
    let unchanged = try await reopened.workout(id: session.id)
    XCTAssertEqual(unchanged.exercises.first?.sets.first?.components, load.components)
    edited.exercises[0].sets[0].weightGrams = 6000
    try await reopened.updateHistoricalWorkout(
      edited, original: unchanged, now: now + 13_000, calendar: calendar)
    let changed = try await reopened.workout(id: session.id)
    XCTAssertNil(changed.exercises.first?.sets.first?.components)
    XCTAssertEqual(changed.exercises.first?.sets.first?.weightGrams, 6000)
  }

  func testManyEqualWeightObjectsAreRejectedBeforeComponentWorkExplodes() {
    let items = (0..<200).map {
      WeightItem(id: "tiny-\($0)", name: "Tiny", grams: 1, isEnabled: true)
    }
    XCTAssertThrowsError(try WeightInventory.loads(items: items))
  }
}
