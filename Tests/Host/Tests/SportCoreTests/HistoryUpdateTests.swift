import Foundation
import XCTest

@testable import SportCore

final class HistoryUpdateTests: XCTestCase, @unchecked Sendable {
  private let now = 1_791_720_000_000
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }
  private func draft(_ id: String, time: Int, reps: Int = 12) -> ManualWorkout {
    ManualWorkout(
      id: id, name: "Séance", performedAt: time,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: (0..<4).map { _ in ManualWorkoutSet(repetitions: reps, weightGrams: 3900) },
          feelingTenths: 70)
      ])
  }
  func testUpdateKeepsIdentityArchivedDefinitionAndRefreshesLatestByCalendarDate() async throws {
    let repository = try SportRepository(path: ":memory:")
    try await repository.addHistoricalWorkout(
      draft("older", time: now - 172_800_000), now: now, calendar: calendar)
    try await repository.addHistoricalWorkout(
      draft("newer", time: now - 86_400_000, reps: 10), now: now, calendar: calendar)
    let original = try await repository.workout(id: "older")
    try await repository.deleteExercise(id: "chin-ups")
    var edit = draft("older", time: now)
    edit.name = "Corrigée"
    try await repository.updateHistoricalWorkout(
      edit, original: original, now: now, calendar: calendar)
    let saved = try await repository.workout(id: "older")
    XCTAssertEqual(saved.name, "Corrigée")
    XCTAssertEqual(saved.id, original.id)
    XCTAssertEqual(saved.scheduleID, original.scheduleID)
    XCTAssertEqual(saved.exercises.first?.definition, original.exercises.first?.definition)
    let last = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "")
    XCTAssertEqual(last?.sets.first?.repetitions, 12)
    let records = try await repository.exerciseHistory(exerciseID: "chin-ups")
    XCTAssertEqual(records.map(\.workoutID), ["older", "newer"])
    let archived = try await repository.historyExercises()
    XCTAssertTrue(archived.contains { $0.id == "chin-ups" })
    try await repository.deleteHistoricalWorkout(id: "older")
    let after = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "")
    XCTAssertEqual(after?.sets.first?.repetitions, 10)
  }
  func testStaleFutureAndInvalidEditsCannotOverwriteOrResurrect() async throws {
    let repository = try SportRepository(path: ":memory:")
    let first = draft("one", time: now - 86_400_000)
    try await repository.addHistoricalWorkout(first, now: now, calendar: calendar)
    let original = try await repository.workout(id: "one")
    var invalid = first
    invalid.exercises[0].sets[0].repetitions = 0
    do {
      try await repository.updateHistoricalWorkout(
        invalid, original: original, now: now, calendar: calendar)
      XCTFail("Invalid edit accepted")
    } catch {}
    let untouched = try await repository.workout(id: "one")
    XCTAssertEqual(untouched, original)
    var future = first
    future.performedAt = now + 86_400_000
    do {
      try await repository.updateHistoricalWorkout(
        future, original: original, now: now, calendar: calendar)
      XCTFail("Future edit accepted")
    } catch {}
    var changed = first
    changed.name = "Updated"
    try await repository.updateHistoricalWorkout(
      changed, original: original, now: now, calendar: calendar)
    do {
      try await repository.updateHistoricalWorkout(
        first, original: original, now: now, calendar: calendar)
      XCTFail("Stale edit accepted")
    } catch {}
    try await repository.deleteHistoricalWorkout(id: "one")
    do {
      try await repository.updateHistoricalWorkout(
        first, original: original, now: now, calendar: calendar)
      XCTFail("Deleted entry recreated")
    } catch {}
    let overview = try await repository.workoutOverview(now: now)
    XCTAssertTrue(overview.history.isEmpty)
  }
  func testActiveEditRejectedAndCancelledStatusPreservedWithMissingFeeling() async throws {
    let repository = try SportRepository(path: ":memory:")
    let session = try await repository.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar)
    var edit = ManualWorkout(
      id: session.id, name: "Abandonnée corrigée", performedAt: now,
      exercises: session.exercises.map {
        ManualWorkoutExercise(
          catalogueID: $0.definition.id, tracking: $0.definition.tracking, sets: [],
          feelingTenths: nil)
      })
    do {
      try await repository.updateHistoricalWorkout(
        edit, original: session, now: now, calendar: calendar)
      XCTFail("Active workout edited")
    } catch {}
    try await repository.cancelWorkout(id: session.id, now: now + 1000)
    let cancelled = try await repository.workout(id: session.id)
    edit.name = "Abandonnée"
    try await repository.updateHistoricalWorkout(
      edit, original: cancelled, now: now + 2000, calendar: calendar)
    let saved = try await repository.workout(id: session.id)
    XCTAssertEqual(saved.status, .cancelled)
    XCTAssertNil(saved.exercises.first?.feelingTenths)
    XCTAssertEqual(saved.scheduleID, session.scheduleID)
    let last = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "")
    XCTAssertNil(last)
  }

  func testCorrectingManualSeriesCountMakesEligibleCurrentGoal() async throws {
    let repository = try SportRepository(path: ":memory:")
    var entry = draft("correction", time: now - 86_400_000)
    entry.exercises[0].sets.removeLast()
    try await repository.addHistoricalWorkout(entry, now: now, calendar: calendar)
    let original = try await repository.workout(id: entry.id)
    entry.exercises[0].sets.append(ManualWorkoutSet(repetitions: 12, weightGrams: 3900))
    try await repository.updateHistoricalWorkout(
      entry, original: original, now: now, calendar: calendar)
    let previous = try await repository.previousPerformance(
      exerciseID: "chin-ups", excludingWorkoutID: "")
    let snapshot = try await repository.snapshot()
    let target = try XCTUnwrap(snapshot.exercises.first { $0.id == "chin-ups" })
    XCTAssertEqual(previous?.definition.setCount, 3)  // preserve original metadata
    XCTAssertEqual(previous?.sets.count, 4)
    XCTAssertEqual(
      Progression.assess(
        target: target, previous: previous,
        loads: try WeightInventory.loads(items: snapshot.weightItems)
      ).status, .increase)
  }

  func testCalendarKeysAreGregorianWithSuppliedLocalTimezone() {
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = TimeZone(secondsFromGMT: 0)!
    XCTAssertEqual(WorkoutClock.dayKey(now, calendar: buddhist), "2026-10-11")
    buddhist.timeZone = TimeZone(secondsFromGMT: 14 * 3600)!
    XCTAssertEqual(WorkoutClock.dayKey(now, calendar: buddhist), "2026-10-12")
  }
}
