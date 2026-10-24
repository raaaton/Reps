import Foundation
import XCTest

@testable import RepsCore

final class WorkoutStreakTests: XCTestCase {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Paris")!
    return value
  }
  private func workout(_ day: String, status: WorkoutStatus = .completed) -> WorkoutSummary {
    WorkoutSummary(
      id: UUID().uuidString, scheduleID: "s", name: "Training", dayKey: day,
      startedAt: 0, endedAt: status == .active ? nil : 1, status: status, setCount: 4)
  }
  private func attendance(
    _ history: [WorkoutSummary], ending: String, planned: Set<Int> = [1, 3, 5],
    photos: [String: Int] = [:]
  ) -> [AttendanceDay] {
    TrainingAnalytics.attendance(
      history: history, scheduledWeekdays: planned,
      ending: TrainingAnalytics.date(for: ending, calendar: calendar)!, calendar: calendar,
      photoCounts: photos)
  }
  private func streak(_ history: [WorkoutSummary], ending: String, planned: Set<Int> = [1, 3, 5])
    -> Int
  {
    WorkoutStreak.days(
      attendance: attendance(history, ending: ending, planned: planned),
      workoutsPerWeek: planned.count, calendar: calendar)
  }
  func testCalendarDaysIncludeRestDaysAndTodayInsteadOfCountingCompletedWorkouts() {
    let history = [
      "2026-10-05", "2026-10-07", "2026-10-09", "2026-10-12", "2026-10-14", "2026-10-16",
    ].map { workout($0) }
    XCTAssertEqual(streak(history, ending: "2026-10-19"), 15)
    XCTAssertEqual(streak([workout("2026-10-05")], ending: "2026-10-06"), 2)
  }
  func testThreeConsecutiveMissedScheduledWorkoutsBreakOnlyAfterTheThirdDayHasEnded() {
    let history = [workout("2026-10-05")]
    XCTAssertEqual(streak(history, ending: "2026-10-12"), 8)
    XCTAssertEqual(streak(history, ending: "2026-10-13"), 0)
  }
  func testNewCompletionResetsMissCounterAndBrokenStreakRestartsAtOne() {
    XCTAssertEqual(
      streak([workout("2026-10-05"), workout("2026-10-09")], ending: "2026-10-15"), 11)
    let restarted = [workout("2026-10-05"), workout("2026-10-14")]
    XCTAssertEqual(streak(restarted, ending: "2026-10-14"), 1)
    XCTAssertEqual(streak(restarted, ending: "2026-10-15"), 2)
  }
  func testThresholdFollowsTwoOrFourWeeklyWorkouts() {
    let history = [workout("2026-10-05")]
    for planned: Set<Int> in [[1, 4], [1, 2, 4, 6]] {
      XCTAssertEqual(streak(history, ending: "2026-10-12", planned: planned), 8)
      XCTAssertEqual(streak(history, ending: "2026-10-13", planned: planned), 0)
    }
    let days = attendance(history, ending: "2026-10-13")
    XCTAssertEqual(WorkoutStreak.days(attendance: days, workoutsPerWeek: 2, calendar: calendar), 0)
    XCTAssertEqual(WorkoutStreak.days(attendance: days, workoutsPerWeek: 4, calendar: calendar), 9)
  }
  func testEmptyHistoryNoScheduleAndPhotosAloneHaveNoStreak() {
    XCTAssertEqual(streak([], ending: "2026-10-19"), 0)
    XCTAssertEqual(streak([workout("2026-10-05")], ending: "2026-10-19", planned: []), 0)
    let days = attendance([], ending: "2026-10-19", photos: ["2026-10-05": 3])
    XCTAssertEqual(WorkoutStreak.days(attendance: days, workoutsPerWeek: 3, calendar: calendar), 0)
  }
  func testCancelledActiveAndPhotoDaysCannotSaveABrokenStreak() {
    let history = [
      workout("2026-10-05"), workout("2026-10-07", status: .cancelled),
      workout("2026-10-12", status: .active),
    ]
    let days = attendance(
      history, ending: "2026-10-13", photos: ["2026-10-07": 3, "2026-10-12": 1])
    XCTAssertEqual(WorkoutStreak.days(attendance: days, workoutsPerWeek: 3, calendar: calendar), 0)
  }
  func testDuplicateAndOffScheduleCompletionsCountDaysOnce() {
    let history = [workout("2026-10-05"), workout("2026-10-05"), workout("2026-10-08")]
    XCTAssertEqual(streak(history, ending: "2026-10-14"), 10)
  }
  func testCalendarCountingAcrossDSTDoesNotUseElapsedHours() {
    XCTAssertEqual(streak([workout("2026-10-24")], ending: "2026-10-26"), 3)
  }
  func testExactDaysFormattingKeepsUnitsAndSingularForms() {
    XCTAssertEqual(StreakDisplayUnit.days.label(days: 0), "0 days")
    XCTAssertEqual(StreakDisplayUnit.days.label(days: 1), "1 day")
    XCTAssertEqual(StreakDisplayUnit.days.label(days: 15), "15 days")
    XCTAssertEqual(StreakDisplayUnit.days.label(days: 372), "372 days")
  }
  func testLargestCompleteUnitUsesFloorAndChoosesYearsBeforeMonthsBeforeWeeks() {
    let examples: [(Int, String)] = [
      (-1, "0 days"), (0, "0 days"), (1, "1 day"), (6, "6 days"),
      (7, "1 week"), (14, "2 weeks"), (15, "2 weeks"), (29, "4 weeks"), (30, "1 month"),
      (60, "2 months"), (364, "12 months"), (365, "1 year"), (372, "1 year"), (730, "2 years"),
    ]
    for (days, expected) in examples {
      XCTAssertEqual(StreakDisplayUnit.largestUnit.label(days: days), expected)
    }
  }
}
