import RepsCore
import SwiftUI

struct BackpackWeightEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State private var value: String
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool

  init(grams: Int) { _value = State(initialValue: WorkoutLabels.weight(grams)) }

  private var grams: Int? {
    guard let grams = try? WorkoutWeight.grams(value), grams > 0 else { return nil }
    return grams
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("Weight (kg)") {
            TextField("3", text: $value).keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing).focused($focused)
              .accessibilityLabel("Backpack weight in kilograms")
          }
        }
      }
      .disabled(saving)
      .navigationTitle("Backpack").navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(saving)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(.iconOnly)
            .disabled(saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(saving ? "Saving…" : "Save", systemImage: "checkmark") { save() }
            .tint(.white).labelStyle(.iconOnly).disabled(saving || grams == nil)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
            focused = false
          }.tint(.white).labelStyle(.iconOnly)
        }
      }
      .alert(
        "Unable to Update",
        isPresented: Binding(
          get: { error != nil }, set: { if !$0 { error = nil } }
        )
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }

  private func save() {
    guard !saving, let grams else { return }
    saving = true
    focused = false
    Task {
      defer { saving = false }
      do {
        try await store.saveBackpackWeight(grams: grams)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
