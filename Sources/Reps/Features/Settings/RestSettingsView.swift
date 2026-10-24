import RepsCore
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
  @State private var minutes: Int
  @State private var seconds: Int
  private let initialMinutes: Int
  private let initialSeconds: Int
  @State private var saving = false
  @State private var error: String?

  init(seconds: Int) {
    initialMinutes = seconds / 60
    initialSeconds = seconds % 60
    _minutes = State(initialValue: seconds / 60)
    _seconds = State(initialValue: seconds % 60)
  }

  var body: some View {
    Form {
      Section {
        HStack(spacing: 0) {
          Picker("Minutes", selection: $minutes) {
            ForEach(0...59, id: \.self) { value in
              Text("\(value) min").tag(value)
            }
            if initialMinutes > 59 {
              Text("\(initialMinutes) min").tag(initialMinutes)
            }
          }
          .frame(maxWidth: .infinity)
          .clipped()
          .accessibilityLabel("Rest minutes")
          Picker("Seconds", selection: $seconds) {
            ForEach(Array(Set([0, 30, initialSeconds])).sorted(), id: \.self) { value in
              Text("\(value) sec").tag(value)
            }
          }
          .frame(maxWidth: .infinity)
          .clipped()
          .accessibilityLabel("Rest seconds")
        }
        .pickerStyle(.wheel)
        .labelsHidden()
      } footer: {
        Text("Changes apply to future workouts.")
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
        RepsConfirmationButton(title: "Save") {
          save()
        }.labelStyle(.iconOnly).disabled(saving || (minutes == 0 && seconds == 0))
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
    guard minutes >= 0, (0...59).contains(seconds), minutes <= (Int.max - seconds) / 60,
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
