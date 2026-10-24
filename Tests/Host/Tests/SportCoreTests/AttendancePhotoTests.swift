import Foundation
import XCTest

@testable import SportCore

final class AttendancePhotoTests: XCTestCase {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Paris")!
    return value
  }
  private var end: Date { ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")! }
  func testPhotoOnlyHistoryStartsAtEarliestPhotoWithoutInventingCompletedOrMissedWorkouts() {
    let days = TrainingAnalytics.attendance(
      history: [], scheduledWeekdays: [1, 2, 3, 4, 5, 6, 7], ending: end,
      calendar: calendar, photoCounts: ["2026-10-18": 3, "2026-10-25": 1])
    XCTAssertEqual(days.first?.key, "2026-10-12")
    XCTAssertEqual(days.first { $0.key == "2026-10-18" }?.photoCount, 3)
    XCTAssertEqual(days.first { $0.key == "2026-10-25" }?.photoCount, 1)
    XCTAssertTrue(days.allSatisfy { $0.state == .neutral && $0.workouts.isEmpty })
    XCTAssertEqual(Set(days.map(\.key)).count, days.count)
  }
  func testPhotosPreserveCompletedMissedAndTodayStates() {
    let workout = WorkoutSummary(
      id: "one", scheduleID: "s", name: "Training", dayKey: "2026-10-19",
      startedAt: 0, endedAt: 1, status: .completed, setCount: 4)
    let days = TrainingAnalytics.attendance(
      history: [workout], scheduledWeekdays: [1, 7], ending: end,
      calendar: calendar, photoCounts: ["2026-10-19": 2, "2026-10-25": 1, "2026-10-26": 3])
    XCTAssertEqual(days.first { $0.key == "2026-10-19" }?.state, .completed)
    XCTAssertEqual(days.first { $0.key == "2026-10-19" }?.photoCount, 2)
    XCTAssertEqual(days.first { $0.key == "2026-10-25" }?.state, .missed)
    XCTAssertEqual(days.first { $0.key == "2026-10-25" }?.photoCount, 1)
    XCTAssertEqual(days.last?.state, .neutral)
    XCTAssertEqual(days.last?.photoCount, 3)
    XCTAssertEqual(days.filter { $0.state == .completed }.count, 1)
  }
  func testInvalidFutureAndNonpositivePhotoCountsCannotExtendHistory() {
    let days = TrainingAnalytics.attendance(
      history: [], ending: end, calendar: calendar,
      photoCounts: ["2026-02-30": 1, "2025-01-01": 0, "2024-01-01": -1, "2026-11-01": 2])
    XCTAssertEqual(days.first?.key, "2026-10-26")
    XCTAssertTrue(days.allSatisfy { $0.photoCount == 0 })
  }
  func testExplicitWeekRangeStillBoundsOldPhotoHistory() {
    let days = TrainingAnalytics.attendance(
      history: [], ending: end, weeks: 1, calendar: calendar,
      photoCounts: ["2026-01-01": 2, "2026-10-26": 1])
    XCTAssertEqual(days.count, 1)
    XCTAssertEqual(days.first?.photoCount, 1)
  }
}
