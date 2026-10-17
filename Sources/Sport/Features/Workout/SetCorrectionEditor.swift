import SportCore
import SwiftUI

struct SetCorrectionEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let workoutID: String
  let exerciseID: String
  let original: WorkoutSet
  @State private var performance: String
  @State private var weight: String
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool
  init(workoutID: String, exerciseID: String, set: WorkoutSet) {
    self.workoutID = workoutID
    self.exerciseID = exerciseID
    original = set
    _performance = State(
      initialValue: set.repetitions.map(String.init) ?? WorkoutLabels.weight(set.durationMS ?? 0))
    _weight = State(initialValue: WorkoutLabels.weight(set.weightGrams))
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent(original.repetitions == nil ? "Duration (s)" : "Repetitions") {
            TextField("Value", text: $performance).keyboardType(
              original.repetitions == nil ? .decimalPad : .numberPad
            ).multilineTextAlignment(.trailing).focused($focused)
          }
          LabeledContent("Added Weight (kg)") {
            TextField("Load", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(
              .trailing
            ).focused($focused)
          }
        } footer: {
          Text(
            "Rest, other sets and timestamps stay unchanged. Changing the load removes its original composition."
          )
        }
      }
      .disabled(saving).interactiveDismissDisabled(saving)
      .navigationTitle("Edit Set \(original.number)").navigationBarTitleDisplayMode(
        .inline
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly
          ).disabled(
            saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            save()
          } label: {
            SportConfirmationLabel(title: "Save")
          }.labelStyle(.iconOnly).disabled(saving)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
            focused = false
          }.tint(.white).labelStyle(.iconOnly)
        }
      }
      .alert(
        "Set Not Updated",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }
  private func save() {
    guard !saving else { return }
    saving = true
    focused = false
    Task {
      defer { saving = false }
      do {
        let reps = original.repetitions == nil ? nil : Int(performance)
        let duration = original.repetitions == nil ? try WorkoutWeight.grams(performance) : nil
        let grams = try WorkoutWeight.grams(weight)
        try await store.correctSet(
          workoutID: workoutID, exerciseID: exerciseID, original: original, repetitions: reps,
          durationMS: duration, weightGrams: grams)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
