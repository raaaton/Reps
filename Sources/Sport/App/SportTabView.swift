import SwiftUI

struct SportTabView: View {
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
        .labelStyle(SportLabelStyle())
      }

      Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
        NavigationStack {
          HistoryView()
        }
        .labelStyle(SportLabelStyle())
      }

      Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
        NavigationStack { ProgressionView() }
          .labelStyle(SportLabelStyle())
      }

      Tab("Settings", systemImage: "gearshape", value: 3) {
        NavigationStack {
          SettingsView()
        }
        .labelStyle(SportLabelStyle())
      }
    }
    .environment(\.locale, Locale(identifier: "en"))
    .onOpenURL { url in
      guard url.scheme == "sport", url.host == "workout" else { return }
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
