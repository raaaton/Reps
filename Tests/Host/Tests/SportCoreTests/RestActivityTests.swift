import Foundation
import XCTest

@testable import SportCore

final class RestActivityTests: XCTestCase, @unchecked Sendable {
  private let now = 1_791_720_000_000

  private func start(_ repository: SportRepository) async throws -> WorkoutSession {
    let snapshot = try await repository.snapshot()
    var exercise = try XCTUnwrap(snapshot.exercises.first { $0.id == "chin-ups" })
    exercise.setCount = 2
    try await repository.saveExercise(exercise)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return try await repository.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
  }

  private func record(_ repository: SportRepository, _ workout: WorkoutSession, time: Int)
    async throws
  {
    let exercise = try XCTUnwrap(workout.currentExercise)
    let number = exercise.sets.count + 1
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: number, now: time)
    try await repository.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: number,
      repetitions: 10, weightGrams: 0, now: time + 12_300)
  }

  private func resting(_ repository: SportRepository) async throws -> WorkoutSession {
    let workout = try await start(repository)
    try await record(repository, workout, time: now)
    return try await repository.workout(id: workout.id)
  }

  func testProjectionUsesPersistedRestIdentityDeadlineAndNextSet() async throws {
    let repository = try SportRepository(path: ":memory:")
    let workout = try await resting(repository)
    let snapshot = try XCTUnwrap(RestActivitySnapshot.current(in: workout, at: now + 15_000))
    XCTAssertEqual(snapshot.restID, workout.rest?.id)
    XCTAssertEqual(snapshot.workoutID, workout.id)
    XCTAssertEqual(snapshot.exerciseName, "Chin-ups")
    XCTAssertEqual(snapshot.nextSet, 2)
    XCTAssertEqual(snapshot.deadline, now + 192_300)
    XCTAssertNil(snapshot.remainingMS)
    XCTAssertFalse(snapshot.isPaused)
    XCTAssertEqual(snapshot, RestActivitySnapshot.current(in: workout, at: now + 16_000))
    XCTAssertNil(RestActivitySnapshot.current(in: workout, at: now + 192_300))
  }

  func testPausedProjectionKeepsRemainingWithoutRunningAnotherTimer() async throws {
    let repository = try SportRepository(path: ":memory:")
    let workout = try await resting(repository)
    let rest = try XCTUnwrap(workout.rest)
    try await repository.changeRest(id: rest.id, action: .pause, now: now + 20_000)
    let paused = try await repository.workout(id: workout.id)
    let snapshot = try XCTUnwrap(RestActivitySnapshot.current(in: paused, at: now + 30_000))
    XCTAssertEqual(snapshot.remainingMS, 172_300)
    XCTAssertNil(snapshot.deadline)
    XCTAssertTrue(snapshot.isPaused)
    XCTAssertEqual(snapshot, RestActivitySnapshot.current(in: paused, at: now + 500_000))
  }

  func testOldPauseCannotChangeResumedDeadlineAndOldResumeCannotChangeNewPause() async throws {
    let repository = try SportRepository(path: ":memory:")
    let workout = try await resting(repository)
    let id = try XCTUnwrap(workout.rest?.id)
    try await repository.changeRest(
      id: id, action: .pause, expectedTime: now + 192_300, now: now + 20_000)
    try await repository.changeRest(
      id: id, action: .resume, expectedTime: 172_300, now: now + 30_000)
    try await repository.changeRest(
      id: id, action: .pause, expectedTime: now + 192_300, now: now + 40_000)
    var current = try await repository.workout(id: workout.id)
    XCTAssertEqual(current.rest?.status, .running)
    XCTAssertEqual(current.rest?.deadline, now + 202_300)
    try await repository.changeRest(
      id: id, action: .pause, expectedTime: now + 202_300, now: now + 50_000)
    try await repository.changeRest(
      id: id, action: .resume, expectedTime: 172_300, now: now + 60_000)
    current = try await repository.workout(id: workout.id)
    XCTAssertEqual(current.rest?.status, .paused)
    XCTAssertEqual(current.rest?.remainingMS, 152_300)
  }

  func testExternalConnectionCommitsPauseBeforeAppReadsProjectionAndRepeatIsHarmless() async throws
  {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let app = try SportRepository(path: path)
    let workout = try await resting(app)
    let external = try SportRepository(path: path)
    let id = try XCTUnwrap(workout.rest?.id)
    for time in [now + 20_000, now + 25_000] {
      try await external.changeRest(
        id: id, action: .pause, expectedTime: now + 192_300, now: time)
    }
    let current = try await app.workout(id: workout.id)
    XCTAssertEqual(
      RestActivitySnapshot.current(in: current, at: now + 30_000)?.remainingMS, 172_300)
  }

  func testProjectionDoesNotExposeActiveSeriesOrSkippedCancelledOrExpiredRest() async throws {
    let repository = try SportRepository(path: ":memory:")
    let ready = try await start(repository)
    XCTAssertNil(RestActivitySnapshot.current(in: ready, at: now))
    try await record(repository, ready, time: now)
    let resting = try await repository.workout(id: ready.id)
    let id = try XCTUnwrap(resting.rest?.id)
    try await repository.changeRest(id: id, action: .skip, now: now + 20_000)
    let skipped = try await repository.workout(id: ready.id)
    XCTAssertNil(RestActivitySnapshot.current(in: skipped, at: now + 20_000))
    try await record(repository, skipped, time: now + 30_000)
    let lastSet = try await repository.workout(id: ready.id)
    XCTAssertEqual(lastSet.phase(at: now + 50_000), .feeling)
    XCTAssertNil(RestActivitySnapshot.current(in: lastSet, at: now + 50_000))
    try await repository.cancelWorkout(id: ready.id, now: now + 60_000)
    let cancelled = try await repository.workout(id: ready.id)
    XCTAssertNil(RestActivitySnapshot.current(in: cancelled, at: now + 60_000))
    XCTAssertNil(RestActivitySnapshot.current(in: nil, at: now))
  }

  func testActivityReadDoesNotConsumeForegroundExpiryFeedback() async throws {
    let repository = try SportRepository(path: ":memory:")
    let workout = try await resting(repository)
    let projection = try await repository.restActivitySnapshot(now: now + 200_000)
    XCTAssertNil(projection)
    let overview = try await repository.workoutOverview(now: now + 200_000)
    XCTAssertEqual(overview.expiredRestIDs, [try XCTUnwrap(workout.rest?.id)])
  }
}
