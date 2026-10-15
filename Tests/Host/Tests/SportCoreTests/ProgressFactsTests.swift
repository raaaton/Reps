import Foundation
import XCTest

@testable import SportCore

final class ProgressFactsTests: XCTestCase, @unchecked Sendable {
  func testFactsCompareEqualConditionsAndSkipDifferentRest() {
    let definition = TrainingExercise(
      id: "x", name: "X", tracking: .repetitions, setCount: 4, minimumReps: 8, maximumReps: 12,
      durationSeconds: nil, isEnabled: true)
    func record(_ reps: [Int], weight: Int = 3900, feeling: Int = 75) -> WorkoutExercise {
      WorkoutExercise(
        id: "ex", definition: definition,
        sets: reps.enumerated().map {
          WorkoutSet(
            id: "\($0.offset)", number: $0.offset + 1, repetitions: $0.element, durationMS: nil,
            weightGrams: weight, completedAt: 100)
        }, feelingTenths: feeling, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
    }
    let old = record([10, 10, 9, 8])
    let current = record([10, 10, 9, 9], feeling: 70)
    let facts = ProgressFacts.compare(
      current: current, previous: old, restSeconds: 180, previousRestSeconds: 180)
    XCTAssertTrue(facts.contains(.repetitionsAdded(1, grams: 3900)))
    XCTAssertTrue(facts.contains(.effortLower(from: 75, to: 70)))
    XCTAssertTrue(
      ProgressFacts.compare(
        current: current, previous: old, restSeconds: 60, previousRestSeconds: 180
      ).isEmpty)
    let heavier = record([8, 8, 8, 8], weight: 4500)
    XCTAssertEqual(
      ProgressFacts.compare(
        current: heavier, previous: old, restSeconds: 180, previousRestSeconds: 180),
      [.loadChanged(from: 3900, to: 4500)])
  }
  func testOverflowAndMissingMetricsNeverCreateFakeFact() {
    let def = TrainingExercise(
      id: "x", name: "X", tracking: .repetitions, setCount: 2, minimumReps: 1, maximumReps: Int.max,
      durationSeconds: nil, isEnabled: true)
    let sets = (1...2).map {
      WorkoutSet(
        id: "s\($0)", number: $0, repetitions: Int.max, durationMS: nil, weightGrams: 0,
        completedAt: 0)
    }
    let value = WorkoutExercise(
      id: "e", definition: def, sets: sets, feelingTenths: 70, setStartedAt: nil,
      setWeightGrams: nil, setEndedAt: nil)
    XCTAssertTrue(
      ProgressFacts.compare(
        current: value, previous: value, restSeconds: 180, previousRestSeconds: 180
      ).isEmpty)
    XCTAssertTrue(
      ProgressFacts.compare(
        current: value, previous: nil, restSeconds: 180, previousRestSeconds: 180
      ).isEmpty)
  }
  func testLowerFeelingDoesNotCountAsProgressWhenOutputDropped() {
    let def = TrainingExercise(
      id: "x", name: "X", tracking: .repetitions, setCount: 1, minimumReps: 8, maximumReps: 12,
      durationSeconds: nil, isEnabled: true)
    func exercise(_ reps: Int, _ feeling: Int) -> WorkoutExercise {
      WorkoutExercise(
        id: "ex", definition: def,
        sets: [
          WorkoutSet(
            id: "set", number: 1, repetitions: reps, durationMS: nil, weightGrams: 3900,
            completedAt: 1)
        ], feelingTenths: feeling, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
    }
    XCTAssertTrue(
      ProgressFacts.compare(
        current: exercise(8, 70), previous: exercise(12, 80), restSeconds: 180,
        previousRestSeconds: 180
      ).isEmpty)
    XCTAssertEqual(
      ProgressFacts.compare(
        current: exercise(12, 70), previous: exercise(12, 80), restSeconds: 180,
        previousRestSeconds: 180), [.effortLower(from: 80, to: 70)])
  }
  func testReportUsesLatestComparablePriorSessionNotIntermediateDifferentRest() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let now = 1_791_720_000_000
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    func draft(_ id: String, _ offset: Int, _ reps: Int) -> ManualWorkout {
      ManualWorkout(
        id: id, name: id, performedAt: now + offset,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: "chin-ups", tracking: .repetitions,
            sets: (1...4).map { _ in ManualWorkoutSet(repetitions: reps, weightGrams: 3900) },
            feelingTenths: 75)
        ])
    }
    try await r.addHistoricalWorkout(
      draft("comparable", -172_800_000, 9), now: now, calendar: calendar)
    try await r.saveRest(seconds: 60)
    try await r.addHistoricalWorkout(
      draft("different", -86_400_000, 8), now: now, calendar: calendar)
    try await r.saveRest(seconds: 180)
    try await r.addHistoricalWorkout(draft("current", 0, 10), now: now, calendar: calendar)
    // Known-chronology fixture: unlike manual entries these workouts have a measured rest context.
    let fixture = try SQLiteDatabase(path: path)
    try fixture.execute("UPDATE workouts SET schedule_id='pull-abs'")
    let reports = try await r.progressReports(workoutID: "current")
    XCTAssertEqual(reports.first?.facts, [.repetitionsAdded(4, grams: 3900)])
    let older = try await r.progressReports(workoutID: "comparable")
    XCTAssertEqual(older.first?.facts, [])
  }

  func testManualRestIsUnknownAndCannotManufactureComparableProgress() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let now = 1_791_720_000_000
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    func draft(_ id: String, _ offset: Int, _ reps: Int) -> ManualWorkout {
      ManualWorkout(
        id: id, name: id, performedAt: now + offset,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: "chin-ups", tracking: .repetitions,
            sets: (1...4).map { _ in ManualWorkoutSet(repetitions: reps, weightGrams: 3900) },
            feelingTenths: 75)
        ])
    }
    try await r.addHistoricalWorkout(draft("known", -172_800_000, 8), now: now, calendar: calendar)
    try await r.addHistoricalWorkout(draft("unknown", -86_400_000, 9), now: now, calendar: calendar)
    try await r.addHistoricalWorkout(draft("current", 0, 10), now: now, calendar: calendar)
    let fixture = try SQLiteDatabase(path: path)
    try fixture.execute("UPDATE workouts SET schedule_id='pull-abs' WHERE id!='unknown'")
    let manualReport = try await r.progressReports(workoutID: "unknown")
    XCTAssertTrue(manualReport.isEmpty)
    let measuredReport = try await r.progressReports(workoutID: "current")
    XCTAssertEqual(measuredReport.first?.facts, [.repetitionsAdded(8, grams: 3900)])
  }

}
