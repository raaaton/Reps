import Foundation
import XCTest

@testable import SportCore

final class ProgressionIntegrationTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var value = Calendar(identifier: .buddhist)
    value.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
    return value
  }
  func testTimedGoalNeverRaisesLoadAndCorrectionPreservesNextCountdownAcrossConnections()
    async throws
  {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.weekday = 1
    schedule.exerciseIDs = ["l-sit"]
    try await r.saveSchedule(schedule)
    let context = try await r.goalContext(exerciseID: "l-sit")
    var goal = try XCTUnwrap(context.suggestion?.goal)
    goal.load = try XCTUnwrap(
      WeightInventory.loads(items: snapshot.weightItems).first { $0.grams == 3900 })
    try await r.saveGoal(goal, original: nil)
    let w = try await r.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
    let ex = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(
      workoutID: w.id, exerciseID: ex.id, number: 1, weightGrams: 3900, load: goal.load, now: now)
    try await r.finishTimedSet(workoutID: w.id, exerciseID: ex.id, number: 1, now: now + 13000)
    let saved = try await r.workout(id: w.id)
    let set = try XCTUnwrap(saved.currentExercise?.sets.first)
    try await r.changeRest(id: XCTUnwrap(saved.rest).id, action: .skip, now: now + 14000)
    try await r.beginSet(
      workoutID: w.id, exerciseID: ex.id, number: 2, weightGrams: 3900, load: goal.load,
      now: now + 15000)
    let other = try SportRepository(path: path)
    try await other.correctSet(
      workoutID: w.id, exerciseID: ex.id, original: set, repetitions: nil, durationMS: 12000,
      weightGrams: 3900)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after.currentExercise?.setStartedAt, now + 18000)
    XCTAssertEqual(after.phase(at: now + 16000), .countdown)
    XCTAssertEqual(after.currentExercise?.sets.first?.completedAt, set.completedAt)
    XCTAssertEqual(after.currentExercise?.sets.first?.durationMS, 12000)
    do {
      try await r.correctSet(
        workoutID: w.id, exerciseID: ex.id, original: set, repetitions: nil, durationMS: 14000,
        weightGrams: 3900)
      XCTFail("Concurrent stale edit accepted")
    } catch {}
    let latest = try await r.goalContext(exerciseID: "l-sit")
    XCTAssertEqual(latest.adopted, goal)
    XCTAssertEqual(latest.suggestion?.reason, .duration)
    XCTAssertEqual(
      latest.suggestion?.goal.definition.durationSeconds, goal.definition.durationSeconds)
    XCTAssertEqual(latest.suggestion?.goal.load.grams, 0)
  }
  func testHistoricalEditAndCatalogueDeletionPreserveFrozenGoal() async throws {
    let r = try SportRepository(path: ":memory:")
    let configuration = try await r.snapshot()
    var schedule = try XCTUnwrap(configuration.schedules.first { $0.id == "pull-abs" })
    schedule.weekday = 1
    try await r.saveSchedule(schedule)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    let goal = try XCTUnwrap(context.suggestion?.goal)
    try await r.saveGoal(goal, original: nil)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    try await r.cancelWorkout(id: w.id, now: now + 1000)
    let original = try await r.workout(id: w.id)
    let draft = ManualWorkout(
      id: w.id, name: "Corrigée", performedAt: now,
      exercises: original.exercises.map {
        ManualWorkoutExercise(
          catalogueID: $0.definition.id, tracking: $0.definition.tracking, sets: [],
          feelingTenths: nil)
      })
    try await r.updateHistoricalWorkout(
      draft, original: original, now: now + 2000, calendar: calendar)
    try await r.deleteExercise(id: "chin-ups")
    let stored = try await r.workout(id: w.id)
    XCTAssertEqual(stored.exercises.first?.goal, goal)
    XCTAssertEqual(stored.exercises.first?.definition, original.exercises.first?.definition)
  }
  func testUnavailableGoalBlocksStartAndLeavesNoPartialWorkout() async throws {
    let r = try SportRepository(path: ":memory:")
    let configuration = try await r.snapshot()
    var schedule = try XCTUnwrap(configuration.schedules.first { $0.id == "pull-abs" })
    schedule.weekday = 1
    try await r.saveSchedule(schedule)
    let context = try await r.goalContext(exerciseID: "chin-ups")
    var goal = try XCTUnwrap(context.suggestion?.goal)
    let snapshot = try await r.snapshot()
    goal.load = try XCTUnwrap(
      WeightInventory.loads(items: snapshot.weightItems).first { $0.grams == 4500 })
    try await r.saveGoal(goal, original: nil)
    try await r.deleteWeightItem(id: "programming-books")
    do {
      _ = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
      XCTFail("Unavailable goal started")
    } catch {}
    let overview = try await r.workoutOverview(now: now)
    XCTAssertNil(overview.active)
    XCTAssertTrue(overview.history.isEmpty)
    let replacement = try await r.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar, loadOverrides: ["chin-ups": .bodyweight]
    )
    XCTAssertEqual(replacement.currentExercise?.goal?.load.grams, 0)
    let unchanged = try await r.goalContext(exerciseID: "chin-ups")
    XCTAssertEqual(unchanged.adopted, goal)
  }
  func testActiveAttendanceUsesLocalGregorianDateAndCalendarDayAcrossDST() async throws {
    let r = try SportRepository(path: ":memory:")
    let configuration = try await r.snapshot()
    var schedule = try XCTUnwrap(configuration.schedules.first { $0.id == "pull-abs" })
    schedule.weekday = 1
    try await r.saveSchedule(schedule)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    let ex = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: ex.id, number: 1, now: now)
    try await r.recordSet(
      workoutID: w.id, exerciseID: ex.id, number: 1, repetitions: 8, weightGrams: 0, now: now + 1000
    )
    let overview = try await r.workoutOverview(now: now + 2000)
    let ending = Date(timeIntervalSince1970: Double(now + 2000) / 1000)
    let days = TrainingAnalytics.attendance(
      history: TrainingAnalytics.summaries(in: overview), ending: ending, calendar: calendar)
    XCTAssertEqual(days.last?.key, "2026-10-12")
    XCTAssertEqual(days.last?.state, .neutral)
    XCTAssertEqual(days.last?.workouts.first?.id, w.id)
    XCTAssertNil(TrainingAnalytics.date(for: "2026-02-30", calendar: calendar))
    var paris = Calendar(identifier: .gregorian)
    paris.timeZone = TimeZone(identifier: "Europe/Paris")!
    let end = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
    let dst = TrainingAnalytics.attendance(history: [], ending: end, weeks: 2, calendar: paris)
    XCTAssertEqual(
      dst.map(\.key),
      [
        "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24",
        "2026-10-25", "2026-10-26",
      ])
    XCTAssertEqual(Set(dst.map(\.key)).count, dst.count)
  }
}
