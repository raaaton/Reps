import Foundation
import XCTest

@testable import RepsCore

private actor ReminderSource {
  var value: ReminderContext
  init(_ value: ReminderContext) { self.value = value }
  func read() -> ReminderContext { value }
  func disable() {
    value.preferences.workoutsEnabled = false
    value.preferences.photosEnabled = false
  }
}
private actor ReminderTestTransport: ReminderTransport {
  var requests: [String: ReminderOccurrence] = [:]
  var permission: ReminderAuthorization = .allowed
  var blockNext = false
  var shouldFail = false
  var arrived = false
  var arrivalWaiter: CheckedContinuation<Void, Never>?
  var releaseWaiter: CheckedContinuation<Void, Never>?
  func authorization() -> ReminderAuthorization { permission }
  func pending() -> [PendingReminder] {
    requests.map { PendingReminder(id: $0.key, occurrence: $0.value) }
  }
  func remove(ids: [String]) { for id in ids { requests[id] = nil } }
  func add(_ request: ReminderOccurrence) async throws {
    if shouldFail {
      shouldFail = false
      throw TrainingError.storage
    }
    requests[request.id] = request
    if blockNext {
      blockNext = false
      arrived = true
      arrivalWaiter?.resume()
      arrivalWaiter = nil
      await withCheckedContinuation { releaseWaiter = $0 }
    }
  }
  func prepareBlock() { blockNext = true }
  func failNext() { shouldFail = true }
  func waitUntilBlocked() async {
    if !arrived { await withCheckedContinuation { arrivalWaiter = $0 } }
  }
  func release() {
    releaseWaiter?.resume()
    releaseWaiter = nil
  }
  func deny() { permission = .denied }
}
final class ReminderSyncTests: XCTestCase, @unchecked Sendable {
  func testConcurrentDisableRemovesOldRequestsAndPreservesForeignRequest() async throws {
    let repository = try RepsRepository(path: ":memory:")
    try await repository.saveNotificationPreferences(NotificationPreferences(photosEnabled: true))
    let source = ReminderSource(try await repository.reminderContext())
    let transport = ReminderTestTransport()
    let foreign = ReminderOccurrence(
      id: "another.feature", kind: .photos, title: "Other", body: "Other",
      components: DateComponents(day: 2, hour: 9), repeats: true, date: nil)
    try await transport.add(foreign)
    await transport.prepareBlock()
    let sync = ReminderSynchronizer(transport: transport, source: { await source.read() })
    let first = Task { await sync.refresh() }
    await transport.waitUntilBlocked()
    await source.disable()
    let second = Task { await sync.refresh() }
    await transport.release()
    _ = await first.value
    _ = await second.value
    let remaining = await transport.pending()
    XCTAssertEqual(remaining.map(\.id), ["another.feature"])
  }
  func testDeniedPermissionCancelsManagedOnlyAndFailureIsRetryable() async throws {
    let repository = try RepsRepository(path: ":memory:")
    try await repository.saveNotificationPreferences(NotificationPreferences(photosEnabled: true))
    let context = try await repository.reminderContext()
    let transport = ReminderTestTransport()
    let sync = ReminderSynchronizer(transport: transport, source: { context })
    await transport.failNext()
    let failed = await sync.refresh()
    XCTAssertNotNil(failed.error)
    let retry = await sync.refresh()
    XCTAssertNil(retry.error)
    XCTAssertEqual(retry.count, 1)
    await transport.deny()
    let denied = await sync.refresh()
    XCTAssertEqual(denied.count, 0)
    XCTAssertEqual(denied.authorization, .denied)
    let pending = await transport.pending()
    XCTAssertTrue(pending.isEmpty)
  }
  func testTestNotificationSurvivesReminderSyncAndIsNotCountedOrRouted() async throws {
    let repository = try RepsRepository(path: ":memory:")
    try await repository.saveNotificationPreferences(NotificationPreferences(photosEnabled: true))
    let context = try await repository.reminderContext()
    let transport = ReminderTestTransport()
    try await transport.add(
      ReminderOccurrence(
        id: ReminderPolicy.testIdentifier, kind: .photos, title: "Test", body: "Test",
        components: DateComponents(second: 10), repeats: false, date: nil))
    let sync = ReminderSynchronizer(transport: transport, source: { context })
    let result = await sync.refresh()
    let requests = await transport.pending()
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(requests.count, 2)
    XCTAssertTrue(requests.contains { $0.id == ReminderPolicy.testIdentifier })
    XCTAssertFalse(ReminderPolicy.managed(ReminderPolicy.testIdentifier))
    XCTAssertTrue(ReminderPolicy.presents(ReminderPolicy.testIdentifier))
    XCTAssertFalse(ReminderPolicy.presents("foreign"))
    XCTAssertNil(
      ReminderPolicy.destination(identifier: ReminderPolicy.testIdentifier, kind: "photos"))
  }
  func testRoutesRejectMismatchedPayloadAndPermissionNeverRepromptsDenial() {
    XCTAssertEqual(
      ReminderPolicy.destination(identifier: "sport.local.photos.monthly", kind: "photos"),
      .progression)
    XCTAssertEqual(
      ReminderPolicy.destination(
        identifier: "sport.local.workout.legs.2026-10-13", kind: "workout"), .today)
    XCTAssertNil(
      ReminderPolicy.destination(identifier: "sport.local.photos.monthly", kind: "workout"))
    XCTAssertNil(ReminderPolicy.destination(identifier: "foreign", kind: "photos"))
    XCTAssertFalse(ReminderAuthorization.denied.mayRequest)
    XCTAssertFalse(ReminderAuthorization.allowed.mayRequest)
    XCTAssertTrue(ReminderAuthorization.notDetermined.mayRequest)
  }
}
