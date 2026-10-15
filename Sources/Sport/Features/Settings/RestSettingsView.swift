import SportCore
import SwiftUI

struct RestSettingsView: View {
  @State private var editing = false

  var body: some View {
    TrainingContent { snapshot in
      List {
        Section {
          Button {
            editing = true
          } label: {
            LabeledContent("Duration", value: TrainingLabels.rest(snapshot.restSeconds))
          }
          .foregroundStyle(.primary)
        } footer: {
          Text(
            "Used between sets. Changes apply to future workouts."
          )
        }
      }
      .sheet(isPresented: $editing) {
        NavigationStack { RestEditor(seconds: snapshot.restSeconds) }
      }
    }
    .navigationTitle("Rest")
  }
}

struct RestEditor: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TrainingStore
  @State private var minutes: String
  @State private var seconds: String
  @State private var saving = false
  @State private var error: String?

  init(seconds: Int) {
    _minutes = State(initialValue: String(seconds / 60))
    _seconds = State(initialValue: String(seconds % 60))
  }

  var body: some View {
    Form {
      Section {
        LabeledContent("Minutes") {
          TextField("3", text: $minutes).keyboardType(.numberPad).multilineTextAlignment(.trailing)
            .accessibilityLabel("Rest minutes")
        }
        LabeledContent("Seconds") {
          TextField("0", text: $seconds).keyboardType(.numberPad).multilineTextAlignment(.trailing)
            .accessibilityLabel("Rest seconds")
        }
      } footer: {
        Text(
          "Choose a duration above zero. Seconds must be between 0 and 59."
        )
      }
    }
    .disabled(saving)
    .navigationTitle("Rest Duration")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
          .iconOnly
        ).disabled(saving)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", systemImage: "checkmark") { save() }.labelStyle(.iconOnly).disabled(saving)
      }
    }
    .interactiveDismissDisabled(saving)
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

  private func save() {
    guard let minutes = Int(minutes), let seconds = Int(seconds), minutes >= 0,
      (0...59).contains(seconds), minutes <= (Int.max - seconds) / 60,
      minutes * 60 + seconds > 0
    else {
      error = "Enter a valid duration above zero."
      return
    }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await store.saveRest(seconds: minutes * 60 + seconds)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
