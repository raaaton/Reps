import Foundation
import XCTest

@testable import SportCore

final class BodyWeightReminderTests: XCTestCase, @unchecked Sendable {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Paris")!
    return value
  }
  private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  private func context() async throws -> ReminderContext {
    let repository = try SportRepository(path: ":memory:")
    return ReminderContext(
      training: try await repository.snapshot(),
      preferences: NotificationPreferences(
        weightEnabled: true, weightWeekday: 2, weightMinutes: 8 * 60 + 15), startedDays: [])
  }

  func testWeeklyCalendarHorizonSkipsMeasuredDayAndPastTime() async throws {
    var context = try await context()
    context.bodyWeightDays = ["2026-10-20"]
    let plan = try ReminderPlanner.plan(
      context: context, now: date("2026-10-13T07:00:00Z"), calendar: calendar)
    XCTAssertEqual(
      plan.map(\.id),
      [
        "sport.local.bodyweight.2026-10-27", "sport.local.bodyweight.2026-11-03",
      ])
    XCTAssertTrue(plan.allSatisfy { $0.kind == .bodyWeight && !$0.repeats })
    XCTAssertEqual(plan.first?.components.hour, 8)
    XCTAssertEqual(plan.first?.components.minute, 15)
    context.preferences.weightEnabled = false
    XCTAssertTrue(
      try ReminderPlanner.plan(
        context: context, now: date("2026-10-13T07:00:00Z"), calendar: calendar
      ).isEmpty)
  }

  func testSundayAndDSTKeepLocalTimeIntent() async throws {
    var context = try await context()
    context.preferences.weightWeekday = 7
    context.preferences.weightMinutes = 150
    let spring = try ReminderPlanner.plan(
      context: context, now: date("2026-03-28T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(spring.first?.id, "sport.local.bodyweight.2026-03-29")
    XCTAssertEqual(spring.first?.components.hour, 3)
    XCTAssertEqual(spring.first?.components.minute, 30)
    let autumn = try ReminderPlanner.plan(
      context: context, now: date("2026-10-24T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(autumn.first?.date, date("2026-10-25T00:30:00Z"))
  }

  func testLegacyJSONDefaultsWeightOffAndValidatesExplicitSchedule() throws {
    let legacy = Data(#"{"workoutsEnabled":true,"photosEnabled":false,"photoMinutes":377}"#.utf8)
    let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: legacy)
    XCTAssertFalse(decoded.weightEnabled)
    XCTAssertNil(decoded.weightWeekday)
    XCTAssertNil(decoded.weightMinutes)
    XCTAssertThrowsError(try NotificationPreferences(weightEnabled: true).validated())
    XCTAssertThrowsError(try NotificationPreferences(weightWeekday: 0).validated())
    XCTAssertThrowsError(try NotificationPreferences(weightWeekday: 8).validated())
    XCTAssertThrowsError(try NotificationPreferences(weightMinutes: -1).validated())
    XCTAssertThrowsError(try NotificationPreferences(weightMinutes: 1440).validated())
    let configured = NotificationPreferences(
      weightEnabled: true, weightWeekday: 1, weightMinutes: 0)
    XCTAssertEqual(try configured.validated(), configured)
    XCTAssertEqual(
      try JSONDecoder().decode(
        NotificationPreferences.self,
        from: JSONEncoder().encode(configured)), configured)
  }

  func testBodyWeightRoutingUsesProgressAndRejectsMismatchedKind() {
    XCTAssertEqual(
      ReminderPolicy.destination(
        identifier: "sport.local.bodyweight.2026-10-20", kind: "bodyWeight"), .bodyWeight)
    XCTAssertEqual(ReminderDestination.bodyWeight.tabIndex, 2)
    XCTAssertEqual(ReminderDestination.progression.tabIndex, 2)
    XCTAssertEqual(ReminderDestination.today.tabIndex, 0)
    XCTAssertNil(
      ReminderPolicy.destination(
        identifier: "sport.local.bodyweight.2026-10-20", kind: "photos"))
  }

  func testPreferencesPersistAndMeasuredDaysAreReadWithoutHistoryLoss() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SportRepository(path: path)
    let preferences = NotificationPreferences(
      workoutsEnabled: true, photosEnabled: true, photoMinutes: 377,
      weightEnabled: true, weightWeekday: 6, weightMinutes: 545)
    try await repository.saveNotificationPreferences(preferences)
    let reopened = try SportRepository(path: path)
    let context = try await reopened.reminderContext()
    XCTAssertEqual(context.preferences, preferences)
    XCTAssertTrue(context.bodyWeightDays.isEmpty)
    XCTAssertEqual(context.training.weightItems.count, 3)
    try await reopened.saveBodyWeight(
      BodyWeightMeasurement(id: "measured", dayKey: "2026-10-13", grams: 72_400), original: nil,
      now: Int(date("2026-10-13T12:00:00Z").timeIntervalSince1970 * 1000), calendar: calendar)
    let measured = try await reopened.reminderContext()
    XCTAssertEqual(measured.bodyWeightDays, ["2026-10-13"])
    do {
      try await reopened.saveNotificationPreferences(NotificationPreferences(weightEnabled: true))
      XCTFail("Incomplete reminder was saved")
    } catch {}
    let unchanged = try await reopened.reminderContext()
    XCTAssertEqual(unchanged.preferences, preferences)
  }
}
