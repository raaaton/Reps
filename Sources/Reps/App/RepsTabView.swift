import SwiftUI

struct RepsTabView: View {
  @EnvironmentObject private var store: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @ObservedObject private var reminders = LocalReminderCoordinator.shared
  @State private var selection = 0
  var body: some View {
    TabView(selection: $selection) {
      Tab("Today", systemImage: "figure.strengthtraining.traditional", value: 0) {
        NavigationStack {
          TodayView()
        }
        .labelStyle(RepsLabelStyle())
      }

      Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
        NavigationStack {
          HistoryView()
        }
        .labelStyle(RepsLabelStyle())
      }

      Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
        NavigationStack { ProgressionView() }
          .labelStyle(RepsLabelStyle())
      }

      Tab("Settings", systemImage: "gearshape", value: 3) {
        NavigationStack {
          SettingsView()
        }
        .labelStyle(RepsLabelStyle())
      }
    }
    .environment(\.locale, Locale(identifier: "en"))
    .onOpenURL { url in
      guard ["reps", "sport"].contains(url.scheme ?? ""), url.host == "workout" else { return }
      selection = 0
      store.requestWorkoutLink(url)
    }
    .task { consumeReminder() }
    .onChange(of: selection) { _, _ in vault.leaveVault() }
    .onChange(of: reminders.destination) { _, _ in consumeReminder() }
  }

  private func consumeReminder() {
    guard let destination = reminders.destination else { return }
    selection = destination.tabIndex
    if destination == .bodyWeight { store.requestBodyWeightEntry() }
    reminders.consumeDestination()
  }
}
