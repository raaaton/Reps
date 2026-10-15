import Foundation
import XCTest

@testable import SportCore

final class TrainingAnalyticsTests: XCTestCase, @unchecked Sendable {
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
  func testAttendanceGroupsDaysWithoutInventingMissedSessions() {
    let records = [
      WorkoutSummary(
        id: "one", scheduleID: "manual", name: "A", dayKey: "2026-10-11", startedAt: 100,
        endedAt: 100, status: .completed, setCount: 4),
      WorkoutSummary(
        id: "two", scheduleID: "deleted", name: "B", dayKey: "2026-10-11", startedAt: 101,
        endedAt: 110, status: .cancelled, setCount: 2),
      WorkoutSummary(
        id: "three", scheduleID: "manual", name: "C", dayKey: "2026-10-10", startedAt: 100,
        endedAt: 100, status: .cancelled, setCount: 1),
      WorkoutSummary(
        id: "empty", scheduleID: "s", name: "D", dayKey: "2026-10-09", startedAt: 100, endedAt: 100,
        status: .cancelled, setCount: 0),
    ]
    let days = TrainingAnalytics.attendance(
      history: records, ending: date("2026-10-12T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(days.first { $0.key == "2026-10-11" }?.state, .completed)
    XCTAssertEqual(days.first { $0.key == "2026-10-10" }?.state, .partial)
    XCTAssertEqual(days.first { $0.key == "2026-10-09" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-12" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-11" }?.workouts.count, 2)
    XCTAssertTrue(days.allSatisfy { $0.date <= date("2026-10-12T12:00:00Z") })
  }
  func testElapsedDurationIsWallClockAndManualDurationIsUnknown() {
    let real = WorkoutSession(
      id: "w", scheduleID: "removed", name: "W", dayKey: "2026-10-11", startedAt: 1000,
      endedAt: 181000, status: .completed, restSeconds: 180, exercises: [], rest: nil)
    XCTAssertEqual(real.totalElapsedMS, 180000)
    let manual = WorkoutSession(
      id: "m", scheduleID: "manual", name: "M", dayKey: "2026-10-11", startedAt: 1000,
      endedAt: 1000, status: .completed, restSeconds: 180, exercises: [], rest: nil)
    XCTAssertNil(manual.totalElapsedMS)
  }
  func testSamplesKeepSetsSeparateAndRejectWrongModeAndCancelledRecords() async throws {
    let r = try SportRepository(path: ":memory:")
    let draft = ManualWorkout(
      id: "history", name: "History", performedAt: 1_791_720_000_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: [
            ManualWorkoutSet(repetitions: 12, weightGrams: 3900),
            ManualWorkoutSet(repetitions: 10, weightGrams: 4500),
          ], feelingTenths: 75)
      ])
    try await r.addHistoricalWorkout(draft, now: 1_791_720_000_000, calendar: calendar)
    let records = try await r.exerciseHistory(exerciseID: "chin-ups")
    let all = TrainingAnalytics.samples(
      records: records, tracking: .repetitions, since: date("2026-10-01T00:00:00Z"),
      calendar: calendar)
    XCTAssertEqual(all.count, 2)
    XCTAssertEqual(all.map(\.repetitions), [12, 10])
    XCTAssertEqual(all.map(\.grams), [3900, 4500])
    XCTAssertEqual(
      TrainingAnalytics.samples(
        records: records, tracking: .repetitions, weight: 3900, since: date("2026-10-01T00:00:00Z"),
        calendar: calendar
      ).count, 1)
    XCTAssertTrue(
      TrainingAnalytics.samples(
        records: records, tracking: .duration, since: date("2026-10-01T00:00:00Z"),
        calendar: calendar
      ).isEmpty)
    XCTAssertTrue(
      TrainingAnalytics.samples(
        records: records, tracking: .repetitions, since: date("2026-11-01T00:00:00Z"),
        calendar: calendar
      ).isEmpty)
  }
  func testChartLoadSelectionMatchesCompletedRecordsAndTrackingMode() {
    func record(
      _ id: String, _ mode: TrackingMode, _ weight: Int, _ status: WorkoutStatus = .completed
    ) -> ExercisePerformance {
      let definition = TrainingExercise(
        id: "x", name: "X", tracking: mode, setCount: 1,
        minimumReps: mode == .repetitions ? 8 : nil, maximumReps: mode == .repetitions ? 12 : nil,
        durationSeconds: nil, isEnabled: true)
      let set = WorkoutSet(
        id: id, number: 1, repetitions: mode == .repetitions ? 10 : nil,
        durationMS: mode == .duration ? 12000 : nil, weightGrams: weight, completedAt: 1)
      return ExercisePerformance(
        workoutID: id, workoutName: id, dayKey: "2026-10-11", status: status,
        exercise: WorkoutExercise(
          id: id, definition: definition, sets: [set], feelingTenths: 75, setStartedAt: nil,
          setWeightGrams: nil, setEndedAt: nil))
    }
    let records = [
      record("timed", .duration, 7500), record("cancelled", .repetitions, 4500, .cancelled),
      record("valid", .repetitions, 3900),
    ]
    XCTAssertEqual(TrainingAnalytics.chartWeights(records: records, tracking: .repetitions), [3900])
    XCTAssertEqual(
      TrainingAnalytics.chartWeight(records: records, tracking: .repetitions, selected: nil), 3900)
    XCTAssertEqual(
      TrainingAnalytics.chartWeight(records: records, tracking: .repetitions, selected: 7500), 3900)
    XCTAssertEqual(
      TrainingAnalytics.chartWeight(records: records, tracking: .duration, selected: nil), 7500)
  }

}
