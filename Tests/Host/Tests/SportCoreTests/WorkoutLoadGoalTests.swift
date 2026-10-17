import Foundation
import XCTest

@testable import SportCore

final class WorkoutLoadGoalTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  func ready(_ r: SportRepository, single: Bool = false) async throws -> WorkoutSession {
    let snapshot = try await r.snapshot()
    var plan = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    if single {
      plan.exerciseIDs = ["chin-ups"]
      try await r.saveSchedule(plan)
    }
    for var exercise in snapshot.exercises where plan.exerciseIDs.contains(exercise.id) {
      exercise.setCount = 1
      try await r.saveExercise(exercise)
    }
    let workout = try await r.startWorkout(scheduleID: plan.id, now: now)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await r.beginSet(workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1,
      repetitions: 12, weightGrams: 3900, now: now + 1000)
    return try await r.workout(id: workout.id)
  }
  func proposal(_ r: SportRepository, _ w: WorkoutSession, feeling: Int = 75) async throws
    -> ExerciseLoadGoalDecision
  {
    let exercise = try XCTUnwrap(w.currentExercise)
    let value = try await r.exerciseLoadGoalDecision(
      workoutID: w.id, exerciseID: exercise.id,
      feelingTenths: feeling, now: now + 2000)
    return try XCTUnwrap(value)
  }
  func finishSecond(_ r: SportRepository, _ id: String) async throws {
    var workout = try await r.workout(id: id)
    if let rest = workout.rest {
      try await r.changeRest(id: rest.id, action: .skip, now: now + 3000)
    }
    workout = try await r.workout(id: id)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await r.beginSet(workoutID: id, exerciseID: exercise.id, number: 1, now: now + 4000)
    try await r.finishTimedSet(workoutID: id, exerciseID: exercise.id, number: 1, now: now + 8000)
    try await r.recordSet(
      workoutID: id, exerciseID: exercise.id, number: 1, repetitions: nil,
      weightGrams: 0, now: now + 8000)
    try await r.saveFeeling(workoutID: id, exerciseID: exercise.id, tenths: 80, now: now + 9000)
  }
  func testUpdateAppearsBeforeTransitionAndSurvivesReopenAndCompletion() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let w = try await ready(r)
    let p = try await proposal(r, w)
    XCTAssertEqual(p.suggestion.goal.load.grams, 4500)
    let preview = try await r.workout(id: w.id)
    XCTAssertEqual(preview.phase(at: now + 2000), .feeling)
    XCTAssertNil(preview.currentExercise?.feelingTenths)
    let observed1 = try await r.snapshot().goals.isEmpty
    XCTAssertTrue(observed1)
    try await r.resolveExerciseLoadGoal(p, update: true, now: now + 2000)
    let reopened = try SportRepository(path: path)
    let observed2 = try await reopened.goalContext(exerciseID: "chin-ups").adopted?.load.grams
    XCTAssertEqual(observed2, 4500)
    try await finishSecond(reopened, w.id)
    let next = try await reopened.startWorkout(
      scheduleID: "pull-abs", now: now + 10000, restart: true)
    XCTAssertEqual(next.currentExercise?.goal?.load.grams, 4500)
    XCTAssertEqual(next.currentExercise?.goal?.repetitions, [8])
  }
  func testKeepPreservesExistingGoalThroughCompletion() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await ready(r)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    var original = try XCTUnwrap(context.suggestion?.goal)
    original.repetitions = [9]
    try await r.saveGoal(original, original: nil)
    let p = try await proposal(r, w)
    try await r.resolveExerciseLoadGoal(p, update: false, now: now + 2000)
    try await finishSecond(r, w.id)
    let observed3 = try await r.goalContext(exerciseID: "chin-ups").adopted
    XCTAssertEqual(observed3, original)
  }
  func testLastExerciseDecisionIsNotOverwrittenByImmediateCompletion() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await ready(r, single: true)
    let p = try await proposal(r, w, feeling: 95)
    XCTAssertEqual(p.suggestion.reason, .decreaseLoad)
    try await r.resolveExerciseLoadGoal(p, update: true, now: now + 2000)
    let observed4 = try await r.workout(id: w.id).status
    XCTAssertEqual(observed4, .completed)
    let observed5 = try await r.goalContext(exerciseID: "chin-ups").adopted?.load.grams
    XCTAssertEqual(observed5, 3000)
  }
  func testStaleGoalAndInventoryAndChangedEffortCannotCommit() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await ready(r, single: true)
    let p = try await proposal(r, w)
    var custom = p.suggestion.goal
    custom.repetitions = [9]
    try await r.saveGoal(custom, original: nil)
    do {
      try await r.resolveExerciseLoadGoal(p, update: true, now: now + 2000)
      XCTFail("stale accepted")
    } catch {}
    let observed6 = try await r.workout(id: w.id).currentExercise?.feelingTenths
    XCTAssertNil(observed6)
    let fresh = try await proposal(r, w)
    try await r.deleteWeightItem(id: "programming-books")
    do {
      try await r.resolveExerciseLoadGoal(fresh, update: true, now: now + 2000)
      XCTFail("stale inventory accepted")
    } catch {}
    let observed7 = try await r.goalContext(exerciseID: "chin-ups").adopted
    XCTAssertEqual(observed7, custom)
  }
  func testSQLFailureRollsBackGoalDecisionAndFeeling() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let w = try await ready(r, single: true)
    let p = try await proposal(r, w)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER fail_marker BEFORE INSERT ON workout_goal_decisions BEGIN SELECT RAISE(ABORT,'test failure'); END"
    )
    do {
      try await r.resolveExerciseLoadGoal(p, update: true, now: now + 2000)
      XCTFail("SQL failure ignored")
    } catch {}
    let observed8 = try await r.snapshot().goals.isEmpty
    XCTAssertTrue(observed8)
    let observed9 = try await r.workout(id: w.id).currentExercise?.feelingTenths
    XCTAssertNil(observed9)
    XCTAssertEqual(
      try db.query("SELECT COUNT(*) AS n FROM workout_goal_decisions").first?.integer("n"), 0)
  }
  func testMigrationEightPreservesActiveResultsAndRestSettings() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let workout = try await ready(r)
    let before = try await r.snapshot()
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TABLE workout_goal_decisions")
    try db.execute("PRAGMA user_version=8")
    let reopened = try SportRepository(path: path)
    let after = try await reopened.snapshot()
    let restored = try await reopened.workout(id: workout.id)
    XCTAssertEqual(before, after)
    XCTAssertEqual(restored, workout)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 9)
    XCTAssertEqual(
      try db.query("SELECT COUNT(*) AS n FROM workout_goal_decisions").first?.integer("n"), 0)
  }

  func testExplicitChoicesRemainWhenRestOfWorkoutIsCancelled() async throws {
    for update in [true, false] {
      let r = try SportRepository(path: ":memory:")
      let w = try await ready(r)
      let decision = try await proposal(r, w)
      try await r.resolveExerciseLoadGoal(decision, update: update, now: now + 2000)
      try await r.cancelWorkout(id: w.id, now: now + 3000)
      let context = try await r.goalContext(exerciseID: "chin-ups")
      XCTAssertEqual(context.adopted, update ? decision.suggestion.goal : nil)
    }
  }

}
