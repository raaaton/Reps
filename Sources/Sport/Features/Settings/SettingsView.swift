import SwiftUI

struct SettingsView: View {
  @AppStorage(SportHaptics.preferenceKey) private var hapticsEnabled = true
  var body: some View {
    List {
      Section("Training") {
        NavigationLink {
          PlanningView()
        } label: {
          Label("Workouts", systemImage: "calendar")
        }

        NavigationLink {
          ExercisesView()
        } label: {
          Label("Exercises", systemImage: "figure.strengthtraining.traditional")
        }

        NavigationLink {
          WeightInventoryView()
        } label: {
          Label("Added Weight", systemImage: "backpack")
        }

        NavigationLink {
          RestSettingsView()
        } label: {
          Label("Rest", systemImage: "timer")
        }
      }

      Section("Reminders and Privacy") {
        NavigationLink {
          NotificationsSettingsView()
        } label: {
          Label("Notifications", systemImage: "bell")
        }

        NavigationLink {
          VaultSettingsView()
        } label: {
          Label("Photo Vault", systemImage: "lock")
        }
      }

      Section {
        Toggle("Haptic Feedback", systemImage: "hand.tap", isOn: $hapticsEnabled)
      } header: {
        Text("Interaction")
      } footer: {
        Text(
          "Feedback during sets, rest and data selection. System controls keep their iOS settings."
        )
      }

      Section("Data") {
        NavigationLink {
          TrainingTransferView()
        } label: {
          Label("Import and Export", systemImage: "externaldrive")
        }
      }

      Section {
        NavigationLink {
          AboutView()
        } label: {
          Label("About", systemImage: "info.circle")
        }
      }
    }
    .navigationTitle("Settings")
    .scrollBounceBehavior(.basedOnSize)
  }
}
