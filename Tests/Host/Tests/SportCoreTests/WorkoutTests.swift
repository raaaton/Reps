import Foundation
import XCTest

@testable import SportCore

final class WorkoutTests: XCTestCase, @unchecked Sendable {
  // Sunday 11 October 2026, in UTC. Real clock-independent persisted timestamps.
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }

  func path() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
  }

  func start(_ repository: SportRepository, sets: Int = 2) async throws -> WorkoutSession {
    let snapshot = try await repository.snapshot()
    for var exercise in snapshot.exercises where ["chin-ups", "l-sit"].contains(exercise.id) {
      exercise.setCount = sets
      try await repository.saveExercise(exercise)
    }
    return try await repository.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
  }

  func record(_ repository: SportRepository, _ session: WorkoutSession, time: Int) async throws {
    let exercise = try XCTUnwrap(session.currentExercise)
    let number = exercise.sets.count + 1
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: number, now: time)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: number,
      repetitions: exercise.definition.tracking == .repetitions ? 10 : nil,
      weightGrams: 4500, now: time + 12_300)
  }

  func testStartResumeSnapshotsAndLocalDayValidation() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository)
    XCTAssertEqual(session.phase, .readySet)
    XCTAssertEqual(session.exercises.map(\.definition.id), ["chin-ups", "l-sit"])
    XCTAssertEqual(session.dayKey, "2026-10-11")
    var exercise = (try await repository.snapshot()).exercises[3]
    exercise.name = "Changed catalogue"
    try await repository.saveExercise(exercise)
    let resumed = try await repository.startWorkout(
      scheduleID: "legs", now: now + 86_400_000, calendar: calendar)
    XCTAssertEqual(resumed, session, "An active session from yesterday must resume globally")
    try await repository.cancelWorkout(id: session.id, now: now + 1000)
    do {
      _ = try await repository.startWorkout(scheduleID: "legs", now: now, calendar: calendar)
      XCTFail("Started a different weekday")
    } catch {}
    let next = try await start(repository)
    XCTAssertEqual(next.exercises.first?.definition.name, "Changed catalogue")
  }

  func testCompleteSetsFeelingAndDailyRestartPreserveHistory() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository, sets: 1)
    try await record(repository, session, time: now)
    var current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase, .feeling, "Feeling remains available during transition rest")
    let first = try XCTUnwrap(current.currentExercise)
    XCTAssertEqual(first.sets.first?.repetitions, 10)
    try await repository.saveFeeling(
      workoutID: session.id, exerciseID: first.id, tenths: 73, now: now + 13_000)
    current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase, .resting)
    try await repository.changeRest(
      id: try XCTUnwrap(current.rest?.id), action: .skip, now: now + 13_500)
    current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase, .readySet)
    XCTAssertEqual(current.currentExercise?.definition.tracking, .duration)
    try await record(repository, current, time: now + 14_000)
    current = try await repository.workout(id: session.id)
    let last = try XCTUnwrap(current.currentExercise)
    XCTAssertEqual(last.sets.first?.durationMS, 9_300)
    try await repository.saveFeeling(
      workoutID: session.id, exerciseID: last.id, tenths: 100, now: now + 27_000)
    let complete = try await repository.workout(id: session.id)
    XCTAssertEqual(complete.phase, .completed)
    XCTAssertNotNil(complete.endedAt)
    do {
      _ = try await repository.startWorkout(
        scheduleID: "pull-abs", now: now + 30_000, calendar: calendar)
      XCTFail("Bypassed same-day lock")
    } catch {}
    let restarted = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now + 31_000, calendar: calendar, restart: true)
    XCTAssertNotEqual(restarted.id, session.id)
    let overview = try await repository.workoutOverview(now: now + 32_000)
    XCTAssertEqual(overview.history.map(\.id), [session.id])
    XCTAssertEqual(overview.active?.id, restarted.id)
    let previous = try await repository.previousPerformance(
      exerciseID: "l-sit", excludingWorkoutID: restarted.id)
    XCTAssertEqual(previous?.sets.first?.durationMS, 9_300)
    XCTAssertEqual(previous?.feelingTenths, 100)
  }

  func testTimerPauseResumeReopenExpiryAndStaleAction() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let repository = try SportRepository(path: file)
    let session = try await start(repository)
    try await record(repository, session, time: now)
    var current = try await repository.workout(id: session.id)
    let rest = try XCTUnwrap(current.rest)
    XCTAssertEqual(current.phase, .resting)
    XCTAssertEqual(rest.remaining(at: now + 22_300), 170_000)
    try await repository.changeRest(id: rest.id, action: .pause, now: now + 22_300)
    try await repository.changeRest(id: rest.id, action: .pause, now: now + 40_000)
    let reopened = try SportRepository(path: file)
    current = try await reopened.workout(id: session.id)
    XCTAssertEqual(current.rest?.remaining(at: now + 900_000), 170_000)
    try await reopened.changeRest(id: rest.id, action: .resume, now: now + 900_000)
    try await reopened.changeRest(id: rest.id, action: .resume, now: now + 950_000)
    let before = try await reopened.workoutOverview(now: now + 1_069_999)
    XCTAssertEqual(before.active?.phase, .resting)
    let expired = try await reopened.workoutOverview(now: now + 1_070_000)
    XCTAssertEqual(expired.active?.phase, .readySet)
    XCTAssertEqual(expired.expiredRestIDs, [rest.id])
    let again = try await reopened.workoutOverview(now: now + 1_070_001)
    XCTAssertTrue(again.expiredRestIDs.isEmpty, "Completion feedback is claimed once")
    try await record(reopened, try XCTUnwrap(expired.active), time: now + 1_080_000)
    current = try await reopened.workout(id: session.id)
    XCTAssertEqual(current.phase, .feeling)
    try await reopened.changeRest(id: rest.id, action: .skip, now: now + 1_100_000)
    let unchanged = try await reopened.workout(id: session.id)
    XCTAssertEqual(unchanged, current)
  }

  func testDuplicateAndWrongSetActionsCannotAdvanceFlow() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now + 1000)
    let started = try await repository.workout(id: session.id)
    XCTAssertEqual(started.currentExercise?.setStartedAt, now)
    do {
      try await repository.recordSet(
        workoutID: session.id, exerciseID: exercise.id, number: 2, repetitions: 10, weightGrams: 0,
        now: now + 2000)
      XCTFail("Accepted stale/wrong index")
    } catch {}
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, repetitions: 10, weightGrams: 0,
      now: now + 2000)
    let saved = try await repository.workout(id: session.id)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, repetitions: 15, weightGrams: 9000,
      now: now + 3000)
    let duplicate = try await repository.workout(id: session.id)
    XCTAssertEqual(duplicate, saved)
    do {
      try await repository.beginSet(
        workoutID: session.id, exerciseID: exercise.id, number: 2, now: now + 4000)
      XCTFail("Started during rest")
    } catch {}
  }

  func testSkipAndCancelPreserveSetsAndConfigurationDeletionDoesNotAffectSession() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository)
    try await record(repository, session, time: now)
    let resting = try await repository.workout(id: session.id)
    let rest = try XCTUnwrap(resting.rest)
    try await repository.changeRest(id: rest.id, action: .skip, now: now + 13_000)
    try await repository.deleteExercise(id: "chin-ups")
    try await repository.deleteSchedule(id: "pull-abs")
    let preserved = try await repository.workout(id: session.id)
    XCTAssertEqual(preserved.phase, .readySet)
    XCTAssertEqual(preserved.exercises.map(\.definition.id), ["chin-ups", "l-sit"])
    try await repository.cancelWorkout(id: session.id, now: now + 14_000)
    try await repository.cancelWorkout(id: session.id, now: now + 15_000)
    let cancelled = try await repository.workout(id: session.id)
    XCTAssertEqual(cancelled.phase, .cancelled)
    XCTAssertEqual(cancelled.exercises.first?.sets.count, 1)
    let previous = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "other")
    XCTAssertNil(previous)
    let overview = try await repository.workoutOverview(now: now + 20_000)
    XCTAssertNil(overview.active)
    XCTAssertEqual(overview.history.first?.status, .cancelled)
  }

  func testInvalidValuesAndExtremeRestDoNotChangeActiveSet() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    let before = try await repository.workout(id: session.id)
    for (reps, weight) in [(0, 0), (-1, 0), (10, -1)] {
      do {
        try await repository.recordSet(
          workoutID: session.id, exerciseID: exercise.id, number: 1, repetitions: reps,
          weightGrams: weight, now: now + 1000)
        XCTFail("Accepted invalid performance")
      } catch {}
    }
    do {
      try await repository.saveFeeling(
        workoutID: session.id, exerciseID: exercise.id, tenths: 75, now: now + 1000)
      XCTFail("Accepted Feeling before all sets")
    } catch {}
    let after = try await repository.workout(id: session.id)
    XCTAssertEqual(before, after)
    try await repository.cancelWorkout(id: session.id, now: now + 2000)
    try await repository.saveRest(seconds: Int.max)
    do {
      _ = try await repository.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
      XCTFail("Accepted overflowing rest")
    } catch {}
    XCTAssertEqual(try WorkoutWeight.grams("4,125"), 4125)
    XCTAssertEqual(try WorkoutWeight.grams("0"), 0)
    XCTAssertEqual(try WorkoutWeight.grams(" 3.5 "), 3500)
    for input in ["-1", "NaN", "1.2345", "1,2.3", "1e5", String(Int.max), ""] {
      XCTAssertThrowsError(try WorkoutWeight.grams(input), input)
    }
  }

  func testFailureCreatingRestRollsBackRecordedSetAndPreservesStart() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let repository = try SportRepository(path: file)
    let session = try await start(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    let before = try await repository.workout(id: session.id)
    let injection = try SQLiteDatabase(path: file)
    try injection.execute(
      "CREATE TRIGGER reject_rest BEFORE INSERT ON workout_rests BEGIN SELECT RAISE(ABORT,'test failure'); END"
    )
    do {
      try await repository.recordSet(
        workoutID: session.id, exerciseID: exercise.id, number: 1, repetitions: 12, weightGrams: 0,
        now: now + 1000)
      XCTFail("Accepted database failure")
    } catch {}
    let after = try await repository.workout(id: session.id)
    XCTAssertEqual(before, after)
  }

  func testVersionOneMigrationPreservesCustomizedConfiguration() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let old = try SQLiteDatabase(path: file)
    // Independent fixture with the columns shipped by milestone 2, not a copy of the migrator.
    for sql in [
      "CREATE TABLE exercises(id TEXT PRIMARY KEY,name TEXT,tracking TEXT,set_count INTEGER,minimum_reps INTEGER,maximum_reps INTEGER,duration_seconds INTEGER,enabled INTEGER,position INTEGER)",
      "CREATE TABLE schedules(id TEXT PRIMARY KEY,name TEXT,weekday INTEGER,enabled INTEGER,reminder_minutes INTEGER)",
      "CREATE TABLE schedule_exercises(schedule_id TEXT,exercise_id TEXT,position INTEGER)",
      "CREATE TABLE preferences(id INTEGER PRIMARY KEY,rest_seconds INTEGER)",
      "INSERT INTO exercises VALUES('custom','Personnel','duration',3,NULL,NULL,42,1,0)",
      "INSERT INTO schedules VALUES('mine','Maison',7,1,410)",
      "INSERT INTO schedule_exercises VALUES('mine','custom',0)",
      "INSERT INTO preferences VALUES(1,137)",
      "PRAGMA user_version=1",
    ] { try old.execute(sql) }
    let upgraded = try SportRepository(path: file)
    let snapshot = try await upgraded.snapshot()
    XCTAssertEqual(snapshot.exercises.count, 1)
    XCTAssertEqual(snapshot.exercises.first?.durationSeconds, 42)
    XCTAssertEqual(snapshot.schedules.first?.name, "Maison")
    XCTAssertEqual(snapshot.schedules.first?.reminderMinutes, 410)
    XCTAssertEqual(snapshot.restSeconds, 137)
    let session = try await upgraded.startWorkout(scheduleID: "mine", now: now, calendar: calendar)
    XCTAssertEqual(session.exercises.first?.definition.name, "Personnel")
    XCTAssertEqual(try old.query("PRAGMA user_version").first?.integer("user_version"), 10)
  }
  func testTimedSetSurvivesReopenAndRejectsClockReversal() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let repository = try SportRepository(path: file)
    let session = try await start(repository, sets: 1)
    try await record(repository, session, time: now)
    var current = try await repository.workout(id: session.id)
    let first = try XCTUnwrap(current.currentExercise)
    try await repository.saveFeeling(
      workoutID: session.id, exerciseID: first.id, tenths: 0, now: now + 13_000)
    current = try await repository.workout(id: session.id)
    let timed = try XCTUnwrap(current.currentExercise)
    try await repository.changeRest(
      id: try XCTUnwrap(current.rest?.id), action: .skip, now: now + 13_500)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: timed.id, number: 1, now: now + 14_000)
    let reopened = try SportRepository(path: file)
    let restored = try await reopened.workout(id: session.id)
    XCTAssertEqual(restored.phase(at: now + 16_999), .countdown)
    XCTAssertEqual(restored.phase(at: now + 17_000), .activeSet)
    XCTAssertEqual(restored.currentExercise?.setStartedAt, now + 17_000)
    for time in [now + 13_000, now + 14_000] {
      do {
        try await reopened.recordSet(
          workoutID: session.id, exerciseID: timed.id, number: 1, repetitions: nil, weightGrams: 0,
          now: time)
        XCTFail("Accepted nonpositive timed duration")
      } catch {}
    }
    try await reopened.recordSet(
      workoutID: session.id, exerciseID: timed.id, number: 1, repetitions: nil, weightGrams: 0,
      now: now + 54_125)
    for value in [-1, 101] {
      do {
        try await reopened.saveFeeling(
          workoutID: session.id, exerciseID: timed.id, tenths: value, now: now + 55_000)
        XCTFail("Accepted invalid Feeling")
      } catch {}
    }
    try await reopened.saveFeeling(
      workoutID: session.id, exerciseID: timed.id, tenths: 85, now: now + 55_000)
    try await reopened.saveFeeling(
      workoutID: session.id, exerciseID: timed.id, tenths: 90, now: now + 56_000)
    let finished = try await reopened.workout(id: session.id)
    XCTAssertEqual(finished.exercises.last?.sets.first?.durationMS, 37_100)
    XCTAssertEqual(finished.exercises.last?.feelingTenths, 85)
  }

  func testOldRestActionCannotSkipNewRestAndCancelStopsExpiry() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await start(repository, sets: 3)
    try await record(repository, session, time: now)
    var current = try await repository.workout(id: session.id)
    let oldRest = try XCTUnwrap(current.rest)
    try await repository.changeRest(id: oldRest.id, action: .skip, now: now + 13_000)
    current = try await repository.workout(id: session.id)
    try await record(repository, current, time: now + 14_000)
    let before = try await repository.workout(id: session.id)
    let newRest = try XCTUnwrap(before.rest)
    XCTAssertNotEqual(oldRest.id, newRest.id)
    for action: RestAction in [.pause, .resume, .skip] {
      try await repository.changeRest(id: oldRest.id, action: action, now: now + 28_000)
    }
    let after = try await repository.workout(id: session.id)
    XCTAssertEqual(after, before)
    try await repository.cancelWorkout(id: session.id, now: now + 30_000)
    let overview = try await repository.workoutOverview(now: now + 999_000)
    XCTAssertTrue(overview.expiredRestIDs.isEmpty)
    XCTAssertNil(overview.active)
    let cancelled = try await repository.workout(id: session.id)
    XCTAssertNil(cancelled.rest)
    XCTAssertEqual(cancelled.exercises.first?.sets.count, 2)
  }

  func testConcurrentStartsAcrossConnectionsReturnOneSession() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let first = try SportRepository(path: file)
    let second = try SportRepository(path: file)
    let time = now
    let cal = calendar
    async let a = first.startWorkout(scheduleID: "pull-abs", now: time, calendar: cal)
    async let b = second.startWorkout(scheduleID: "pull-abs", now: time, calendar: cal)
    let sessions = try await [a, b]
    XCTAssertEqual(sessions[0].id, sessions[1].id)
    let db = try SQLiteDatabase(path: file)
    XCTAssertEqual(
      try db.query("SELECT count(*) AS count FROM workouts").first?.integer("count"), 1)
  }

  func testDatabaseRejectsInvalidSetEvenOutsideRepository() async throws {
    let file = path()
    defer { try? FileManager.default.removeItem(atPath: file) }
    let repository = try SportRepository(path: file)
    let session = try await start(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    let db = try SQLiteDatabase(path: file)
    XCTAssertThrowsError(
      try db.execute(
        "INSERT INTO workout_sets(id,exercise_id,number,repetitions,duration_ms,weight_grams,completed_at) VALUES('bad',?,1,-1,NULL,0,?)",
        [.text(exercise.id), .integer(now)]))
    XCTAssertThrowsError(
      try db.execute(
        "INSERT INTO workout_sets(id,exercise_id,number,repetitions,duration_ms,weight_grams,completed_at) VALUES('bad2',?,1,NULL,-1,0,?)",
        [.text(exercise.id), .integer(now)]))
  }

}
