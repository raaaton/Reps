import Foundation
import XCTest

@testable import SportCore

final class LatestExerciseGoalTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_892_800_000

  func configure(_ r: SportRepository, timed: Bool = false) async throws {
    let snapshot = try await r.snapshot()
    let id = timed ? "l-sit" : "push-ups"
    for (scheduleID, count) in [("legs", 2), ("push", 4)] {
      var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == scheduleID })
      schedule.exerciseIDs = [id]
      schedule.setCounts = [id: count]
      try await r.saveSchedule(schedule)
    }
  }

  @discardableResult
  func finish(
    _ r: SportRepository, schedule: String = "legs", reps: [Int] = [10, 9],
    at start: Int? = nil
  ) async throws -> WorkoutSession {
    let start = start ?? now
    let w = try await r.startWorkout(scheduleID: schedule, now: start, restart: true)
    let exercise = try XCTUnwrap(w.currentExercise)
    for (index, rep) in reps.enumerated() {
      let time = start + (index + 1) * 200_000
      let active = try await r.workout(id: w.id)
      if let rest = active.rest { try await r.changeRest(id: rest.id, action: .skip, now: time) }
      try await r.beginSet(workoutID: w.id, exerciseID: exercise.id, number: index + 1, now: time)
      try await r.recordSet(
        workoutID: w.id, exerciseID: exercise.id, number: index + 1,
        repetitions: rep, weightGrams: 0, now: time + 1000)
    }
    try await r.saveFeeling(
      workoutID: w.id, exerciseID: exercise.id, tenths: 85,
      now: start + (reps.count + 1) * 200_000)
    return try await r.workout(id: w.id)
  }

  func testCompletionPropagatesLatestExerciseAcrossWorkoutsAndResizesTargets() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let done = try await finish(r)
    XCTAssertEqual(done.status, .completed)
    let other = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(other.adopted?.repetitions, [10, 10, 10, 10])
    let next = try await r.startWorkout(scheduleID: "push", now: now + 4 * 86_400_000)
    XCTAssertEqual(next.currentExercise?.goal?.repetitions, [10, 10, 10, 10])
    // New reference is the latest exercise session even when the older workout had fewer sets.
    try await r.cancelWorkout(id: next.id, now: now + 4 * 86_400_000 + 1)
    try await finish(r, schedule: "push", reps: [12, 11, 10, 9], at: now + 11 * 86_400_000)
    let two = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(two.adopted?.repetitions, [11, 11])
  }

  func testUpgradeRefreshesExistingHistoryOnceAndPreservesActiveSnapshots() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    try await finish(r)
    let active = try await r.startWorkout(scheduleID: "push", now: now + 4 * 86_400_000)
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE schedule_exercises SET goal_payload=NULL WHERE exercise_id='push-ups'")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=13")
    let reopened = try SportRepository(path: path)
    let refreshed = try await reopened.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(refreshed.adopted?.repetitions, [10, 10, 10, 10])
    let preserved = try await reopened.workout(id: active.id)
    XCTAssertEqual(preserved, active)
    let context = try await reopened.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    var custom = try XCTUnwrap(context.adopted)
    custom.repetitions = [8, 8]
    try await reopened.saveGoal(custom, original: context.adopted, scheduleID: "legs")
    let again = try SportRepository(path: path)
    let saved = try await again.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(saved.adopted?.repetitions, [8, 8])
  }

  func testFailedPropagationRollsBackWorkoutCompletionAndAllGoals() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      """
      CREATE TRIGGER reject_other_goal BEFORE UPDATE OF goal_payload ON schedule_exercises
      WHEN NEW.schedule_id='push' AND NEW.goal_payload IS NOT NULL
      BEGIN SELECT RAISE(ABORT,'test'); END
      """)
    do {
      try await finish(r)
      XCTFail("Completion committed only some future goals")
    } catch {}
    let state = try await r.workoutOverview(now: now + 800_000)
    XCTAssertEqual(state.active?.currentExercise?.feelingTenths, nil)
    XCTAssertEqual(state.active?.status, .active)
    let snapshot = try await r.snapshot()
    XCTAssertTrue(snapshot.schedules.allSatisfy { $0.goals["push-ups"] == nil })
  }
}

extension LatestExerciseGoalTests {
  func testTimedCompletionCarriesActualTenthsIntoBothWorkoutsAndTheirFrozenWarmup() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, timed: true)
    let w = try await r.startWorkout(scheduleID: "legs", now: now)
    let e = try XCTUnwrap(w.currentExercise)
    for (index, duration) in [12300, 10700].enumerated() {
      let time = now + (index + 1) * 200_000
      let state = try await r.workout(id: w.id)
      if let rest = state.rest { try await r.changeRest(id: rest.id, action: .skip, now: time) }
      try await r.beginSet(
        workoutID: w.id, exerciseID: e.id, number: index + 1,
        weightGrams: 0, load: .bodyweight, now: time)
      try await r.finishTimedSet(
        workoutID: w.id, exerciseID: e.id, number: index + 1,
        now: time + 3000 + duration)
      try await r.recordSet(
        workoutID: w.id, exerciseID: e.id, number: index + 1,
        repetitions: nil, weightGrams: 0, now: time + 3000 + duration)
    }
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 85, now: now + 600_000)
    let two = try await r.goalContext(exerciseID: "l-sit", scheduleID: "legs")
    let four = try await r.goalContext(exerciseID: "l-sit", scheduleID: "push")
    XCTAssertEqual(two.adopted?.durationsMS, [12000, 12000])
    XCTAssertEqual(four.adopted?.durationsMS, [12000, 12000, 12000, 12000])
    XCTAssertNil(four.exercise.durationSeconds)
    let next = try await r.startWorkout(
      scheduleID: "push", now: now + 4 * 86_400_000,
      includeSupport: true, stretch: .quadriceps, stretchSeconds: 30)
    XCTAssertEqual(next.currentExercise?.goal?.durationTargetMS(forSet: 3), 12000)
    XCTAssertEqual(next.support?.steps.first?.targetDurationMS, 6000)
  }

  func testUpgradeUsesLatestManualSessionAcrossWorkoutsAndIgnoresLaterCancellation() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    try await finish(r)
    let manual = ManualWorkout(
      id: "latest", name: "Elsewhere", performedAt: now + 86_400_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "push-ups", tracking: .repetitions,
          sets: [
            ManualWorkoutSet(repetitions: 11, weightGrams: 0),
            ManualWorkoutSet(repetitions: 10, weightGrams: 0),
            ManualWorkoutSet(repetitions: 8, weightGrams: 0),
          ], feelingTenths: 85)
      ])
    try await r.addHistoricalWorkout(manual, now: now + 2 * 86_400_000)
    let cancelled = try await r.startWorkout(scheduleID: "push", now: now + 4 * 86_400_000)
    try await r.cancelWorkout(id: cancelled.id, now: now + 4 * 86_400_000 + 1000)
    let db = try SQLiteDatabase(path: path)
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=13")
    let migrated = try SportRepository(path: path)
    let two = try await migrated.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    let four = try await migrated.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(two.adopted?.repetitions, [10, 10])
    XCTAssertEqual(four.adopted?.repetitions, [10, 10, 10, 10])
    XCTAssertEqual(four.suggestion?.source?.id, two.suggestion?.source?.id)
  }

  func testUpgradeFailureRollsBackVersionAndEveryFutureGoal() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    try await finish(r)
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE schedule_exercises SET goal_payload=NULL WHERE exercise_id='push-ups'")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=13")
    try db.execute(
      """
      CREATE TRIGGER reject_upgrade BEFORE UPDATE OF goal_payload ON schedule_exercises
      WHEN NEW.schedule_id='push' BEGIN SELECT RAISE(ABORT,'test'); END
      """)
    XCTAssertThrowsError(try SportRepository(path: path))
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 13)
    XCTAssertEqual(
      try db.query("SELECT COUNT(*) AS n FROM schedule_exercises WHERE goal_payload IS NOT NULL")[0]
        .integer("n"), 0)
  }
}

extension LatestExerciseGoalTests {
  func testAddingAndResizingAnAssignmentUsesLastKnownSetRatherThanProgramMinimum() async throws {
    let r = try SportRepository(path: ":memory:")
    let initial = try await r.snapshot()
    var legs = try XCTUnwrap(initial.schedules.first { $0.id == "legs" })
    legs.exerciseIDs = ["push-ups"]
    legs.setCounts = ["push-ups": 2]
    try await r.saveSchedule(legs)
    try await finish(r)
    var pull = try XCTUnwrap(initial.schedules.first { $0.id == "pull-abs" })
    pull.exerciseIDs = ["push-ups"]
    pull.setCounts = ["push-ups": 4]
    try await r.saveSchedule(pull)
    let added = try await r.goalContext(exerciseID: "push-ups", scheduleID: "pull-abs")
    XCTAssertEqual(added.adopted?.repetitions, [10, 10, 10, 10])
    legs.setCounts["push-ups"] = 3
    try await r.saveSchedule(legs)
    let resized = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(resized.adopted?.repetitions, [10, 10, 10])
  }

  func testDecliningLoadIncreaseStillRefreshesPerformanceAtTheSameLoad() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let context = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    var old = try XCTUnwrap(context.suggestion?.goal)
    old.repetitions = [9, 9]
    try await r.saveGoal(old, original: nil, scheduleID: "legs")
    let w = try await r.startWorkout(scheduleID: "legs", now: now)
    let e = try XCTUnwrap(w.currentExercise)
    for n in 1...2 {
      let time = now + n * 200_000
      if let rest = try await r.workout(id: w.id).rest {
        try await r.changeRest(id: rest.id, action: .skip, now: time)
      }
      try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: n, now: time)
      try await r.recordSet(
        workoutID: w.id, exerciseID: e.id, number: n,
        repetitions: 12, weightGrams: 0, now: time + 1000)
    }
    let value = try await r.exerciseLoadGoalDecision(
      workoutID: w.id, exerciseID: e.id,
      feelingTenths: 75, now: now + 600_000)
    let decision = try XCTUnwrap(value)
    try await r.resolveExerciseLoadGoal(decision, update: false, now: now + 600_000)
    let next = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(next.adopted?.load.grams, 0)
    XCTAssertEqual(next.adopted?.repetitions, [12, 12])
    let other = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(other.adopted?.repetitions, [12, 12, 12, 12])
  }
}
