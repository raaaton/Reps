import Foundation
import XCTest

@testable import RepsCore

final class HistoryDecisionTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000

  func configure(_ r: RepsRepository) async throws {
    let snapshot = try await r.snapshot()
    var plan = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    plan.exerciseIDs = ["chin-ups"]
    plan.setCounts = ["chin-ups": 1]
    try await r.saveSchedule(plan)
  }

  func manual(_ id: String, reps: Int, at: Int) -> ManualWorkout {
    ManualWorkout(
      id: id, name: "Recorded", performedAt: at,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: [ManualWorkoutSet(repetitions: reps, weightGrams: 0)], feelingTenths: 85)
      ])
  }

  func goal(_ r: RepsRepository) async throws -> ExerciseGoal? {
    try await r.goalContext(exerciseID: "chin-ups", scheduleID: "pull-abs").adopted
  }

  func draft(_ w: WorkoutSession) -> ManualWorkout {
    ManualWorkout(
      id: w.id, name: w.name, performedAt: w.startedAt,
      exercises: w.exercises.map { e in
        ManualWorkoutExercise(
          catalogueID: e.definition.id, tracking: e.definition.tracking,
          sets: e.sets.map {
            ManualWorkoutSet(
              repetitions: $0.repetitions, durationMS: $0.durationMS, weightGrams: $0.weightGrams,
              sourceID: $0.id)
          }, feelingTenths: e.feelingTenths)
      })
  }

  func completedWithDecision(_ r: RepsRepository) async throws -> WorkoutSession {
    try await configure(r)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1, repetitions: 12, weightGrams: 3900,
      now: now + 1000)
    let decision = try await r.exerciseLoadGoalDecision(
      workoutID: w.id, exerciseID: e.id, feelingTenths: 75, now: now + 2000)
    try await r.resolveExerciseLoadGoal(XCTUnwrap(decision), update: true, now: now + 2000)
    return try await r.workout(id: w.id)
  }

  func addAssignment(_ r: RepsRepository) async throws -> ExerciseGoal? {
    let snapshot = try await r.snapshot()
    var plan = try XCTUnwrap(snapshot.schedules.first { $0.id == "legs" })
    plan.exerciseIDs = ["chin-ups"]
    plan.setCounts = ["chin-ups": 2]
    try await r.saveSchedule(plan)
    return try await r.goalContext(exerciseID: "chin-ups", scheduleID: "legs").adopted
  }

  func testRenamePreservesExplicitDecisionForNewAssignment() async throws {
    let r = try RepsRepository(path: ":memory:")
    let original = try await completedWithDecision(r)
    let before = try await goal(r)
    XCTAssertEqual(before?.load.grams, 4500)
    var edit = draft(original)
    edit.name = "Renamed only"
    try await r.updateHistoricalWorkout(edit, original: original, now: now + 3000)
    let seeded = try await addAssignment(r)
    XCTAssertEqual(seeded?.load.grams, 4500)
    let preserved = try await goal(r)
    XCTAssertEqual(preserved, before)
  }

  func testHistoryAddEditDeleteLeaveFutureGoalsUnchanged() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await configure(r)
    let before = try await r.snapshot()
    try await r.addHistoricalWorkout(manual("record", reps: 12, at: now), now: now)
    var after = try await r.snapshot()
    XCTAssertEqual(after, before)
    let stored = try await r.workout(id: "record")
    var edit = draft(stored)
    edit.exercises[0].sets[0].repetitions = 9
    try await r.updateHistoricalWorkout(edit, original: stored, now: now + 1000)
    after = try await r.snapshot()
    XCTAssertEqual(after, before)
    try await r.deleteHistoricalWorkout(id: "record")
    after = try await r.snapshot()
    XCTAssertEqual(after, before)
  }

  func testCorrectedPerformanceDropsOldDecisionWithoutRewritingExistingGoal() async throws {
    let r = try RepsRepository(path: ":memory:")
    let stored = try await completedWithDecision(r)
    let before = try await goal(r)
    var edit = draft(stored)
    edit.exercises[0].sets[0].repetitions = 9
    try await r.updateHistoricalWorkout(edit, original: stored, now: now + 1000)
    let after = try await goal(r)
    XCTAssertEqual(after, before)
    let seeded = try await addAssignment(r)
    XCTAssertEqual(seeded?.load.grams, 3900)
    XCTAssertEqual(seeded?.repetitions, [9, 9])
  }
}
