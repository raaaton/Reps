import XCTest

@testable import SportCore

final class WorkoutFeedbackTests: XCTestCase, @unchecked Sendable {
  func testSavedSetProducesOneSuccessButReadingOrCorrectingDoesNot() async throws {
    let helper = WorkoutTests(name: "fixture", testClosure: { _ in })
    let repository = try SportRepository(path: ":memory:")
    let started = try await helper.start(repository)
    let before = try await repository.workoutOverview(now: helper.now)
    try await helper.record(repository, started, time: helper.now)
    let after = try await repository.workoutOverview(now: helper.now + 13_000)
    XCTAssertEqual(WorkoutFeedback.change(from: before, to: after), .success)
    var tracker = WorkoutFeedbackTracker()
    XCTAssertEqual(tracker.event(from: before, to: after), .success)
    XCTAssertNil(
      tracker.event(from: before, to: after), "Overlapping refreshes cannot replay a save")
    XCTAssertNil(WorkoutFeedback.change(from: after, to: after))
    let exercise = try XCTUnwrap(after.active?.currentExercise)
    let set = try XCTUnwrap(exercise.sets.first)
    try await repository.correctSet(
      workoutID: started.id, exerciseID: exercise.id, original: set,
      repetitions: 11, durationMS: nil, weightGrams: set.weightGrams)
    let corrected = try await repository.workoutOverview(now: helper.now + 14_000)
    XCTAssertNil(WorkoutFeedback.change(from: after, to: corrected))
  }

  func testRestPauseResumeAndExpiryDoNotProduceSuccess() async throws {
    let helper = WorkoutTests(name: "fixture", testClosure: { _ in })
    let repository = try SportRepository(path: ":memory:")
    let started = try await helper.start(repository)
    try await helper.record(repository, started, time: helper.now)
    let running = try await repository.workoutOverview(now: helper.now + 13_000)
    let rest = try XCTUnwrap(running.active?.rest)
    try await repository.changeRest(id: rest.id, action: .pause, now: helper.now + 14_000)
    let paused = try await repository.workoutOverview(now: helper.now + 14_000)
    XCTAssertEqual(WorkoutFeedback.change(from: running, to: paused), .selection)
    XCTAssertNil(WorkoutFeedback.change(from: paused, to: paused))
    try await repository.changeRest(id: rest.id, action: .resume, now: helper.now + 15_000)
    let resumed = try await repository.workoutOverview(now: helper.now + 15_000)
    XCTAssertEqual(WorkoutFeedback.change(from: paused, to: resumed), .selection)
    let expired = try await repository.workoutOverview(now: helper.now + 300_000)
    XCTAssertNil(WorkoutFeedback.change(from: resumed, to: expired), "Expiry has its own feedback")
  }

  func testFinishWorkoutSucceedsButCancellationIsSilent() async throws {
    let helper = WorkoutTests(name: "fixture", testClosure: { _ in })
    let repository = try SportRepository(path: ":memory:")
    var session = try await helper.start(repository, sets: 1)
    for index in 0..<2 {
      let time = helper.now + index * 30_000
      try await helper.record(repository, session, time: time)
      let before = try await repository.workoutOverview(now: time + 13_000)
      let exercise = try XCTUnwrap(before.active?.currentExercise)
      try await repository.saveFeeling(
        workoutID: session.id, exerciseID: exercise.id, tenths: 75, now: time + 14_000)
      let after = try await repository.workoutOverview(now: time + 14_000)
      XCTAssertEqual(
        WorkoutFeedback.change(from: before, to: after), index == 1 ? .success : .selection)
      session = try await repository.workout(id: session.id)
    }
    let next = try await repository.startWorkout(
      scheduleID: "pull-abs", now: helper.now + 90_000, calendar: helper.calendar, restart: true)
    let beforeCancel = try await repository.workoutOverview(now: helper.now + 90_000)
    try await repository.cancelWorkout(id: next.id, now: helper.now + 91_000)
    let cancelled = try await repository.workoutOverview(now: helper.now + 91_000)
    XCTAssertNil(WorkoutFeedback.change(from: beforeCancel, to: cancelled))
  }
}
