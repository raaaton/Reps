import Foundation
import XCTest

@testable import SportCore

final class WorkoutSupportTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }
  func exercise(timed: Bool = false, duration: Int? = 15) -> WorkoutExercise {
    let d = TrainingExercise(
      id: "chin-ups", name: "Chin-ups", tracking: timed ? .duration : .repetitions,
      setCount: 4, minimumReps: timed ? nil : 8, maximumReps: timed ? nil : 12,
      durationSeconds: timed ? duration : nil, isEnabled: true)
    return WorkoutExercise(
      id: "first", definition: d, sets: [], feelingTenths: nil,
      setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
  }
  func testBodyweightWarmupUsesTwoHalfTargetsAndCorrectRests() throws {
    var e = exercise()
    e.goal = ExerciseGoal(definition: e.definition, load: .bodyweight, repetitions: [11, 10, 9, 8])
    let plan = try WorkoutSupport.make(
      first: e, restSeconds: 181, stretch: .upperBack, stretchSeconds: 30)
    let warm = plan.steps.filter { $0.kind == .warmUp }
    XCTAssertEqual(warm.count, 2)
    XCTAssertEqual(warm.map(\.targetRepetitions), [5, 5])
    XCTAssertEqual(warm.map(\.restAfterMS), [90_500, 181_000])
    XCTAssertEqual(Set(warm.map(\.name)), ["Chin-ups"])
  }
  func testWeightedWarmupUsesOneFullTargetAtBodyweight() throws {
    var e = exercise()
    e.goal = ExerciseGoal(
      definition: e.definition, load: AvailableLoad(grams: 6000, components: []),
      repetitions: [12, 11, 10, 9])
    let plan = try WorkoutSupport.make(
      first: e, restSeconds: 180, stretch: .quadriceps, stretchSeconds: 30)
    XCTAssertEqual(plan.steps.filter { $0.kind == .warmUp }.map(\.targetRepetitions), [12])
    XCTAssertEqual(plan.steps.first?.restAfterMS, 180_000)
    XCTAssertEqual(plan.steps.filter { $0.kind == .stretch }.count, 2)
  }
  func testTimedWarmupSupportsHalfSecondsAndFreeDuration() throws {
    let timed = try WorkoutSupport.make(
      first: exercise(timed: true), restSeconds: 180, stretch: .upperBack, stretchSeconds: 30)
    XCTAssertEqual(timed.steps.prefix(2).map(\.targetDurationMS), [7500, 7500])
    let free = try WorkoutSupport.make(
      first: exercise(timed: true, duration: nil), restSeconds: 180, stretch: .upperBack,
      stretchSeconds: 30)
    XCTAssertTrue(free.steps.prefix(2).allSatisfy { $0.targetDurationMS == nil })
  }
}

extension WorkoutSupportTests {
  func guided(_ r: SportRepository, timed: Bool = false, duration: Int? = 15) async throws
    -> WorkoutSession
  {
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    var d = try XCTUnwrap(snapshot.exercises.first { $0.id == (timed ? "l-sit" : "chin-ups") })
    if timed { d.durationSeconds = duration }
    try await r.saveExercise(d)
    schedule.exerciseIDs = [d.id]
    schedule.setCounts = [d.id: 1]
    try await r.saveSchedule(schedule)
    return try await r.startWorkout(
      scheduleID: schedule.id, now: now, calendar: calendar,
      includeSupport: true, stretch: .upperBack)
  }
  func warm(_ r: SportRepository, _ w: WorkoutSession) async throws -> (WorkoutSession, Int) {
    var time = now + 1000
    var current = w
    for _ in 0..<2 {
      let step = try XCTUnwrap(current.currentSupport)
      try await r.beginSupport(workoutID: w.id, stepID: step.id, now: time)
      time += step.tracking == .duration ? 9000 : 1000
      try await r.finishSupport(
        workoutID: w.id, stepID: step.id,
        repetitions: step.targetRepetitions, now: time)
      current = try await r.workout(id: w.id)
      XCTAssertEqual(current.phase(at: time), .resting)
      let rest = try XCTUnwrap(current.rest)
      XCTAssertEqual(rest.remaining(at: time), step.restAfterMS)
      XCTAssertNotNil(RestActivitySnapshot.current(in: current, at: time))
      try await r.changeRest(id: rest.id, action: .skip, now: time + 1)
      time += 1000
      current = try await r.workout(id: w.id)
    }
    return (current, time)
  }
  func completeGuided(_ r: SportRepository) async throws -> WorkoutSession {
    let original = try await guided(r)
    let (w, time) = try await warm(r, original)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: time)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1, repetitions: 10, weightGrams: 0,
      now: time + 1000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 70, now: time + 2000)
    let stretching = try await r.workout(id: w.id)
    XCTAssertEqual(stretching.status, .active)
    XCTAssertEqual(stretching.currentSupport?.kind, .stretch)
    let step = try XCTUnwrap(stretching.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: time + 3000)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, now: time + 36_000)
    let finished = try await r.workout(id: w.id)
    XCTAssertEqual(finished.status, .completed)
    XCTAssertEqual(finished.endedAt, time + 36_000)
    XCTAssertEqual(finished.exercises.flatMap(\.sets).count, 1)
    return finished
  }
  func testGuidedSequenceRequiresWarmupAndRestThenStretchBeforeCompletion() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await guided(r)
    XCTAssertEqual(w.phase(at: now), .support)
    let e = try XCTUnwrap(w.currentExercise)
    do {
      try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now + 1)
      XCTFail("Skipped required warm-up")
    } catch {}
    try await r.cancelWorkout(id: w.id, now: now + 1)
    _ = try await completeGuided(r)
  }
  func testSupportSurvivesReloadAndRepeatedFinishDoesNotRestartRest() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let w = try await guided(r)
    let step = try XCTUnwrap(w.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now + 1000)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, repetitions: 4, now: now + 2000)
    let before = try await r.workout(id: w.id)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, repetitions: 4, now: now + 3000)
    let reopened = try SportRepository(path: path)
    let after = try await reopened.workout(id: w.id)
    XCTAssertEqual(after, before)
    XCTAssertEqual(after.exercises.flatMap(\.sets).count, 0)
    let rest = try XCTUnwrap(after.rest)
    try await reopened.changeRest(id: rest.id, action: .pause, now: now + 4000)
    let paused = try await reopened.workout(id: w.id)
    XCTAssertEqual(paused.rest?.remaining(at: now + 80_000), 88_000)
    try await reopened.changeRest(id: rest.id, action: .resume, now: now + 80_000)
    let resumed = try await reopened.workout(id: w.id)
    XCTAssertEqual(resumed.rest?.deadline, now + 168_000)
  }
  func testTimedSupportCountdownCancelAndFreeResultsPersist() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await guided(r, timed: true, duration: nil)
    let step = try XCTUnwrap(w.currentSupport)
    XCTAssertNil(step.targetDurationMS)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now)
    let counting = try await r.workout(id: w.id)
    XCTAssertEqual(counting.currentSupport?.countdown(at: now), 3)
    do {
      try await r.finishSupport(workoutID: w.id, stepID: step.id, now: now + 1000)
      XCTFail("Completed during countdown")
    } catch {}
    try await r.cancelSupportCountdown(
      workoutID: w.id, stepID: step.id, expectedStart: now + 3000, now: now + 1000)
    let cancelled = try await r.workout(id: w.id)
    XCTAssertNil(cancelled.currentSupport?.startedAt)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now + 2000)
    // Late delivery of Cancel cannot stop an already-running timer.
    try await r.cancelSupportCountdown(
      workoutID: w.id, stepID: step.id, expectedStart: now + 5000, now: now + 6000)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, now: now + 17_500)
    let done = try await r.workout(id: w.id)
    XCTAssertEqual(done.support?.steps.first?.durationMS, 12_500)
  }
  func testSupportCSVJSONAndReplacementRoundTripWithoutAffectingWorkSets() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await completeGuided(r)
    let records = try TrainingCSV.decode(TrainingCSV.encode([w]))
    XCTAssertEqual(records, [w])
    let archive = try await r.exportTraining(now: now + 100_000)
    XCTAssertEqual(try TrainingArchive.decode(archive.encoded()), archive)
    let target = try SportRepository(path: ":memory:")
    let preview = try await target.previewCSVImport(records, now: now + 100_000)
    try await target.applyTrainingImport(preview, now: now + 100_000)
    let imported = try await target.workout(id: w.id)
    XCTAssertEqual(imported, w)
    let history = try await target.workoutOverview(now: now + 100_000)
    XCTAssertEqual(history.history.first?.setCount, 1)
  }
  func testLegacyCSVAndVersionSevenDataRemainCompatible() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let legacy = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TABLE workout_goal_decisions")
    try db.execute("DROP TABLE workout_support")
    try db.execute("PRAGMA user_version=7")
    let migrated = try SportRepository(path: path)
    let loaded = try await migrated.workout(id: legacy.id)
    XCTAssertEqual(loaded, legacy)
    XCTAssertNil(loaded.support)
    let data = try Data(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent(
          "Sources/Sport/Resources/Sport-demo-2026.csv"))
    XCTAssertFalse(try TrainingCSV.decode(data).isEmpty)
  }
}

extension WorkoutSupportTests {
  func testFullRestExpiresBeforeFirstWorkSetAndLiveActivityStops() async throws {
    let r = try SportRepository(path: ":memory:")
    let initial = try await guided(r)
    var current = initial
    var time = now + 1000
    for _ in 0..<2 {
      let step = try XCTUnwrap(current.currentSupport)
      try await r.beginSupport(workoutID: initial.id, stepID: step.id, now: time)
      try await r.finishSupport(
        workoutID: initial.id, stepID: step.id, repetitions: 4, now: time + 1000)
      let resting = try await r.workout(id: initial.id)
      let rest = try XCTUnwrap(resting.rest)
      let e = try XCTUnwrap(resting.currentExercise)
      do {
        try await r.beginSet(workoutID: initial.id, exerciseID: e.id, number: 1, now: time + 2000)
        XCTFail("Started a work set during warm-up rest")
      } catch {}
      time = try XCTUnwrap(rest.deadline)
      let overview = try await r.workoutOverview(now: time)
      current = try XCTUnwrap(overview.active)
      XCTAssertNil(RestActivitySnapshot.current(in: current, at: time))
    }
    XCTAssertEqual(current.phase(at: time), .readySet)
    XCTAssertNil(current.currentSupport)
  }
  func testOnlyOneWarmupForWeightedFirstExerciseAndSnapshotStaysFixed() async throws {
    let r = try SportRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    let load = try XCTUnwrap(
      WeightInventory.loads(items: snapshot.weightItems).first { $0.grams > 0 })
    let w = try await r.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar,
      loadOverrides: ["chin-ups": load], includeSupport: true)
    XCTAssertEqual(w.support?.steps.filter { $0.kind == .warmUp }.count, 1)
    XCTAssertEqual(w.support?.steps.first?.targetRepetitions, 8)
    var first = try XCTUnwrap(snapshot.exercises.first { $0.id == "chin-ups" })
    first.minimumReps = 2
    first.maximumReps = 6
    try await r.saveExercise(first)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after.support, w.support)
    XCTAssertEqual(after.exercises.count, 2)
    let step = try XCTUnwrap(after.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now + 1000)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, repetitions: 8, now: now + 2000)
    let rested = try await r.workout(id: w.id)
    XCTAssertEqual(rested.rest?.remaining(at: now + 2000), 180_000)
  }
  func testCancelledCountdownExportsWithoutInventingACompletedResult() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await guided(r, timed: true, duration: nil)
    let step = try XCTUnwrap(w.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now)
    try await r.cancelWorkout(id: w.id, now: now + 1000)
    let cancelled = try await r.workout(id: w.id)
    let restored = try TrainingCSV.decode(TrainingCSV.encode([cancelled]))
    XCTAssertEqual(restored, [cancelled])
    XCTAssertNil(restored[0].support?.steps.first?.durationMS)
    XCTAssertNil(restored[0].support?.steps.first?.completedAt)
  }
  func testMalformedSupportPayloadAndUnorderedResultsAreRejected() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await completeGuided(r)
    var broken = w
    broken.support?.steps[1].completedAt = now
    XCTAssertThrowsError(try TrainingCSV.encode([broken]))
    let archive = try await r.exportTraining(now: now + 100_000)
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var workouts = try XCTUnwrap(contents["workouts"] as? [[String: Any]])
    var support = try XCTUnwrap(workouts[0]["support"] as? [String: Any])
    support["privatePhotos"] = []
    workouts[0]["support"] = support
    contents["workouts"] = workouts
    root["contents"] = contents
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
  }
}

extension WorkoutSupportTests {
  func testBackwardClockCannotCancelBeforeSavedWarmupOrBreakExports() async throws {
    let r = try SportRepository(path: ":memory:")
    let w = try await guided(r)
    let step = try XCTUnwrap(w.currentSupport)
    try await r.beginSupport(workoutID: w.id, stepID: step.id, now: now + 1000)
    try await r.finishSupport(workoutID: w.id, stepID: step.id, repetitions: 4, now: now + 10_000)
    do {
      try await r.cancelWorkout(id: w.id, now: now + 5000)
      XCTFail("Cancelled before a saved warm-up")
    } catch {}
    let current = try await r.workout(id: w.id)
    XCTAssertEqual(current.status, .active)
    try await r.cancelWorkout(id: w.id, now: now + 11_000)
    let cancelled = try await r.workout(id: w.id)
    XCTAssertEqual(try TrainingCSV.decode(TrainingCSV.encode([cancelled])), [cancelled])
    let exported = try await r.exportTraining(now: now + 12_000)
    XCTAssertEqual(try TrainingArchive.decode(exported.encoded()), exported)
  }
}

extension WorkoutSupportTests {
  func testExerciseGoalChoiceSurvivesStretchCompletionForUpdateAndKeep() async throws {
    for update in [true, false] {
      let r = try SportRepository(path: ":memory:")
      let original = try await guided(r)
      let (w, time) = try await warm(r, original)
      let exercise = try XCTUnwrap(w.currentExercise)
      try await r.beginSet(workoutID: w.id, exerciseID: exercise.id, number: 1, now: time)
      try await r.recordSet(
        workoutID: w.id, exerciseID: exercise.id, number: 1,
        repetitions: 12, weightGrams: 3900, now: time + 1000)
      let preview = try await r.exerciseLoadGoalDecision(
        workoutID: w.id, exerciseID: exercise.id,
        feelingTenths: 75, now: time + 2000)
      let decision = try XCTUnwrap(preview)
      try await r.resolveExerciseLoadGoal(decision, update: update, now: time + 2000)
      let stretching = try await r.workout(id: w.id)
      XCTAssertEqual(stretching.currentSupport?.kind, .stretch)
      let step = try XCTUnwrap(stretching.currentSupport)
      try await r.beginSupport(workoutID: w.id, stepID: step.id, now: time + 3000)
      try await r.finishSupport(workoutID: w.id, stepID: step.id, now: time + 36_000)
      let finished = try await r.workout(id: w.id)
      let context = try await r.goalContext(exerciseID: "chin-ups")
      XCTAssertEqual(finished.status, .completed)
      if update {
        XCTAssertEqual(context.adopted, decision.suggestion.goal)
      } else {
        XCTAssertEqual(context.adopted?.repetitions, [12])
        XCTAssertEqual(context.adopted?.load.grams, 3900)
      }
    }
  }
}
