import Foundation
import XCTest

@testable import SportCore

final class WorkoutRefinementTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func setup(_ r: SportRepository, single: Bool = false) async throws -> WorkoutSession {
    let s = try await r.snapshot()
    var plan = try XCTUnwrap(s.schedules.first { $0.id == "pull-abs" })
    if single {
      plan.exerciseIDs = ["chin-ups"]
      try await r.saveSchedule(plan)
    }
    for var e in s.exercises where plan.exerciseIDs.contains(e.id) {
      e.setCount = 1
      try await r.saveExercise(e)
    }
    return try await r.startWorkout(scheduleID: plan.id, now: now, calendar: calendar)
  }
  func testTransitionRestStartsAtLastSetAndFeelingDoesNotRestartIt() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await setup(r)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 10, weightGrams: 0, now: now + 10_000)
    let feeling = try await r.workout(id: w.id)
    XCTAssertEqual(feeling.phase(at: now + 11_000), .feeling)
    let activity = try XCTUnwrap(RestActivitySnapshot.current(in: feeling, at: now + 11_000))
    XCTAssertEqual(activity.exerciseName, "L-sit")
    XCTAssertEqual(activity.nextSet, 1)
    XCTAssertEqual(activity.deadline, now + 190_000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 80, now: now + 15_000)
    let resting = try await r.workout(id: w.id)
    XCTAssertEqual(resting.phase(at: now + 15_000), .resting)
    XCTAssertEqual(resting.rest?.deadline, now + 190_000)
    let next = try XCTUnwrap(resting.currentExercise)
    do {
      try await r.beginSet(workoutID: w.id, exerciseID: next.id, number: 1, now: now + 16_000)
      XCTFail("Started next exercise during transition rest")
    } catch {}
    let rest = try XCTUnwrap(resting.rest)
    try await r.changeRest(id: rest.id, action: .pause, now: now + 20_000)
    let paused = try await r.workout(id: w.id)
    XCTAssertEqual(paused.rest?.remainingMS, 170_000)
    try await r.changeRest(id: rest.id, action: .skip, now: now + 21_000)
    let ready = try await r.workout(id: w.id)
    XCTAssertEqual(ready.phase(at: now + 21_000), .readySet)
  }
  func testCompletedWorkoutMatchesActualResultWithoutAdoptingSuggestedLoad() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await setup(r, single: true)
    let e = try XCTUnwrap(w.currentExercise)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    var goal = try XCTUnwrap(context.suggestion?.goal)
    let loads = try WeightInventory.loads(items: await r.snapshot().weightItems)
    goal.load = try XCTUnwrap(loads.first { $0.grams == 3900 })
    try await r.saveGoal(goal, original: nil)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 12, weightGrams: 3900, now: now + 10_000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 75, now: now + 11_000)
    let updated = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(updated.adopted?.repetitions, [12])
    XCTAssertEqual(updated.adopted?.load.grams, 3900)
    XCTAssertEqual(updated.suggestion?.goal.load.grams, 4500)
    let finished = try await r.workout(id: w.id)
    XCTAssertNil(finished.rest, "No rest after the last exercise")
    let next = try await r.startWorkout(
      scheduleID: "pull-abs", now: now + 20_000,
      calendar: calendar, restart: true)
    XCTAssertEqual(next.currentExercise?.goal?.repetitions, [12])
    XCTAssertEqual(next.currentExercise?.goal?.load.grams, 3900)
  }
}

extension ExerciseGoalTests {
  func testVeryHighFeelingSuggestsNearestLighterLoadAndPreservesReps() async throws {
    let r = try SportRepository(path: ":memory:")
    try await r.addHistoricalWorkout(
      entry(reps: [10, 10, 9, 8], feeling: 95), now: now, calendar: calendar)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(c.suggestion?.goal.load.grams, 3000)
    XCTAssertEqual(c.suggestion?.goal.repetitions, [10, 10, 9, 8])
    let previous = try await r.previousPerformance(exerciseID: "chin-ups", excludingWorkoutID: "")
    let loads = try WeightInventory.loads(items: await r.snapshot().weightItems)
    let assessment = Progression.assess(target: c.exercise, previous: previous, loads: loads)
    XCTAssertEqual(assessment.nextLoad?.grams, 3000)
  }
  func testExactlyNineDoesNotSuggestLighterLoad() async throws {
    let r = try SportRepository(path: ":memory:")
    try await r.addHistoricalWorkout(
      entry(reps: [10, 10, 9, 8], feeling: 90), now: now, calendar: calendar)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(c.suggestion?.goal.load.grams, 3900)
  }
}

extension WorkoutSupportTests {
  func stretching(_ r: SportRepository) async throws -> (WorkoutSession, Int) {
    let w = try await guided(r)
    let (ready, time) = try await warm(r, w)
    let e = try XCTUnwrap(ready.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: time)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 10, weightGrams: 0, now: time + 1000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 80, now: time + 2000)
    let stretching = try await r.workout(id: w.id)
    let step = try XCTUnwrap(stretching.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: time + 3000)
    return (try await r.workout(id: w.id), time + 36_000)
  }
  func testStretchAutomaticallyCompletesAtExactDeadlineEvenAfterReload() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let (w, deadline) = try await stretching(r)
    let early = try await r.workoutOverview(now: deadline - 1)
    XCTAssertEqual(early.active?.id, w.id)
    let reopened = try SportRepository(path: path)
    let expired = try await reopened.workoutOverview(now: deadline + 60_000)
    XCTAssertNil(expired.active)
    let saved = try await reopened.workout(id: w.id)
    XCTAssertEqual(saved.status, .completed)
    XCTAssertEqual(saved.endedAt, deadline)
    XCTAssertEqual(saved.support?.steps.last?.durationMS, 30_000)
    XCTAssertEqual(saved.support?.steps.last?.completedAt, deadline)
    XCTAssertEqual(try TrainingCSV.decode(TrainingCSV.encode([saved])), [saved])
    _ = try await reopened.workoutOverview(now: deadline + 70_000)
    let again = try await reopened.workout(id: w.id)
    XCTAssertEqual(again, saved)
  }
}

extension WorkoutRefinementTests {
  func testGoalMatchesAboveProgramResultRatherThanSilentlyClampingIt() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await setup(r, single: true)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 14, weightGrams: 0, now: now + 1000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 90, now: now + 2000)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(c.adopted?.repetitions, [14])
    XCTAssertEqual(c.suggestion?.goal.repetitions, [14])
  }
  func testCancelledWorkoutDoesNotReplaceGoalWithPartialPerformance() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await setup(r, single: true)
    let e = try XCTUnwrap(w.currentExercise)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    let goal = try XCTUnwrap(c.suggestion?.goal)
    try await r.saveGoal(goal, original: nil)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 10, weightGrams: 0, now: now + 1000)
    try await r.cancelWorkout(id: w.id, now: now + 2000)
    let after = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(after.adopted, goal)
  }
  func testTransitionRestExpiredWhileRatingDoesNotStartAgainAfterFeeling() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await setup(r)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1,
      repetitions: 10, weightGrams: 0, now: now + 1000)
    _ = try await r.workoutOverview(now: now + 181_000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 80, now: now + 190_000)
    let next = try await r.workout(id: w.id)
    XCTAssertNil(next.rest)
    XCTAssertEqual(next.phase(at: now + 190_000), .readySet)
  }
}

extension WorkoutSupportTests {
  func testLateStretchFinishStillRecordsTargetRatherThanExtraTime() async throws {
    let r = try SportRepository(path: ":memory:")
    let (w, deadline) = try await stretching(r)
    let step = try XCTUnwrap(w.currentSupport)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, now: deadline + 60_000)
    let ended = try await r.workout(id: w.id)
    XCTAssertEqual(ended.endedAt, deadline)
    XCTAssertEqual(ended.support?.steps.last?.durationMS, 30_000)
  }
  func testAutomaticStretchFeedbackIsClaimedOnlyOnce() async throws {
    let r = try SportRepository(path: ":memory:")
    let (w, deadline) = try await stretching(r)
    let first = try await r.workoutOverview(now: deadline)
    XCTAssertEqual(first.expiredStretchIDs, [try XCTUnwrap(w.currentSupport?.id)])
    let again = try await r.workoutOverview(now: deadline + 1000)
    XCTAssertTrue(again.expiredStretchIDs.isEmpty)
  }
}

extension ExerciseGoalTests {
  func testLighterSuggestionDoesNotRequirePreviousLoadInCurrentInventory() async throws {
    let r = try SportRepository(path: ":memory:")
    var draft = entry(reps: [10, 10, 9, 8], feeling: 95)
    draft.exercises[0].sets = [10, 10, 9, 8].map {
      ManualWorkoutSet(repetitions: $0, weightGrams: 4000)
    }
    try await r.addHistoricalWorkout(draft, now: now, calendar: calendar)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(c.suggestion?.goal.load.grams, 3900)
    XCTAssertEqual(c.suggestion?.goal.repetitions, [10, 10, 9, 8])
  }
  func testBodyweightWithVeryHighFeelingNeverInventsNegativeLoad() async throws {
    let r = try SportRepository(path: ":memory:")
    var draft = entry(reps: [10, 10, 9, 8], feeling: 100)
    draft.exercises[0].sets = [10, 10, 9, 8].map {
      ManualWorkoutSet(repetitions: $0, weightGrams: 0)
    }
    try await r.addHistoricalWorkout(draft, now: now, calendar: calendar)
    let c = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(c.suggestion?.goal.load.grams, 0)
    XCTAssertEqual(c.suggestion?.goal.repetitions, [10, 10, 9, 8])
  }
  func testTimedFeelingAboveNineSuggestsLessWeightWithoutChangingDuration() async throws {
    let r = try SportRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    var target = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    target.durationSeconds = 15
    try await r.saveExercise(target)
    let draft = ManualWorkout(
      id: "timed", name: "Timed", performedAt: now - 100_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "l-sit", tracking: .duration,
          sets: (1...4).map { _ in ManualWorkoutSet(durationMS: 18_000, weightGrams: 4500) },
          feelingTenths: 95)
      ])
    try await r.addHistoricalWorkout(draft, now: now, calendar: calendar)
    let c = try await r.goalContext(exerciseID: "l-sit")
    XCTAssertEqual(c.suggestion?.goal.load.grams, 3900)
    XCTAssertEqual(c.suggestion?.goal.definition.durationSeconds, 15)
  }
}
