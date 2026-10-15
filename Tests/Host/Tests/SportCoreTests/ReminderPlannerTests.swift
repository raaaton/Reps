import Foundation
import XCTest

@testable import SportCore

final class ReminderPlannerTests: XCTestCase, @unchecked Sendable {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Paris")!
    return value
  }
  private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
  private func context() async throws -> ReminderContext {
    let repository = try SportRepository(path: ":memory:")
    var schedule = try await repository.snapshot().schedules.first { $0.id == "legs" }!
    schedule.reminderMinutes = 18 * 60 + 17
    try await repository.saveSchedule(schedule)
    try await repository.saveNotificationPreferences(
      NotificationPreferences(workoutsEnabled: true, photosEnabled: true, photoMinutes: 360))
    return try await repository.reminderContext()
  }
  func testConcreteHorizonMinutesAndMonthlyWithoutPrivateContent() async throws {
    let plan = try ReminderPlanner.plan(
      context: await context(), now: date("2026-10-12T10:00:00Z"), calendar: calendar)
    let workouts = plan.filter { $0.kind == .workout }
    XCTAssertEqual(
      workouts.map(\.id),
      [
        "sport.local.workout.legs.2026-10-13", "sport.local.workout.legs.2026-10-20",
        "sport.local.workout.legs.2026-10-27", "sport.local.workout.legs.2026-11-03",
      ])
    XCTAssertEqual(workouts.first?.components.hour, 18)
    XCTAssertEqual(workouts.first?.components.minute, 17)
    XCTAssertTrue(workouts.allSatisfy { !$0.repeats })
    let photo = try XCTUnwrap(plan.first { $0.kind == .photos })
    XCTAssertTrue(photo.repeats)
    XCTAssertEqual(photo.components.day, 1)
    XCTAssertEqual(photo.components.hour, 6)
    XCTAssertNil(photo.components.year)
    XCTAssertNil(photo.components.month)
    XCTAssertNil(photo.components.timeZone)
  }
  func testStartedDateSuppressesReminderAndDeletionRestoresIt() async throws {
    let repository = try SportRepository(path: ":memory:")
    var schedule = try await repository.snapshot().schedules.first { $0.id == "legs" }!
    schedule.reminderMinutes = 18 * 60
    try await repository.saveSchedule(schedule)
    try await repository.saveNotificationPreferences(
      NotificationPreferences(workoutsEnabled: true, photosEnabled: false, photoMinutes: 360))
    let now = date("2026-10-13T10:00:00Z")
    let ms = Int(now.timeIntervalSince1970 * 1000)
    let workout = try await repository.startWorkout(scheduleID: "legs", now: ms, calendar: calendar)
    var context = try await repository.reminderContext()
    XCTAssertFalse(
      try ReminderPlanner.plan(context: context, now: now, calendar: calendar).contains {
        $0.id.hasSuffix("2026-10-13")
      })
    try await repository.cancelWorkout(id: workout.id, now: ms + 1000)
    context = try await repository.reminderContext()
    XCTAssertFalse(
      try ReminderPlanner.plan(context: context, now: now, calendar: calendar).contains {
        $0.id.hasSuffix("2026-10-13")
      })
    try await repository.deleteHistoricalWorkout(id: workout.id)
    context = try await repository.reminderContext()
    XCTAssertTrue(
      try ReminderPlanner.plan(context: context, now: now, calendar: calendar).contains {
        $0.id.hasSuffix("2026-10-13")
      })
  }
  func testOffUnsetDisabledAndPastHourProduceNoWorkout() async throws {
    var context = try await context()
    context.preferences.workoutsEnabled = false
    context.preferences.photosEnabled = false
    XCTAssertEqual(
      try ReminderPlanner.plan(
        context: context, now: date("2026-10-13T10:00:00Z"), calendar: calendar), [])
    context.preferences.workoutsEnabled = true
    context.training.schedules[0].reminderMinutes = nil
    XCTAssertEqual(
      try ReminderPlanner.plan(
        context: context, now: date("2026-10-13T10:00:00Z"), calendar: calendar), [])
    context.training.schedules[0].reminderMinutes = 18 * 60 + 17
    context.training.schedules[0].isEnabled = false
    XCTAssertEqual(
      try ReminderPlanner.plan(
        context: context, now: date("2026-10-13T10:00:00Z"), calendar: calendar), [])
    context.training.schedules[0].isEnabled = true
    let plan = try ReminderPlanner.plan(
      context: context, now: date("2026-10-13T16:18:00Z"), calendar: calendar)
    XCTAssertFalse(plan.contains { $0.id.hasSuffix("2026-10-13") })
  }
  func testDSTGapAndRepeatedTimeKeepLocalIntent() async throws {
    var context = try await context()
    context.preferences.photosEnabled = false
    context.training.schedules = [
      TrainingSchedule(
        id: "sunday", name: "Séance", weekday: 7, isEnabled: true, reminderMinutes: 150,
        exerciseIDs: ["chin-ups"])
    ]
    let spring = try ReminderPlanner.plan(
      context: context, now: date("2026-03-28T12:00:00Z"), calendar: calendar)
    let gap = try XCTUnwrap(spring.first)
    XCTAssertEqual(gap.components.day, 29)
    XCTAssertEqual(gap.components.hour, 3)
    XCTAssertEqual(gap.components.minute, 30)
    let autumn = try ReminderPlanner.plan(
      context: context, now: date("2026-10-24T12:00:00Z"), calendar: calendar)
    XCTAssertEqual(autumn.first?.date, date("2026-10-25T00:30:00Z"))
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = calendar.timeZone
    XCTAssertEqual(
      try ReminderPlanner.plan(
        context: context, now: date("2026-10-24T12:00:00Z"), calendar: buddhist), autumn)
  }
  func testPreferencesPersistenceValidationAndAtomicRollback() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SportRepository(path: path)
    let saved = NotificationPreferences(
      workoutsEnabled: true, photosEnabled: true, photoMinutes: 377)
    try await repository.saveNotificationPreferences(saved)
    do {
      try await repository.saveNotificationPreferences(
        NotificationPreferences(workoutsEnabled: false, photosEnabled: false, photoMinutes: 1440))
      XCTFail("Invalid time saved")
    } catch {}
    let reopened = try SportRepository(path: path)
    let context = try await reopened.reminderContext()
    XCTAssertEqual(context.preferences, saved)
    XCTAssertEqual(context.training.restSeconds, 180)
    XCTAssertEqual(context.training.weightItems.count, 3)
  }
}
