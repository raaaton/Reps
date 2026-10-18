import SportCore
import SwiftUI
import UIKit

struct NotificationsSettingsView: View {
  @EnvironmentObject private var store: TrainingStore
  @ObservedObject private var reminders = LocalReminderCoordinator.shared
  @State private var saving = false
  @State private var error: String?
  @State private var testScheduled = false
  var body: some View {
    TrainingContent { snapshot in
      Form {
        Section {
          Button("iOS Notification Settings", systemImage: "arrow.up.forward.app") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
        } footer: {
          Text(
            reminders.authorization == .denied
              ? "Allow notifications in iOS, then choose Lock Screen under Alerts. iOS controls how long they stay visible."
              : "Choose Lock Screen under Alerts in iOS. iOS controls how long notifications stay visible."
          )
        }
        Section {
          Toggle("Workout Reminders", isOn: preferenceBinding(photos: false))
          NavigationLink("Choose Times in Workouts") { PlanningView() }
          let scheduled = snapshot.schedules.filter {
            $0.isEnabled && $0.reminderMinutes != nil && !snapshot.exercises(for: $0).isEmpty
          }
          ForEach(scheduled) { schedule in
            LabeledContent(
              schedule.name,
              value:
                "\(TrainingLabels.weekday(schedule.weekday)) · \(TrainingLabels.time(schedule.reminderMinutes!).formatted(date: .omitted, time: .shortened))"
            )
          }
          if scheduled.isEmpty {
            Text("No enabled workout with a reminder time.").foregroundStyle(.secondary)
          }
        } footer: {
          Text(
            "Each workout uses its reminder time in Workouts. The next 28 days are scheduled; open Sport to refresh them. Starting a workout removes its reminder for that day."
          )
        }
        Section {
          Toggle("Monthly Reminder", isOn: preferenceBinding(photos: true))
          DatePicker(
            "Time",
            selection: Binding(
              get: { TrainingLabels.time(store.notificationPreferences.photoMinutes) },
              set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                update(photoMinutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
              }), displayedComponents: .hourAndMinute)
        } header: {
          Text("Progress Photos")
        } footer: {
          Text(
            "On the first of each month, at the chosen time. The reminder includes no photos and opens Progress; your vault stays locked."
          )
        }
        Section {
          Button("Send Test Notification", systemImage: "bell.badge") {
            saving = true
            testScheduled = false
            Task {
              defer { saving = false }
              do {
                try await reminders.sendTestNotification()
                testScheduled = true
              } catch { self.error = error.localizedDescription }
            }
          }
          if testScheduled {
            Text("Test scheduled. Lock your iPhone now.")
              .foregroundStyle(.secondary)
          }
        } footer: {
          Text("Sends one notification after 10 seconds, using your iOS notification settings.")
        }
        Section {
          LabeledContent("Scheduled Reminders", value: String(reminders.count))
          if let message = reminders.error { Text(message).foregroundStyle(.secondary) }
          Button("Sync Again", systemImage: "arrow.clockwise") {
            saving = true
            Task {
              await reminders.refresh()
              saving = false
            }
          }
        }
      }
      .disabled(saving)
    }
    .navigationTitle("Notifications")
    .task { await reminders.refresh() }
    .alert(
      "Notification Error",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func preferenceBinding(photos: Bool) -> Binding<Bool> {
    Binding(
      get: {
        photos
          ? store.notificationPreferences.photosEnabled
          : store.notificationPreferences.workoutsEnabled
      }, set: { value in update(photos: photos, enabled: value) })
  }
  private func update(photos: Bool? = nil, enabled: Bool? = nil, photoMinutes: Int? = nil) {
    guard !saving else { return }
    saving = true
    Task {
      defer { saving = false }
      do {
        if enabled == true { try await reminders.requestPermissionIfNeeded() }
        var preferences = store.notificationPreferences
        if let photos, let enabled {
          if photos {
            preferences.photosEnabled = enabled
          } else {
            preferences.workoutsEnabled = enabled
          }
        }
        if let photoMinutes { preferences.photoMinutes = photoMinutes }
        try await store.saveNotificationPreferences(preferences)
      } catch { self.error = error.localizedDescription }
    }
  }
}
