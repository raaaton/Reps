import Foundation
import XCTest

@testable import SportCore

final class CountdownTests: XCTestCase, @unchecked Sendable {
  private let now = 1_791_720_000_000

  private func timedSession(_ repository: SportRepository) async throws -> WorkoutSession {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let snapshot = try await repository.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await repository.saveSchedule(schedule)
    return try await repository.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
  }

  func testTimedStartIsPersistedAheadAndDuplicateBeginCannotRestartPreparation() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SportRepository(path: path)
    let session = try await timedSession(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now + 1000)
    let reopened = try SportRepository(path: path)
    let restored = try await reopened.workout(id: session.id)
    XCTAssertEqual(restored.currentExercise?.setStartedAt, now + 3000)
    XCTAssertTrue(try XCTUnwrap(restored.currentExercise).sets.isEmpty)
  }

  func testPreparationCannotSavePerformanceAndRecordedDurationExcludesThreeSeconds() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await timedSession(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    for time in [now + 1000, now + 2999, now + 3000] {
      do {
        try await repository.recordSet(
          workoutID: session.id, exerciseID: exercise.id, number: 1,
          repetitions: nil, weightGrams: 0, now: time)
        XCTFail("Recorded preparation or zero duration")
      } catch {}
    }
    let before = try await repository.workout(id: session.id)
    XCTAssertTrue(try XCTUnwrap(before.currentExercise).sets.isEmpty)
    XCTAssertNil(before.rest)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1,
      repetitions: nil, weightGrams: 0, now: now + 13_250)
    let saved = try await repository.workout(id: session.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.durationMS, 10_300)
    XCTAssertEqual(saved.rest?.deadline, now + 13_250 + session.restSeconds * 1000)
  }
  func testCountdownBoundaryAndCancelCanOnlyAffectPendingSet() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await timedSession(repository)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    var current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase(at: now), .countdown)
    for (offset, expected) in [
      (0, 3), (999, 3), (1000, 2), (1999, 2), (2000, 1), (2999, 1), (3000, 0),
    ] {
      XCTAssertEqual(current.currentExercise?.countdownSeconds(at: now + offset), expected)
    }
    XCTAssertEqual(current.phase(at: now + 3000), .activeSet)
    do {
      try await repository.cancelSetCountdown(
        workoutID: session.id, exerciseID: exercise.id,
        number: 2, expectedStart: now + 3000, now: now + 1000)
      XCTFail("Wrong series cancelled preparation")
    } catch {}
    try await repository.cancelSetCountdown(
      workoutID: session.id, exerciseID: exercise.id,
      number: 1, expectedStart: now + 3000, now: now + 1000)
    current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase(at: now + 1000), .readySet)
    XCTAssertNil(current.currentExercise?.setStartedAt)
    XCTAssertNil(current.rest)
    XCTAssertTrue(try XCTUnwrap(current.currentExercise).sets.isEmpty)
    try await repository.cancelSetCountdown(
      workoutID: session.id, exerciseID: exercise.id,
      number: 1, expectedStart: now + 3000, now: now + 1500)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now + 2000)
    try await repository.cancelSetCountdown(
      workoutID: session.id, exerciseID: exercise.id,
      number: 1, expectedStart: now + 3000, now: now + 2500)
    let staleCancel = try await repository.workout(id: session.id)
    XCTAssertEqual(
      staleCancel.currentExercise?.setStartedAt, now + 5000,
      "An old cancellation must not erase a new countdown for the same series")
    try await repository.cancelSetCountdown(
      workoutID: session.id, exerciseID: exercise.id,
      number: 1, expectedStart: now + 5000, now: now + 5000)
    current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.currentExercise?.setStartedAt, now + 5000)
    XCTAssertEqual(current.phase(at: now + 5000), .activeSet)
    try await repository.cancelWorkout(id: session.id, now: now + 6000)
    current = try await repository.workout(id: session.id)
    XCTAssertEqual(current.phase(at: now + 6000), .cancelled)
    XCTAssertTrue(try XCTUnwrap(current.exercises.first).sets.isEmpty)
  }

  func testRepetitionsStartImmediatelyAndCannotBeResetByCountdownCancel() async throws {
    let repository = try SportRepository(path: ":memory:")
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let session = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.cancelSetCountdown(
      workoutID: session.id, exerciseID: exercise.id,
      number: 1, expectedStart: now + 3000, now: now + 100)
    let started = try await repository.workout(id: session.id)
    XCTAssertEqual(started.phase(at: now), .activeSet)
    XCTAssertEqual(started.currentExercise?.setStartedAt, now)
    XCTAssertEqual(started.currentExercise?.countdownSeconds(at: now), 0)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1,
      repetitions: 10, weightGrams: 0, now: now + 1000)
    let saved = try await repository.workout(id: session.id)
    XCTAssertEqual(saved.currentExercise?.sets.first?.repetitions, 10)
    XCTAssertNil(saved.currentExercise?.sets.first?.durationMS)
  }

}
