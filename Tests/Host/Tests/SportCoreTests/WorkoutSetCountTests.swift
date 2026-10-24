import Foundation
import XCTest

@testable import SportCore

final class WorkoutSetCountTests: XCTestCase, @unchecked Sendable {
  let tuesday = 1_791_892_800_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }

  func configure(_ r: SportRepository) async throws {
    let s = try await r.snapshot()
    var t = try XCTUnwrap(s.schedules.first { $0.id == "legs" })
    t.exerciseIDs = ["push-ups"]
    t.setCounts = ["push-ups": 2]
    try await r.saveSchedule(t)
  }

  func testTuesdayTwoSaturdayFourPersistAndFreezeAtStart() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    let reopened = try SportRepository(path: path)
    let s = try await reopened.snapshot()
    let t = try XCTUnwrap(s.schedules.first { $0.id == "legs" })
    let saturday = try XCTUnwrap(s.schedules.first { $0.id == "push" })
    XCTAssertEqual(s.exercises(for: t).map(\.setCount), [2])
    XCTAssertEqual(s.exercises(for: saturday).map(\.setCount), [4, 4])
    let workout = try await reopened.startWorkout(
      scheduleID: t.id, now: tuesday, calendar: calendar)
    var edited = t
    edited.setCounts["push-ups"] = 3
    try await reopened.saveSchedule(edited)
    let active = try await reopened.workout(id: workout.id)
    XCTAssertEqual(active.exercises.first?.definition.setCount, 2)
    try await reopened.cancelWorkout(id: workout.id, now: tuesday + 1000)
    let next = try await reopened.startWorkout(
      scheduleID: saturday.id, now: tuesday + 4 * 86_400_000, calendar: calendar)
    XCTAssertEqual(next.exercises.map(\.definition.setCount), [4, 4])
  }

  func testInvalidCountsRollBackWholeWorkoutEdit() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let before = try await r.snapshot()
    for count in [0, -1, 1001] {
      var t = before.schedules[0]
      t.name = "Should not save"
      t.setCounts["push-ups"] = count
      do {
        try await r.saveSchedule(t)
        XCTFail("Accepted \(count)")
      } catch {}
      let after = try await r.snapshot()
      XCTAssertEqual(after, before)
    }
  }

  func testGoalsUseWorkoutCountAndCompletionSharesLatestExercise() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    var goal = try XCTUnwrap(c.suggestion?.goal)
    goal.repetitions = [10, 9]
    try await r.saveGoal(goal, original: nil, scheduleID: "legs")
    let saturday = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(saturday.exercise.setCount, 4)
    XCTAssertNil(saturday.adopted)
    let w = try await r.startWorkout(scheduleID: "legs", now: tuesday, calendar: calendar)
    XCTAssertEqual(w.exercises.first?.goal?.repetitions, [10, 9])
    let e = try XCTUnwrap(w.currentExercise)
    for number in 1...2 {
      let now = tuesday + number * 200_000
      if number == 2 {
        let current = try await r.workout(id: w.id)
        try await r.changeRest(id: XCTUnwrap(current.rest?.id), action: .skip, now: now)
      }
      try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: number, now: now)
      try await r.recordSet(
        workoutID: w.id, exerciseID: e.id, number: number,
        repetitions: 9, weightGrams: 0, now: now + 1000)
    }
    let recorded = try await r.workout(id: w.id)
    XCTAssertEqual(recorded.phase, .feeling)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 85, now: tuesday + 402_000)
    let complete = try await r.workout(id: w.id)
    XCTAssertEqual(complete.status, .completed)
    let nextTuesday = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    let nextSaturday = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertEqual(nextTuesday.adopted?.repetitions, [9, 9])
    XCTAssertEqual(nextSaturday.adopted?.repetitions, [9, 9, 9, 9])
    XCTAssertEqual(nextSaturday.suggestion?.goal.repetitions, [9, 9, 9, 9])
  }

  func testArchiveRoundTripPreservesWorkoutCountsAndGoals() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    try await r.saveGoal(XCTUnwrap(c.suggestion?.goal), original: nil, scheduleID: "legs")
    let archive = try await r.exportTraining(now: tuesday)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let target = try SportRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: tuesday)
    try await target.applyTrainingImport(preview, now: tuesday)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored, archive.contents.configuration)
    let t = try XCTUnwrap(restored.schedules.first { $0.id == "legs" })
    XCTAssertEqual(restored.exercises(for: t).first?.setCount, 2)
    let goal = try await target.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(goal.adopted?.repetitions, [8, 8])
  }
}

extension WorkoutSetCountTests {
  func testMigrationTenCopiesCountsAndGoalsWithoutChangingActiveWorkout() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let before = try await r.snapshot()
    var definition = try XCTUnwrap(before.exercises.first { $0.id == "bulgarians" })
    definition.setCount = 3
    try await r.saveExercise(definition)
    let legacyGoal = ExerciseGoal(
      definition: definition, load: .bodyweight, repetitions: [9, 8, 8])
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "INSERT INTO exercise_goals VALUES(?,?)",
      [.text(definition.id), try ExerciseGoal.encode(legacyGoal)])
    let active = try await r.startWorkout(scheduleID: "legs", now: tuesday, calendar: calendar)
    try db.execute("ALTER TABLE schedule_exercises DROP COLUMN goal_payload")
    try db.execute("ALTER TABLE schedule_exercises DROP COLUMN set_count")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=10")
    let reopened = try SportRepository(path: path)
    let migrated = try await reopened.snapshot()
    let legs = try XCTUnwrap(migrated.schedules.first { $0.id == "legs" })
    XCTAssertEqual(migrated.exercises(for: legs).first?.setCount, 3)
    XCTAssertEqual(legs.goals["bulgarians"], legacyGoal)
    let restored = try await reopened.workout(id: active.id)
    XCTAssertEqual(restored, active)
    try await reopened.cancelWorkout(id: active.id, now: tuesday + 1000)
    let next = try await reopened.startWorkout(
      scheduleID: "legs", now: tuesday + 2000, calendar: calendar)
    XCTAssertEqual(next.currentExercise?.goal, legacyGoal)
    XCTAssertEqual(next.currentExercise?.definition.setCount, 3)
  }

  func testLegacyArchiveRestoresAssignmentCountsAndGoals() async throws {
    let r = try SportRepository(path: ":memory:")
    var archive = try await r.exportTraining(now: tuesday)
    let exercise = try XCTUnwrap(
      archive.contents.configuration.exercises.first { $0.id == "push-ups" })
    let goal = ExerciseGoal(definition: exercise, load: .bodyweight, repetitions: [10, 9, 8, 8])
    archive.contents.configuration.goals = [goal]
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
    root["version"] = 1
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var configuration = try XCTUnwrap(contents["configuration"] as? [String: Any])
    var schedules = try XCTUnwrap(configuration["schedules"] as? [[String: Any]])
    for index in schedules.indices {
      schedules[index].removeValue(forKey: "setCounts")
      schedules[index].removeValue(forKey: "goals")
    }
    configuration["schedules"] = schedules
    contents["configuration"] = configuration
    root["contents"] = contents
    let decoded = try TrainingArchive.decode(
      JSONSerialization.data(withJSONObject: removingNewSkillFields(root)))
    let target = try SportRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: tuesday)
    try await target.applyTrainingImport(preview, now: tuesday)
    let restored = try await target.goalContext(exerciseID: exercise.id, scheduleID: "push")
    XCTAssertEqual(restored.exercise.setCount, 4)
    XCTAssertEqual(restored.adopted?.repetitions, [10, 9, 8, 8])
  }

  func testResizeKeepsExistingTargetsAndRejectsStaleGoalEditor() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    var goal = try XCTUnwrap(c.suggestion?.goal)
    goal.repetitions = [10, 9]
    try await r.saveGoal(goal, original: nil, scheduleID: "legs")
    let snapshot = try await r.snapshot()
    var t = try XCTUnwrap(snapshot.schedules.first { $0.id == "legs" })
    t.setCounts["push-ups"] = 3
    try await r.saveSchedule(t)
    let expanded = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(expanded.adopted?.repetitions, [10, 9, 9])
    do {
      try await r.saveGoal(goal, original: goal, scheduleID: "legs")
      XCTFail("A stale two-set editor overwrote the three-set goal")
    } catch {}
    t.setCounts["push-ups"] = 1
    try await r.saveSchedule(t)
    let reduced = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertEqual(reduced.adopted?.repetitions, [10])
    let w = try await r.startWorkout(scheduleID: "legs", now: tuesday, calendar: calendar)
    XCTAssertEqual(w.currentExercise?.goal?.repetitions, [10])
  }

  func testScheduleFailureKeepsCountsAndGoalsAtomically() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    let c = try await r.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    try await r.saveGoal(XCTUnwrap(c.suggestion?.goal), original: nil, scheduleID: "legs")
    let before = try await r.snapshot()
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER reject_assignment BEFORE INSERT ON schedule_exercises BEGIN SELECT RAISE(ABORT,'test'); END"
    )
    var t = before.schedules[0]
    t.setCounts["push-ups"] = 3
    t.name = "Must roll back"
    do {
      try await r.saveSchedule(t)
      XCTFail("Ignored SQL failure")
    } catch {}
    let after = try await r.snapshot()
    XCTAssertEqual(after, before)
  }

  func testCatalogueEditsAndReorderingNeverChangeWorkoutCounts() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r)
    var s = try await r.snapshot()
    var exercise = try XCTUnwrap(s.exercises.first { $0.id == "push-ups" })
    exercise.name = "Renamed"
    exercise.setCount = 6  // Legacy field cannot be the source of future workout counts.
    try await r.saveExercise(exercise)
    s = try await r.snapshot()
    var saturday = try XCTUnwrap(s.schedules.first { $0.id == "push" })
    saturday.exerciseIDs.reverse()
    try await r.saveSchedule(saturday)
    s = try await r.snapshot()
    let t = try XCTUnwrap(s.schedules.first { $0.id == "legs" })
    XCTAssertEqual(s.exercises(for: t).map(\.setCount), [2])
    let sat = try XCTUnwrap(s.schedules.first { $0.id == "push" })
    XCTAssertEqual(s.exercises(for: sat).map(\.setCount), [4, 4])
    XCTAssertEqual(s.exercises(for: sat).map(\.id), ["pike-push-ups", "push-ups"])
    try await r.deleteExercise(id: "push-ups")
    let deleted = try await r.snapshot()
    XCTAssertFalse(
      deleted.schedules.contains { $0.setCounts["push-ups"] != nil || $0.goals["push-ups"] != nil })
  }
}

extension WorkoutSetCountTests {
  func testLegacyDuplicateAssignmentsAreRejectedWithoutTrapping() async throws {
    let r = try SportRepository(path: ":memory:")
    var archive = try await r.exportTraining(now: tuesday)
    archive.version = 1
    archive.contents.configuration.schedules[0].exerciseIDs = ["bulgarians", "bulgarians"]
    XCTAssertThrowsError(try TrainingArchive.decode(JSONEncoder().encode(archive)))
  }

  func testStaleLegacyGoalRemainsExportableAndIsReconciledOnRestore() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await configure(r)
    let s = try await r.snapshot()
    let definition = try XCTUnwrap(s.exercises.first { $0.id == "push-ups" })
    let stale = ExerciseGoal(definition: definition, load: .bodyweight, repetitions: [9, 9, 8, 8])
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "UPDATE schedule_exercises SET goal_payload=? WHERE schedule_id='legs'",
      [try ExerciseGoal.encode(stale)])
    let archive = try await r.exportTraining(now: tuesday)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let destination = try SportRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: tuesday)
    try await destination.applyTrainingImport(preview, now: tuesday)
    let context = try await destination.goalContext(exerciseID: "push-ups", scheduleID: "legs")
    XCTAssertTrue(context.isAvailable)
    XCTAssertEqual(context.adopted?.repetitions, [9, 9])
    XCTAssertEqual(context.adopted?.definition.setCount, 2)
    let started = try await destination.startWorkout(
      scheduleID: "legs", now: tuesday, calendar: calendar)
    XCTAssertEqual(started.currentExercise?.goal?.repetitions, [9, 9])
  }
}
