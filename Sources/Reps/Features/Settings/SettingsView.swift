import SwiftUI

struct SettingsView: View {
  @AppStorage(RepsHaptics.preferenceKey) private var hapticsEnabled = true
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

        TrainingContent { snapshot in
          StretchingSettingRow(enabled: snapshot.stretchingEnabled)
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
          Label("Private Vault", systemImage: "lock")
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

private struct StretchingSettingRow: View {
  @EnvironmentObject private var store: TrainingStore
  let enabled: Bool
  @State private var saving = false
  @State private var error: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Toggle(
        "Stretching", systemImage: "figure.flexibility",
        isOn: Binding(
          get: { enabled },
          set: { value in
            guard !saving else { return }
            saving = true
            Task {
              defer { saving = false }
              do { try await store.saveStretching(enabled: value) } catch {
                self.error = error.localizedDescription
              }
            }
          })
      )
      .disabled(saving)
    }
    .alert(
      "Unable to Save",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }
}
