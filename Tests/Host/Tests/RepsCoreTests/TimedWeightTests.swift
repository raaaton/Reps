import Foundation
import XCTest

@testable import RepsCore

final class TimedWeightTests: XCTestCase, @unchecked Sendable {
  private let now = 1_791_720_000_000

  private func session(_ repository: RepsRepository) async throws -> WorkoutSession {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let snapshot = try await repository.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await repository.saveSchedule(schedule)
    return try await repository.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
  }

  func testWeightPersistsAcrossReopenAndDuplicateBeginOrFinishDoesNotChangeSet() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let workout = try await session(repository)
    let exercise = try XCTUnwrap(workout.currentExercise)
    let grams = try WorkoutWeight.grams("2,375")
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: grams, now: now)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: 9000, now: now + 1000)
    let reopened = try RepsRepository(path: path)
    let restored = try await reopened.workout(id: workout.id)
    XCTAssertEqual(restored.currentExercise?.setWeightGrams, 2375)
    XCTAssertEqual(restored.currentExercise?.setStartedAt, now + 3000)
    try await reopened.finishTimedSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now + 15_000)
    try await reopened.finishTimedSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now + 25_000)
    let saved = try await reopened.workout(id: workout.id)
    let current = try XCTUnwrap(saved.currentExercise)
    XCTAssertEqual(current.sets.count, 1)
    XCTAssertEqual(current.sets.first?.weightGrams, 2375)
    XCTAssertEqual(current.sets.first?.durationMS, 12_000)
    XCTAssertEqual(current.sets.first?.completedAt, now + 15_000)
    XCTAssertNil(current.setStartedAt)
    XCTAssertNil(current.setWeightGrams)
    XCTAssertNil(current.setEndedAt)
    XCTAssertEqual(saved.rest?.deadline, now + 15_000 + workout.restSeconds * 1000)
  }

  func testCancelledCountdownClearsWeightAndOldCancelCannotEraseReplacement() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let workout = try await session(repository)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: 5000, now: now)
    try await repository.cancelSetCountdown(
      workoutID: workout.id, exerciseID: exercise.id, number: 1,
      expectedStart: now + 3000, now: now + 1000)
    var current = try await repository.workout(id: workout.id)
    XCTAssertNil(current.currentExercise?.setWeightGrams)
    XCTAssertNil(current.currentExercise?.setStartedAt)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: 7500, now: now + 2000)
    try await repository.cancelSetCountdown(
      workoutID: workout.id, exerciseID: exercise.id, number: 1,
      expectedStart: now + 3000, now: now + 2500)
    current = try await repository.workout(id: workout.id)
    XCTAssertEqual(current.currentExercise?.setWeightGrams, 7500)
    XCTAssertEqual(current.currentExercise?.setStartedAt, now + 5000)
    XCTAssertTrue(try XCTUnwrap(current.currentExercise).sets.isEmpty)
    XCTAssertNil(current.rest)
  }

  func testInvalidWeightOrPrematureFinishCannotStartOrRecordASet() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let workout = try await session(repository)
    let exercise = try XCTUnwrap(workout.currentExercise)
    do {
      try await repository.beginSet(
        workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: -1, now: now)
      XCTFail("Negative load accepted")
    } catch {}
    let ready = try await repository.workout(id: workout.id)
    XCTAssertEqual(ready.phase(at: now), .readySet)
    XCTAssertNil(ready.currentExercise?.setWeightGrams)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: 0, now: now)
    for offset in [1000, 2999, 3000] {
      do {
        try await repository.finishTimedSet(
          workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now + offset)
        XCTFail("Countdown or zero duration recorded")
      } catch {}
    }
    let pending = try await repository.workout(id: workout.id)
    XCTAssertEqual(pending.currentExercise?.setWeightGrams, 0)
    XCTAssertTrue(try XCTUnwrap(pending.currentExercise).sets.isEmpty)
    XCTAssertNil(pending.rest)
    try await repository.finishTimedSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now + 10_000)
    let saved = try await repository.workout(id: workout.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.weightGrams, 0)
    XCTAssertEqual(saved.currentExercise?.sets.first?.durationMS, 7000)
    XCTAssertEqual(saved.phase(at: now + 10_000), .resting)
  }

  func testCapturedWeightCannotBeOverwrittenBySavingCaller() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let workout = try await session(repository)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, weightGrams: 1500, now: now)
    try await repository.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1,
      repetitions: nil, weightGrams: 0, now: now + 5000)
    let saved = try await repository.workout(id: workout.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.weightGrams, 1500)
  }

  func testVersionTwoMigrationPreservesActiveSetAndHistoryAndAllowsWeightAfterStop() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let old = try SQLiteDatabase(path: path)
    // Independent fixture of the columns shipped in schema v2, with a running timed set.
    for sql in [
      "CREATE TABLE workouts(id TEXT PRIMARY KEY,schedule_id TEXT,name TEXT,day_key TEXT,started_at INTEGER,ended_at INTEGER,status TEXT,rest_seconds INTEGER)",
      "CREATE TABLE workout_exercises(id TEXT PRIMARY KEY,workout_id TEXT,catalogue_id TEXT,name TEXT,tracking TEXT,set_count INTEGER,minimum_reps INTEGER,maximum_reps INTEGER,duration_seconds INTEGER,position INTEGER,feeling_tenths INTEGER,set_started_at INTEGER)",
      "CREATE TABLE workout_sets(id TEXT PRIMARY KEY,exercise_id TEXT,number INTEGER,repetitions INTEGER,duration_ms INTEGER,weight_grams INTEGER,completed_at INTEGER)",
      "CREATE TABLE workout_rests(id TEXT PRIMARY KEY,workout_id TEXT,exercise_id TEXT,after_set INTEGER,status TEXT,deadline INTEGER,remaining_ms INTEGER)",
      "INSERT INTO workouts VALUES('active','custom','Personnel','2026-10-11',\(now),NULL,'active',180)",
      "INSERT INTO workout_exercises VALUES('timed','active','l-sit','L-sit','duration',3,NULL,NULL,NULL,0,NULL,\(now + 7000))",
      "INSERT INTO workout_sets VALUES('first','timed',1,NULL,1200,1100,\(now + 5000))",
      "INSERT INTO workouts VALUES('past','custom','Ancienne','2026-10-10',\(now - 50_000),\(now - 40_000),'completed',137)",
      "INSERT INTO workout_exercises VALUES('past-ex','past','chin-ups','Ancien nom','repetitions',1,8,12,NULL,0,67,NULL)",
      "INSERT INTO workout_sets VALUES('past-set','past-ex',1,9,NULL,2750,\(now - 40_000))",
      "CREATE TABLE exercises(id TEXT PRIMARY KEY,set_count INTEGER)",
      "CREATE TABLE schedule_exercises(schedule_id TEXT,exercise_id TEXT,position INTEGER)",
      "CREATE TABLE preferences(id INTEGER PRIMARY KEY,rest_seconds INTEGER)",
      "INSERT INTO preferences VALUES(1,180)",
      "PRAGMA user_version=2",
    ] { try old.execute(sql) }
    let repository = try RepsRepository(path: path)
    XCTAssertEqual(try old.query("PRAGMA user_version").first?.integer("user_version"), 18)
    var current = try await repository.workout(id: "active")
    XCTAssertEqual(current.currentExercise?.setStartedAt, now + 7000)
    XCTAssertNil(current.currentExercise?.setWeightGrams)
    XCTAssertEqual(current.currentExercise?.sets.first?.weightGrams, 1100)
    XCTAssertEqual(current.phase(at: now + 10_000), .activeSet)
    let history = try await repository.workout(id: "past")
    XCTAssertEqual(history.name, "Ancienne")
    XCTAssertEqual(history.exercises.first?.definition.name, "Ancien nom")
    XCTAssertEqual(history.exercises.first?.sets.first?.weightGrams, 2750)
    XCTAssertEqual(history.exercises.first?.feelingTenths, 67)
    try await repository.finishTimedSet(
      workoutID: "active", exerciseID: "timed", number: 2, now: now + 10_000)
    let reopened = try RepsRepository(path: path)
    try await reopened.finishTimedSet(
      workoutID: "active", exerciseID: "timed", number: 2, now: now + 20_000)
    current = try await reopened.workout(id: "active")
    XCTAssertEqual(current.phase(at: now + 20_000), .completedSet)
    XCTAssertEqual(current.currentExercise?.setEndedAt, now + 10_000)
    XCTAssertEqual(current.currentExercise?.sets.count, 1)
    XCTAssertNil(current.rest)
    do {
      try await reopened.recordSet(
        workoutID: "active", exerciseID: "timed", number: 2,
        repetitions: nil, weightGrams: 2500, now: now + 9000)
      XCTFail("Weight entry before persisted stop accepted")
    } catch {}
    try await reopened.recordSet(
      workoutID: "active", exerciseID: "timed", number: 2,
      repetitions: nil, weightGrams: 2500, now: now + 40_000)
    current = try await reopened.workout(id: "active")
    XCTAssertEqual(current.currentExercise?.sets.last?.durationMS, 3000)
    XCTAssertEqual(current.currentExercise?.sets.last?.weightGrams, 2500)
    XCTAssertEqual(current.currentExercise?.sets.last?.completedAt, now + 10_000)
    XCTAssertEqual(current.rest?.deadline, now + 190_000)
    XCTAssertNil(current.currentExercise?.setEndedAt)
    XCTAssertNil(current.currentExercise?.setStartedAt)
  }
}
