import RepsCore
import SwiftUI

struct BodyWeightReminderSettingsView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State private var weekday: Int?
  @State private var minutes: Int?
  @State private var choosingTime = false
  @State private var time = Date()
  @State private var saving = false
  @State private var error: String?
  @State private var loaded = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Day", selection: $weekday) {
            Text("Choose a Day").tag(Optional<Int>.none)
            ForEach(1...7, id: \.self) { day in
              Text(TrainingLabels.weekday(day)).tag(Optional(day))
            }
          }
          Button {
            choosingTime = true
          } label: {
            LabeledContent("Time") {
              Text(
                minutes.map { TrainingLabels.time($0).formatted(date: .omitted, time: .shortened) }
                  ?? "Choose a Time")
            }
          }
          .foregroundStyle(.primary)
        } footer: {
          Text("Save to enable a weekly reminder. Notifications include no weight measurements.")
        }
      }
      .navigationTitle("Body Weight Reminder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(weekday == nil || minutes == nil || saving)
        }
      }
      .disabled(saving)
      .interactiveDismissDisabled(saving)
      .onAppear {
        guard !loaded else { return }
        loaded = true
        weekday = store.notificationPreferences.weightWeekday
        minutes = store.notificationPreferences.weightMinutes
        if let minutes { time = TrainingLabels.time(minutes) }
      }
      .sheet(isPresented: $choosingTime) {
        NavigationStack {
          Form {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
              .datePickerStyle(.wheel)
              .labelsHidden()
              .accessibilityLabel("Reminder Time")
          }
          .navigationTitle("Reminder Time")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel", role: .cancel) { choosingTime = false }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                choosingTime = false
              }
            }
          }
        }
      }
      .alert(
        "Notification Error",
        isPresented: Binding(
          get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }

  private func save() {
    guard !saving, let weekday, let minutes else { return }
    saving = true
    Task {
      defer { saving = false }
      do {
        let reminders = LocalReminderCoordinator.shared
        try await reminders.requestPermissionIfNeeded()
        guard reminders.authorization == .allowed else {
          throw TrainingError.invalid(
            "Allow notifications in iOS Notification Settings, then save your reminder again.")
        }
        var preferences = store.notificationPreferences
        preferences.weightEnabled = true
        preferences.weightWeekday = weekday
        preferences.weightMinutes = minutes
        try await store.saveNotificationPreferences(preferences)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
