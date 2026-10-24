import Foundation
import XCTest

@testable import SportCore

final class AveragedExerciseGoalTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_892_800_000

  func performance(_ values: [Int], grams: [Int]? = nil, timed: Bool = false) -> WorkoutExercise {
    let definition = TrainingExercise(
      id: "x", name: "X", tracking: timed ? .duration : .repetitions, setCount: values.count,
      minimumReps: timed ? nil : 8, maximumReps: timed ? nil : 12,
      durationSeconds: timed ? 30 : nil, isEnabled: true)
    return WorkoutExercise(
      id: "record", definition: definition,
      sets: values.enumerated().map { index, value in
        WorkoutSet(
          id: "set-\(index)", number: index + 1,
          repetitions: timed ? nil : value, durationMS: timed ? value : nil,
          weightGrams: grams?[index] ?? 0, completedAt: now)
      }, feelingTenths: 85, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
  }

  func testRepetitionsUseCeilingOfMeanForEveryPlannedSet() throws {
    let pike = performance([12, 12, 10, 12])
    let goal = GoalEngine.lastSessionGoal(
      target: pike.definition, previous: pike, loads: [.bodyweight])
    XCTAssertEqual(goal?.repetitions, [12, 12, 12, 12])
    let fractional = performance([10, 9])
    let rounded = GoalEngine.lastSessionGoal(
      target: fractional.definition, previous: fractional, loads: [.bodyweight])
    XCTAssertEqual(rounded?.repetitions, [10, 10])
  }

  func testDurationUsesCeilingOfMeanInSecondsWithoutRoundingEachSavedSet() {
    let hold = performance([17400, 16100, 18900, 17300], timed: true)
    let goal = GoalEngine.lastSessionGoal(
      target: hold.definition, previous: hold, loads: [.bodyweight])
    XCTAssertEqual(goal?.durationsMS, [18000, 18000, 18000, 18000])
    XCTAssertEqual(hold.sets.compactMap(\.durationMS), [17400, 16100, 18900, 17300])
    let exact = performance([17300, 18700], timed: true)
    XCTAssertEqual(
      GoalEngine.lastSessionGoal(target: exact.definition, previous: exact, loads: [.bodyweight])?
        .durationsMS, [18000, 18000])
  }

  func testMixedLoadsAverageOnlySetsAtHeaviestRecordedLoad() {
    let previous = performance([12, 10, 12, 11], grams: [6600, 7500, 7500, 7500])
    let lighter = AvailableLoad(grams: 6600, components: [])
    let heavier = AvailableLoad(grams: 7500, components: [])
    var target = previous.definition
    target.setCount = 2
    let goal = GoalEngine.lastSessionGoal(
      target: target, previous: previous, loads: [lighter, heavier])
    XCTAssertEqual(goal?.load.grams, 7500)
    XCTAssertEqual(goal?.repetitions, [11, 11])
    // A lighter high-repetition set must never inflate the target at the heavier load.
    let strongerLightSet = performance([30, 10, 12, 11], grams: [6600, 7500, 7500, 7500])
    XCTAssertEqual(
      GoalEngine.lastSessionGoal(
        target: target, previous: strongerLightSet,
        loads: [lighter, heavier])?.repetitions, [11, 11])
  }

  func testAverageDoesNotOverflowForLargeValidCounts() {
    let previous = performance([Int.max, Int.max - 2])
    XCTAssertEqual(
      GoalEngine.lastSessionGoal(
        target: previous.definition, previous: previous,
        loads: [.bodyweight])?.repetitions, [Int.max - 1, Int.max - 1])
  }

  func testUpgradeRepairsExistingMixedBulgarianGoalAndRunsOnlyOnce() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let snapshot = try await r.snapshot()
    let definition = try XCTUnwrap(snapshot.exercises.first { $0.id == "bulgarians" })
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    let lighter = try XCTUnwrap(loads.first { $0.grams == 6600 })
    try await r.saveGoal(
      ExerciseGoal(
        definition: definition, load: lighter,
        repetitions: [8, 8, 8, 8]), original: nil, scheduleID: "legs")
    let w = try await r.startWorkout(scheduleID: "legs", now: now)
    let e = try XCTUnwrap(w.currentExercise)
    for (index, rep) in [12, 10, 12, 11].enumerated() {
      let time = now + (index + 1) * 200_000
      if let rest = try await r.workout(id: w.id).rest {
        try await r.changeRest(id: rest.id, action: .skip, now: time)
      }
      let load = try XCTUnwrap(loads.first { $0.grams == (index == 0 ? 6600 : 7500) })
      try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: index + 1, now: time)
      try await r.recordSet(
        workoutID: w.id, exerciseID: e.id, number: index + 1,
        repetitions: rep, weightGrams: load.grams, load: load, now: time + 1000)
    }
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 85, now: now + 1_000_000)
    let recorded = try await r.workout(id: w.id)
    let live = try await r.goalContext(exerciseID: "bulgarians", scheduleID: "legs")
    XCTAssertEqual(live.adopted?.load.grams, 7500)
    XCTAssertEqual(live.adopted?.repetitions, [11, 11, 11, 11])
    // Simulate the stale future target in installed schema14, with actual history intact.
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "UPDATE schedule_exercises SET goal_payload=? WHERE schedule_id='legs'",
      [
        try ExerciseGoal.encode(
          ExerciseGoal(
            definition: definition, load: lighter,
            repetitions: [8, 8, 8, 8]))
      ])
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=14")
    let reopened = try SportRepository(path: path)
    let repaired = try await reopened.goalContext(exerciseID: "bulgarians", scheduleID: "legs")
    XCTAssertEqual(repaired.adopted?.load.grams, 7500)
    XCTAssertEqual(repaired.adopted?.repetitions, [11, 11, 11, 11])
    let unchanged = try await reopened.workout(id: w.id)
    XCTAssertEqual(unchanged, recorded)
    var customized = try XCTUnwrap(repaired.adopted)
    customized.repetitions = [8, 8, 8, 8]
    try await reopened.saveGoal(customized, original: repaired.adopted, scheduleID: "legs")
    let again = try SportRepository(path: path)
    let persisted = try await again.goalContext(exerciseID: "bulgarians", scheduleID: "legs")
    XCTAssertEqual(persisted.adopted, customized)
  }
}
