import Foundation
import XCTest

@testable import SportCore

final class ExerciseGoalTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func entry(reps: [Int] = [12, 12, 12, 12], feeling: Int = 75) -> ManualWorkout {
    ManualWorkout(
      id: "past", name: "Past", performedAt: now - 86_400_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: reps.map { ManualWorkoutSet(repetitions: $0, weightGrams: 3900) },
          feelingTenths: feeling)
      ])
  }
  func testAdoptionPersistedAndActiveSnapshotUnchangedByLaterGoal() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await r.addHistoricalWorkout(entry(), now: now, calendar: calendar)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    let suggestion = try XCTUnwrap(context.suggestion)
    XCTAssertEqual(suggestion.reason, .increaseLoad)
    XCTAssertEqual(suggestion.goal.load.grams, 4500)
    XCTAssertEqual(suggestion.goal.repetitions, [8, 8, 8, 8])
    try await r.adoptGoal(suggestion, original: nil)
    let reopened = try SportRepository(path: path)
    let persisted = try await reopened.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(persisted.adopted, suggestion.goal)
    let workout = try await reopened.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    let chin = try XCTUnwrap(workout.currentExercise)
    XCTAssertEqual(chin.goal, suggestion.goal)
    var changed = suggestion.goal
    changed.repetitions = [9, 9, 9, 9]
    try await reopened.saveGoal(changed, original: suggestion.goal)
    let old = try await reopened.workout(id: workout.id)
    XCTAssertEqual(old.currentExercise?.goal, suggestion.goal)
    try await reopened.deleteWeightItem(id: "programming-books")
    let still = try await reopened.workout(id: workout.id)
    XCTAssertEqual(still.currentExercise?.goal?.load.grams, 4500)
    let latest = try await reopened.goalContext(exerciseID: "chin-ups")
    XCTAssertFalse(latest.isAvailable)
  }
  func testOneRepetitionProposalAndHighEffortMaintain() async throws {
    let r = try SportRepository(path: ":memory:")
    try await r.addHistoricalWorkout(entry(reps: [10, 10, 9, 8]), now: now, calendar: calendar)
    var context = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(context.suggestion?.goal.repetitions, [10, 10, 9, 9])
    XCTAssertEqual(context.suggestion?.goal.load.grams, 3900)
    XCTAssertEqual(context.suggestion?.reason, .addRepetition)
    let original = try await r.workout(id: "past")
    try await r.updateHistoricalWorkout(
      entry(reps: [10, 10, 9, 8], feeling: 80), original: original, now: now, calendar: calendar)
    context = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(context.suggestion?.goal.repetitions, [10, 10, 9, 8])
    XCTAssertEqual(context.suggestion?.reason, .keep)
  }
  func testStaleAdoptionAndInvalidGoalAreRefusedWithoutReplacingSavedGoal() async throws {
    let r = try SportRepository(path: ":memory:")
    try await r.addHistoricalWorkout(entry(), now: now, calendar: calendar)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    let suggestion = try XCTUnwrap(context.suggestion)
    let original = try await r.workout(id: "past")
    try await r.updateHistoricalWorkout(
      entry(feeling: 80), original: original, now: now, calendar: calendar)
    do {
      try await r.adoptGoal(suggestion, original: nil)
      XCTFail("Stale suggestion adopted")
    } catch {}
    var invalid = suggestion.goal
    invalid.repetitions = [8]
    do {
      try await r.saveGoal(invalid, original: nil)
      XCTFail("Incomplete goal saved")
    } catch {}
    let after = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertNil(after.adopted)
    let valid = try XCTUnwrap(after.suggestion?.goal)
    try await r.saveGoal(valid, original: nil)
    do {
      try await r.saveGoal(suggestion.goal, original: nil)
      XCTFail("Second editor overwrote goal")
    } catch {}
    let current = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(current.adopted, valid)
  }
  func testContextualLoadOverrideDoesNotChangeLongTermGoal() async throws {
    let r = try SportRepository(path: ":memory:")
    let initial = try await r.goalContext(exerciseID: "chin-ups")
    var goal = try XCTUnwrap(initial.suggestion?.goal)
    goal.load = try WeightInventory.loads(items: await r.snapshot().weightItems).first {
      $0.grams == 3900
    }!
    try await r.saveGoal(goal, original: nil)
    let workout = try await r.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar, loadOverrides: ["chin-ups": .bodyweight]
    )
    XCTAssertEqual(workout.currentExercise?.goal?.load.grams, 0)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(context.adopted?.load.grams, 3900)
  }
}
