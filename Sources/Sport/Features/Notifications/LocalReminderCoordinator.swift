import Foundation
import SportCore
import SportLiveSupport
import SwiftUI
import UIKit
import UserNotifications

struct NativeReminderTransport: ReminderTransport {
  func authorization() async -> ReminderAuthorization {
    switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized, .provisional, .ephemeral: .allowed
    @unknown default: .denied
    }
  }
  func pending() async -> [PendingReminder] {
    await UNUserNotificationCenter.current().pendingNotificationRequests().map { request in
      guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
        let kindText = request.content.userInfo["kind"] as? String,
        let kind = ReminderKind(rawValue: kindText)
      else { return PendingReminder(id: request.identifier, occurrence: nil) }
      var components = trigger.dateComponents
      components.calendar = nil
      components.timeZone = nil
      return PendingReminder(
        id: request.identifier,
        occurrence: ReminderOccurrence(
          id: request.identifier, kind: kind, title: request.content.title,
          body: request.content.body, components: components, repeats: trigger.repeats,
          date: trigger.nextTriggerDate()))
    }
  }
  func remove(ids: [String]) async {
    if !ids.isEmpty {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
  }
  func add(_ request: ReminderOccurrence) async throws {
    let content = UNMutableNotificationContent()
    content.title = request.title
    content.body = request.body
    content.sound = .default
    content.userInfo = ["kind": request.kind.rawValue]
    var components = request.components
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    components.calendar = calendar
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: request.repeats)
    try await UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
  }
}

@MainActor
final class LocalReminderCoordinator: ObservableObject {
  static let shared = LocalReminderCoordinator()
  @Published private(set) var authorization: ReminderAuthorization = .notDetermined
  @Published private(set) var count = 0
  @Published private(set) var error: String?
  @Published private(set) var destination: ReminderDestination?
  private let transport = NativeReminderTransport()
  private lazy var synchronizer = ReminderSynchronizer(transport: transport) {
    let repository = try await SportRuntime.shared.repository()
    return try await repository.reminderContext()
  }
  func install() { UNUserNotificationCenter.current().delegate = SportReminderDelegate.shared }
  func refresh() async {
    let result = await synchronizer.refresh()
    authorization = result.authorization
    count = result.count
    error = result.error
  }
  func requestPermissionIfNeeded() async throws {
    authorization = await transport.authorization()
    if authorization.mayRequest {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound,
      ])
      authorization = await transport.authorization()
    }
  }
  func sendTestNotification() async throws {
    try await requestPermissionIfNeeded()
    guard authorization == .allowed else {
      throw TrainingError.invalid(
        "Allow notifications in iOS Notification Settings, then try again.")
    }
    let content = UNMutableNotificationContent()
    content.title = "Test Notification"
    content.body = "Your notification test has arrived."
    content.sound = .default
    try await UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: ReminderPolicy.testIdentifier, content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
  }
  func route(_ destination: ReminderDestination) { self.destination = destination }
  func consumeDestination() { destination = nil }
}

@MainActor
private final class SportReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = SportReminderDelegate()
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    ReminderPolicy.presents(notification.request.identifier) ? [.banner, .list] : []
  }
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
      let kind = response.notification.request.content.userInfo["kind"] as? String,
      let destination = ReminderPolicy.destination(
        identifier: response.notification.request.identifier, kind: kind)
    else { return }
    await LocalReminderCoordinator.shared.route(destination)
  }
}

@MainActor
final class SportAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    LocalReminderCoordinator.shared.install()
    return true
  }
}
