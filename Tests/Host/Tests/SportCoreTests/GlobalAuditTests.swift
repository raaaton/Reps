import Foundation
import XCTest

@testable import SportCore

final class GlobalAuditTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }
  var invalidNames: [String] {
    [String(repeating: "a", count: 4097), String(repeating: "🧗", count: 1025), "name\0suffix"]
  }
  func reject(_ operation: () async throws -> Void) async {
    do {
      try await operation()
      XCTFail("Accepted an invalid mutation")
    } catch {}
  }
  func draft(name: String) -> ManualWorkout {
    ManualWorkout(
      id: "manual-audit", name: name, performedAt: now,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: [ManualWorkoutSet(repetitions: 10, weightGrams: 6000)], feelingTenths: 70)
      ])
  }
  func startAndRecord(_ repository: SportRepository) async throws -> WorkoutSession {
    let session = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.recordSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1,
      repetitions: 10, weightGrams: 0, now: now + 12_300)
    return session
  }

  func testInvalidLocalNamesCannotBlockExports() async throws {
    for name in invalidNames {
      let repository = try SportRepository(path: ":memory:")
      let before = try await repository.snapshot()
      var exercise = before.exercises[0]
      exercise.name = name
      await reject { try await repository.saveExercise(exercise) }
      var schedule = before.schedules[0]
      schedule.name = name
      await reject { try await repository.saveSchedule(schedule) }
      await reject {
        try await repository.saveWeightItem(
          WeightItem(id: "audit", name: name, grams: 1000, isEnabled: true))
      }
      let after = try await repository.snapshot()
      XCTAssertEqual(after, before)
      let archive = try await repository.exportTraining(now: now)
      _ = try archive.encoded()
      _ = try TrainingCSV.encode(archive.contents.workouts)
    }
  }

  func testInvalidManualNamesPreserveHistoryAndExport() async throws {
    for name in invalidNames {
      let repository = try SportRepository(path: ":memory:")
      await reject { try await repository.addHistoricalWorkout(draft(name: name), now: now) }
      let empty = try await repository.workoutOverview(now: now)
      XCTAssertTrue(empty.history.isEmpty)
      let valid = draft(name: "Audit")
      try await repository.addHistoricalWorkout(valid, now: now)
      let original = try await repository.workout(id: valid.id)
      await reject {
        try await repository.updateHistoricalWorkout(
          draft(name: name), original: original, now: now)
      }
      let after = try await repository.workout(id: valid.id)
      XCTAssertEqual(after, original)
      _ = try await repository.exportTraining(now: now).encoded()
    }
  }

  func testTextBoundaryRoundTripsWithoutTruncation() async throws {
    let repository = try SportRepository(path: ":memory:")
    var exercise = (try await repository.snapshot()).exercises[0]
    exercise.name = String(repeating: "🧗", count: 1024)
    try await repository.saveExercise(exercise)
    let archive = try await repository.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.contents.configuration.exercises[0].name, exercise.name)
  }

  func testCancelAfterClockReversalPreservesSavedSeries() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await startAndRecord(repository)
    let before = try await repository.workout(id: session.id)
    await reject { try await repository.cancelWorkout(id: session.id, now: now + 1000) }
    let after = try await repository.workout(id: session.id)
    XCTAssertEqual(after, before)
    try await repository.cancelWorkout(id: session.id, now: now + 13_000)
    _ = try await repository.exportTraining(now: now + 13_000).encoded()
  }

  func testNewSetAfterClockReversalPreservesPreviousSeries() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await startAndRecord(repository)
    let resting = try await repository.workout(id: session.id)
    let rest = try XCTUnwrap(resting.rest)
    try await repository.changeRest(id: rest.id, action: .skip, now: now + 13_000)
    let before = try await repository.workout(id: session.id)
    let exercise = try XCTUnwrap(before.currentExercise)
    await reject {
      try await repository.beginSet(
        workoutID: session.id, exerciseID: exercise.id, number: 2, now: now + 1000)
    }
    let after = try await repository.workout(id: session.id)
    XCTAssertEqual(after, before)
  }

  func testCancelDuringFutureCountdownRemainsAllowed() async throws {
    let repository = try SportRepository(path: ":memory:")
    var schedule = (try await repository.snapshot()).schedules.first { $0.id == "pull-abs" }!
    schedule.exerciseIDs = ["l-sit"]
    try await repository.saveSchedule(schedule)
    let session = try await repository.startWorkout(
      scheduleID: schedule.id, now: now, calendar: calendar)
    let exercise = try XCTUnwrap(session.currentExercise)
    try await repository.beginSet(
      workoutID: session.id, exerciseID: exercise.id, number: 1, weightGrams: 0, now: now)
    try await repository.cancelWorkout(id: session.id, now: now + 1000)
    let cancelled = try await repository.workout(id: session.id)
    XCTAssertEqual(cancelled.status, .cancelled)
    XCTAssertTrue(cancelled.exercises[0].sets.isEmpty)
    _ = try await repository.exportTraining(now: now + 1000).encoded()
  }
}
