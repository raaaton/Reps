import Foundation
import XCTest

@testable import RepsCore

final class HistoryEditingTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }

  func draft(id: String = UUID().uuidString, time: Int? = nil) -> ManualWorkout {
    ManualWorkout(
      id: id, name: "  Séance passée  ", performedAt: time ?? now - 86_400_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "l-sit", tracking: .duration,
          sets: [ManualWorkoutSet(durationMS: 32_500, weightGrams: 1250)], feelingTenths: 81),
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: [
            ManualWorkoutSet(repetitions: 9, weightGrams: 4500),
            ManualWorkoutSet(repetitions: 8, weightGrams: 4000),
          ], feelingTenths: 73),
      ])
  }

  func file() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
  }

  func testManualWorkoutPersistsOrderedSnapshotsWithoutStartingWorkoutOrChangingPlanning()
    async throws
  {
    let path = file()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let before = try await repository.snapshot()
    let input = draft()
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let reopened = try RepsRepository(path: path)
    let overview = try await reopened.workoutOverview(now: now)
    XCTAssertNil(overview.active)
    XCTAssertEqual(overview.history.count, 1)
    XCTAssertEqual(overview.history.first?.setCount, 3)
    let saved = try await reopened.workout(id: input.id)
    XCTAssertEqual(saved.name, "Séance passée")
    XCTAssertEqual(saved.status, .completed)
    XCTAssertEqual(saved.dayKey, "2026-10-10")
    XCTAssertEqual(saved.startedAt, input.performedAt)
    XCTAssertEqual(saved.endedAt, input.performedAt)
    XCTAssertNil(saved.rest)
    XCTAssertEqual(saved.exercises.map(\.definition.id), ["l-sit", "chin-ups"])
    XCTAssertEqual(saved.exercises.map(\.definition.setCount), [1, 2])
    XCTAssertEqual(saved.exercises[0].sets[0].durationMS, 32_500)
    XCTAssertEqual(saved.exercises[1].sets.map(\.number), [1, 2])
    XCTAssertEqual(saved.exercises[1].sets.map(\.weightGrams), [4500, 4000])
    XCTAssertEqual(saved.exercises.map(\.feelingTenths), [81, 73])
    let after = try await reopened.snapshot()
    XCTAssertEqual(before, after)
    try await reopened.deleteExercise(id: "l-sit")
    let preserved = try await reopened.workout(id: input.id)
    XCTAssertEqual(saved, preserved)
  }

  func testManualEntryAndDeletionLeaveActiveWorkoutUntouchedAndRetryDoesNotDuplicate() async throws
  {
    let repository = try RepsRepository(path: ":memory:")
    let active = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    let input = draft()
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let overview = try await repository.workoutOverview(now: now)
    XCTAssertEqual(overview.active, active)
    XCTAssertEqual(overview.history.map(\.id), [input.id])
    try await repository.deleteHistoricalWorkout(id: input.id)
    try await repository.deleteHistoricalWorkout(id: input.id)
    do {
      try await repository.deleteHistoricalWorkout(id: active.id)
      XCTFail("Deleted an active workout")
    } catch {}
    let after = try await repository.workoutOverview(now: now)
    XCTAssertEqual(after.active, active)
    XCTAssertTrue(after.history.isEmpty)
  }

  func testInvalidManualValuesCannotCreatePartialHistory() async throws {
    let repository = try RepsRepository(path: ":memory:")
    var cases: [ManualWorkout] = []
    var input = draft()
    input.name = " \n "
    cases.append(input)
    input = draft()
    input.id = ""
    cases.append(input)
    input = draft()
    input.performedAt = now + 1
    cases.append(input)
    input = draft()
    input.performedAt = -1
    cases.append(input)
    input = draft()
    input.exercises = []
    cases.append(input)
    input = draft()
    input.exercises.append(input.exercises[0])
    cases.append(input)
    input = draft()
    input.exercises[0].catalogueID = "missing"
    cases.append(input)
    input = draft()
    input.exercises[0].tracking = .repetitions
    cases.append(input)
    input = draft()
    input.exercises[0].sets = []
    cases.append(input)
    for feeling in [-1, 101] {
      input = draft()
      input.exercises[0].feelingTenths = feeling
      cases.append(input)
    }
    for set in [
      ManualWorkoutSet(durationMS: 0, weightGrams: 0),
      ManualWorkoutSet(repetitions: 2, durationMS: 3000, weightGrams: 0),
      ManualWorkoutSet(durationMS: 1000, weightGrams: -1),
      ManualWorkoutSet(repetitions: 2, weightGrams: 0),
    ] {
      input = draft()
      input.exercises[0].sets = [set]
      cases.append(input)
    }
    input = draft()
    input.exercises[1].sets[0].repetitions = 0
    cases.append(input)
    for value in cases {
      do {
        try await repository.addHistoricalWorkout(value, now: now, calendar: calendar)
        XCTFail("Accepted invalid manual workout")
      } catch {}
    }
    let overview = try await repository.workoutOverview(now: now)
    XCTAssertTrue(overview.history.isEmpty)
    XCTAssertNil(overview.active)
  }

  func testManualInsertFailureRollsBackEveryRowAndCanRetry() async throws {
    let path = file()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let database = try SQLiteDatabase(path: path)
    try database.execute(
      "CREATE TRIGGER reject_second BEFORE INSERT ON workout_sets WHEN NEW.number=2 BEGIN SELECT RAISE(ABORT,'test failure'); END"
    )
    let input = draft()
    do {
      try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
      XCTFail("Ignored child insert failure")
    } catch {}
    for table in ["workouts", "workout_exercises", "workout_sets", "workout_rests"] {
      XCTAssertEqual(
        try database.query("SELECT count(*) AS n FROM \(table)").first?.integer("n"), 0)
    }
    try database.execute("DROP TRIGGER reject_second")
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let overview = try await repository.workoutOverview(now: now)
    XCTAssertEqual(overview.history.map(\.id), [input.id])
  }

  func testDeletingCancelledSessionWithRestCascadesOnlyItsRowsAndRollsBackOnFailure() async throws {
    let path = file()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let session = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, repetitions: 10, weightGrams: 0,
      now: now + 1000)
    try await repository.cancelWorkout(id: session.id, now: now + 2000)
    let cancelled = try await repository.workout(id: session.id)
    let input = draft()
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let snapshot = try await repository.snapshot()
    let database = try SQLiteDatabase(path: path)
    try database.execute(
      "CREATE TRIGGER reject_delete BEFORE DELETE ON workouts BEGIN SELECT RAISE(ABORT,'test failure'); END"
    )
    do {
      try await repository.deleteHistoricalWorkout(id: session.id)
      XCTFail("Ignored delete failure")
    } catch {}
    let unchanged = try await repository.workout(id: session.id)
    XCTAssertEqual(unchanged, cancelled)
    XCTAssertEqual(
      try database.query("SELECT count(*) AS n FROM workout_rests").first?.integer("n"), 1)
    try database.execute("DROP TRIGGER reject_delete")
    try await repository.deleteHistoricalWorkout(id: session.id)
    XCTAssertTrue(try database.query("PRAGMA foreign_key_check").isEmpty)
    XCTAssertEqual(
      try database.query("SELECT count(*) AS n FROM workout_rests").first?.integer("n"), 0)
    XCTAssertEqual(
      try database.query("SELECT count(*) AS n FROM workout_sets").first?.integer("n"), 3)
    let overview = try await repository.workoutOverview(now: now + 3000)
    XCTAssertEqual(overview.history.map(\.id), [input.id])
    let after = try await repository.snapshot()
    XCTAssertEqual(after, snapshot)
  }

  func testPreviousPerformanceFallsBackAfterDeletionAndEmptyHistoryStaysEmptyOnReopen() async throws
  {
    let path = file()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let older = draft(time: now - 2 * 86_400_000)
    var newer = draft()
    newer.exercises[1].feelingTenths = 99
    try await repository.addHistoricalWorkout(older, now: now, calendar: calendar)
    try await repository.addHistoricalWorkout(newer, now: now, calendar: calendar)
    let latest = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "other")
    XCTAssertEqual(latest?.feelingTenths, 99)
    try await repository.deleteHistoricalWorkout(id: newer.id)
    let fallback = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "other")
    XCTAssertEqual(fallback?.feelingTenths, 73)
    try await repository.deleteHistoricalWorkout(id: older.id)
    let reopened = try RepsRepository(path: path)
    let overview = try await reopened.workoutOverview(now: now)
    XCTAssertTrue(overview.history.isEmpty)
    let none = try await reopened.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "other")
    XCTAssertNil(none)
  }

  func testManualEntryTodayDoesNotLockPlanningAndCannotOverwriteLiveSession() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let input = draft(time: now)
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let active = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    var collision = draft(id: active.id)
    collision.name = "Replacement"
    do {
      try await repository.addHistoricalWorkout(collision, now: now, calendar: calendar)
      XCTFail("Overwrote an active workout with a manual entry")
    } catch {}
    let unchanged = try await repository.workout(id: active.id)
    XCTAssertEqual(unchanged, active)
    try await repository.deleteExercise(id: "l-sit")
    try await repository.addHistoricalWorkout(input, now: now, calendar: calendar)
    let overview = try await repository.workoutOverview(now: now)
    XCTAssertEqual(overview.history.map(\.id), [input.id])
  }

  func testManualFeelingRequiresExplicitExactValue() throws {
    XCTAssertEqual(try WorkoutFeeling.tenths("5"), 50)
    XCTAssertEqual(try WorkoutFeeling.tenths(" 7,3 "), 73)
    XCTAssertEqual(try WorkoutFeeling.tenths("0"), 0)
    XCTAssertEqual(try WorkoutFeeling.tenths("10.0"), 100)
    for value in ["", " ", "-1", "10,1", "5.01", "NaN", String(Int.max)] {
      XCTAssertThrowsError(try WorkoutFeeling.tenths(value))
    }
  }
}
