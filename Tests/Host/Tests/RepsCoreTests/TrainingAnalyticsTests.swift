import Foundation
import XCTest

@testable import RepsCore

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
    XCTAssertEqual(days.first { $0.key == "2026-10-10" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-09" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-12" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-11" }?.workouts.count, 2)
    XCTAssertTrue(days.allSatisfy { $0.date <= date("2026-10-12T12:00:00Z") })
  }
  func testMissedDaysStartAtFirstCompletedWorkoutAndExcludeTodayAndRestDays() {
    func workout(_ key: String, _ status: WorkoutStatus) -> WorkoutSummary {
      WorkoutSummary(
        id: key, scheduleID: "s", name: "Workout", dayKey: key,
        startedAt: 0, endedAt: 1, status: status, setCount: 1)
    }
    let records = [
      workout("2026-10-12", .completed), workout("2026-10-15", .completed),
      workout("2026-10-16", .cancelled), workout("2026-10-09", .cancelled),
    ]
    let days = TrainingAnalytics.attendance(
      history: records, scheduledWeekdays: [1, 3, 5, 7],
      ending: date("2026-10-18T12:00:00Z"), weeks: 2, calendar: calendar)
    XCTAssertEqual(days.filter { $0.state == .missed }.map(\.key), ["2026-10-14", "2026-10-16"])
    XCTAssertEqual(days.filter { $0.state == .completed }.map(\.key), ["2026-10-12", "2026-10-15"])
    XCTAssertEqual(days.last?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-09" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-17" }?.state, .neutral)
    XCTAssertEqual(days.first { $0.key == "2026-10-16" }?.workouts.first?.status, .cancelled)
  }
  func testNoCompletedWorkoutMeansNoMissedDays() {
    let cancelled = WorkoutSummary(
      id: "c", scheduleID: "s", name: "Cancelled",
      dayKey: "2026-10-12", startedAt: 0, endedAt: 1, status: .cancelled, setCount: 4)
    let days = TrainingAnalytics.attendance(
      history: [cancelled], scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7],
      ending: date("2026-10-18T12:00:00Z"), calendar: calendar)
    XCTAssertTrue(days.allSatisfy { $0.state == .neutral })
  }
  func testFirstWorkoutOutsideVisiblePeriodStillEnablesMissedDaysAcrossDST() {
    var paris = calendar
    paris.timeZone = TimeZone(identifier: "Europe/Paris")!
    let first = WorkoutSummary(
      id: "old", scheduleID: "removed", name: "Old",
      dayKey: "2026-09-01", startedAt: 0, endedAt: 1, status: .completed, setCount: 4)
    let days = TrainingAnalytics.attendance(
      history: [first], scheduledWeekdays: [7],
      ending: date("2026-10-26T12:00:00Z"), weeks: 2, calendar: paris)
    XCTAssertEqual(days.filter { $0.state == .missed }.map(\.key), ["2026-10-25"])
    XCTAssertEqual(Set(days.map(\.key)).count, days.count)
  }
  func testDefaultAttendanceStartsInWeekOfFirstCompletedWorkout() {
    let first = WorkoutSummary(
      id: "first", scheduleID: "s", name: "First",
      dayKey: "2026-10-11", startedAt: 0, endedAt: 1, status: .completed, setCount: 4)
    let days = TrainingAnalytics.attendance(
      history: [first], ending: date("2026-10-18T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(days.first?.key, "2026-10-05")
    XCTAssertEqual(days.count, 14)
    let empty = TrainingAnalytics.attendance(
      history: [], ending: date("2026-10-18T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(empty.first?.key, "2026-10-12")
    XCTAssertEqual(empty.count, 7)
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
    let r = try RepsRepository(path: ":memory:")
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
