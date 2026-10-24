import Foundation
import XCTest

@testable import RepsCore

final class GoalReconciliationTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_892_800_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }

  private func assign(_ r: RepsRepository, id: String, workout: String, count: Int) async throws {
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == workout })
    schedule.exerciseIDs = [id]
    schedule.setCounts = [id: count]
    try await r.saveSchedule(schedule)
  }

  private func adopt(
    _ r: RepsRepository, id: String, workout: String, reps: [Int]? = nil, grams: Int = 0
  ) async throws -> ExerciseGoal {
    let c = try await r.goalContext(exerciseID: id, scheduleID: workout)
    let items = try await r.snapshot().weightItems
    let load = try XCTUnwrap(WeightInventory.loads(items: items).first { $0.grams == grams })
    let goal = ExerciseGoal(definition: c.exercise, load: load, repetitions: reps)
    try await r.saveGoal(goal, original: c.adopted, scheduleID: workout)
    return goal
  }

  func testAcceptedRangeEditUpdatesEveryWorkoutAndPreservesActiveSnapshot() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await assign(r, id: "push-ups", workout: "legs", count: 2)
    _ = try await adopt(r, id: "push-ups", workout: "legs", reps: [8, 12], grams: 3000)
    _ = try await adopt(r, id: "push-ups", workout: "push", reps: [9, 9, 10, 11])
    let active = try await r.startWorkout(scheduleID: "legs", now: now, calendar: calendar)
    var exercise = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs").exercise
    exercise.minimumReps = 10
    exercise.maximumReps = 11
    try await r.saveExercise(exercise)
    let reopened = try RepsRepository(path: path)
    let tuesday = try await reopened.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    let saturday = try await reopened.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertTrue(tuesday.isAvailable)
    XCTAssertTrue(saturday.isAvailable)
    XCTAssertEqual(tuesday.adopted?.repetitions, [10, 11])
    XCTAssertEqual(saturday.adopted?.repetitions, [10, 10, 10, 11])
    XCTAssertEqual(tuesday.adopted?.load.grams, 3000)
    let unchanged = try await reopened.workout(id: active.id)
    XCTAssertEqual(unchanged, active)
  }

  func testTrackingAndDurationChangesAreAcceptedWithoutChoosingTheGoalAgain() async throws {
    let r = try RepsRepository(path: ":memory:")
    let original = try await adopt(
      r, id: "push-ups", workout: "push", reps: [9, 10, 11, 12], grams: 3000)
    var exercise = original.definition
    exercise.tracking = .duration
    exercise.durationSeconds = 45
    try await r.saveExercise(exercise)
    var c = try await r.goalContext(exerciseID: exercise.id, scheduleID: "push")
    XCTAssertTrue(c.isAvailable)
    XCTAssertNil(c.adopted?.repetitions)
    XCTAssertEqual(c.adopted?.definition.durationSeconds, 45)
    XCTAssertEqual(c.adopted?.load, original.load)
    exercise.durationSeconds = nil
    try await r.saveExercise(exercise)
    c = try await r.goalContext(exerciseID: exercise.id, scheduleID: "push")
    XCTAssertTrue(c.isAvailable)
    XCTAssertNil(c.adopted?.definition.durationSeconds)
    exercise.tracking = .repetitions
    exercise.minimumReps = 6
    exercise.maximumReps = 9
    try await r.saveExercise(exercise)
    c = try await r.goalContext(exerciseID: exercise.id, scheduleID: "push")
    XCTAssertTrue(c.isAvailable)
    XCTAssertEqual(c.adopted?.repetitions, [6, 6, 6, 6])
  }

  func testTimedGoalEditAlsoUpdatesOtherWorkoutsWithoutChangingTheirLoadsOrCounts() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await assign(r, id: "l-sit", workout: "legs", count: 2)
    let other = try await adopt(r, id: "l-sit", workout: "legs", grams: 3000)
    let current = try await adopt(r, id: "l-sit", workout: "pull-abs")
    var target = current.definition
    target.durationSeconds = 30
    try await r.saveTimedGoal(
      ExerciseGoal(definition: target, load: current.load, repetitions: nil),
      original: current, originalExercise: current.definition, scheduleID: "pull-abs")
    let result = try await r.goalContext(exerciseID: "l-sit", scheduleID: "legs")
    XCTAssertTrue(result.isAvailable)
    XCTAssertEqual(result.adopted?.definition.durationSeconds, 30)
    XCTAssertEqual(result.adopted?.definition.setCount, 2)
    XCTAssertEqual(result.adopted?.load, other.load)
  }

  func testUnavailableCompositionStillRequiresReviewAfterExerciseEdit() async throws {
    let r = try RepsRepository(path: ":memory:")
    let goal = try await adopt(r, id: "push-ups", workout: "push", reps: [9, 9, 9, 9], grams: 3900)
    let items = try await r.snapshot().weightItems
    var item = try XCTUnwrap(items.first { $0.id == "river-book" })
    item.name = "Renamed item"
    try await r.saveWeightItem(item)
    var target = goal.definition
    target.minimumReps = 10
    try await r.saveExercise(target)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertFalse(c.isAvailable)
    XCTAssertTrue(try XCTUnwrap(c.adopted).isCompatible(with: c.exercise))
    XCTAssertEqual(c.adopted?.load, goal.load)
    XCTAssertEqual(c.adopted?.repetitions, [10, 10, 10, 10])
  }

  func testGoalWriteFailureRollsBackTheAcceptedExerciseEdit() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let goal = try await adopt(r, id: "push-ups", workout: "push", reps: [9, 9, 9, 9])
    let before = try await r.snapshot()
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER reject_reconcile BEFORE UPDATE OF goal_payload ON schedule_exercises BEGIN SELECT RAISE(ABORT,'test'); END"
    )
    var target = goal.definition
    target.minimumReps = 10
    do {
      try await r.saveExercise(target)
      XCTFail("Goal failure must roll back the catalogue edit")
    } catch {}
    let after = try await r.snapshot()
    XCTAssertEqual(after, before)
  }

  func testMigrationAcceptsPreviouslyChangedExerciseButPreservesActiveWorkout() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let old = try await adopt(r, id: "bulgarians", workout: "legs", reps: [8, 9, 10, 12])
    let active = try await r.startWorkout(scheduleID: "legs", now: now, calendar: calendar)
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE exercises SET minimum_reps=10,maximum_reps=11 WHERE id='bulgarians'")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=12")
    let reopened = try RepsRepository(path: path)
    let c = try await reopened.goalContext(exerciseID: "bulgarians", scheduleID: "legs")
    XCTAssertTrue(c.isAvailable)
    XCTAssertEqual(c.adopted?.repetitions, [10, 10, 10, 11])
    XCTAssertEqual(c.adopted?.load, old.load)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 18)
    let unchanged = try await reopened.workout(id: active.id)
    XCTAssertEqual(unchanged, active)
  }

  func testProgressShowsReviewIfAnyAssignedCompositionIsMissingEvenWithAnotherValidMainGoal()
    async throws
  {
    let r = try RepsRepository(path: ":memory:")
    try await assign(r, id: "push-ups", workout: "legs", count: 2)
    _ = try await adopt(r, id: "push-ups", workout: "legs", reps: [8, 8], grams: 3900)
    let main = try await adopt(
      r, id: "push-ups", workout: "push", reps: [12, 12, 12, 12], grams: 3000)
    var s = try await r.snapshot()
    XCTAssertEqual(s.primaryGoal(for: main.definition), main)
    XCTAssertFalse(
      s.needsGoalReview(
        for: main.definition, availableLoads: try WeightInventory.loads(items: s.weightItems)))
    var item = try XCTUnwrap(s.weightItems.first { $0.id == "river-book" })
    item.name = "New composition name"
    try await r.saveWeightItem(item)
    s = try await r.snapshot()
    let loads = try WeightInventory.loads(items: s.weightItems)
    XCTAssertTrue(s.needsGoalReview(for: main.definition, availableLoads: loads))
    XCTAssertEqual(s.primaryGoal(for: main.definition), main)
    var legs = try XCTUnwrap(s.schedules.first { $0.id == "legs" })
    legs.isEnabled = false
    legs.exerciseIDs = []
    try await r.saveSchedule(legs)
    s = try await r.snapshot()
    XCTAssertFalse(s.needsGoalReview(for: main.definition, availableLoads: loads))
  }

  func testMigrationWriteFailureKeepsPreviousVersionAndGoal() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let old = try await adopt(r, id: "push-ups", workout: "push", reps: [8, 9, 10, 12])
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE exercises SET minimum_reps=10 WHERE id='push-ups'")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=12")
    try db.execute(
      "CREATE TRIGGER reject_migration BEFORE UPDATE OF goal_payload ON schedule_exercises BEGIN SELECT RAISE(ABORT,'test'); END"
    )
    XCTAssertThrowsError(try RepsRepository(path: path))
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 12)
    let row = try XCTUnwrap(
      db.query(
        "SELECT goal_payload FROM schedule_exercises WHERE schedule_id='push' AND exercise_id='push-ups'"
      ).first)
    XCTAssertEqual(try ExerciseGoal.decode(row.text("goal_payload")), old)
  }

  func testNameOnlyEditPreservesCustomRepetitionsAndDoesNotCreateMissingGoals() async throws {
    let r = try RepsRepository(path: ":memory:")
    let original = try await adopt(r, id: "push-ups", workout: "push", reps: [20, 19, 18, 17])
    var renamed = original.definition
    renamed.name = "New name"
    try await r.saveExercise(renamed)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(c.adopted?.repetitions, [20, 19, 18, 17])
    XCTAssertTrue(c.isAvailable)
    let snapshot = try await r.snapshot()
    XCTAssertNil(snapshot.schedules.first { $0.id == "legs" }?.goals["bulgarians"])
  }
}
