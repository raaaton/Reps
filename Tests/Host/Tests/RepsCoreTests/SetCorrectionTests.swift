import Foundation
import XCTest

@testable import RepsCore

final class SetCorrectionTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func testCorrectionPreservesRestPhaseTimestampAndRejectsStaleInput() async throws {
    let r = try RepsRepository(path: ":memory:")
    let workout = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await r.beginSet(workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now + 1000)
    let loads = try WeightInventory.loads(items: await r.snapshot().weightItems)
    let load = try XCTUnwrap(loads.first { $0.grams == 3900 })
    try await r.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, repetitions: 10,
      weightGrams: load.grams, load: load, now: now + 2000)
    let before = try await r.workout(id: workout.id)
    let set = try XCTUnwrap(before.currentExercise?.sets.first)
    try await r.correctSet(
      workoutID: workout.id, exerciseID: exercise.id, original: set, repetitions: 11,
      durationMS: nil, weightGrams: set.weightGrams)
    let after = try await r.workout(id: workout.id)
    XCTAssertEqual(after.rest, before.rest)
    XCTAssertEqual(after.phase(at: now + 3000), .resting)
    XCTAssertEqual(after.currentExercise?.sets.first?.completedAt, set.completedAt)
    XCTAssertEqual(after.currentExercise?.sets.first?.components, set.components)
    XCTAssertEqual(after.currentExercise?.sets.first?.repetitions, 11)
    do {
      try await r.correctSet(
        workoutID: workout.id, exerciseID: exercise.id, original: set, repetitions: 12,
        durationMS: nil, weightGrams: 3900)
      XCTFail("Stale edit saved")
    } catch {}
    let current = try XCTUnwrap(after.currentExercise?.sets.first)
    do {
      try await r.correctSet(
        workoutID: workout.id, exerciseID: exercise.id, original: current, repetitions: 0,
        durationMS: nil, weightGrams: 3900)
      XCTFail("Invalid edit saved")
    } catch {}
    try await r.cancelWorkout(id: workout.id, now: now + 4000)
    do {
      try await r.correctSet(
        workoutID: workout.id, exerciseID: exercise.id, original: current, repetitions: 12,
        durationMS: nil, weightGrams: 3900)
      XCTFail("Terminal workout edited through active API")
    } catch {}
  }
  func testChangedChargeDropsUnknownCompositionAndDoesNotResetRunningNextSet() async throws {
    let r = try RepsRepository(path: ":memory:")
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    let ex = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: ex.id, number: 1, now: now + 1)
    try await r.recordSet(
      workoutID: w.id, exerciseID: ex.id, number: 1, repetitions: 10,
      weightGrams: 3900, now: now + 1000)
    let saved = try await r.workout(id: w.id)
    let rest = try XCTUnwrap(saved.rest)
    try await r.changeRest(id: rest.id, action: .skip, now: now + 2000)
    try await r.beginSet(workoutID: w.id, exerciseID: ex.id, number: 2, now: now + 3000)
    let original = try XCTUnwrap(saved.currentExercise?.sets.first)
    try await r.correctSet(
      workoutID: w.id, exerciseID: ex.id, original: original, repetitions: 10, durationMS: nil,
      weightGrams: 2375)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after.currentExercise?.setStartedAt, now + 3000)
    XCTAssertEqual(after.currentExercise?.sets.first?.weightGrams, 2375)
    XCTAssertNil(after.currentExercise?.sets.first?.components)
  }
}
