import RepsCore
import SwiftUI

struct MaximumWeightObjectsEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State private var value: String
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool

  init(maximum: Int) { _value = State(initialValue: String(maximum)) }

  private var maximum: Int? {
    guard let number = Int(value), (1...1000).contains(number) else { return nil }
    return number
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("Maximum Objects") {
            HStack {
              TextField("10", text: $value).keyboardType(.numberPad)
                .multilineTextAlignment(.trailing).focused($focused)
                .accessibilityLabel("Maximum weight objects")
              Stepper(
                "Maximum weight objects",
                value: Binding(
                  get: { min(1000, max(1, Int(value) ?? 10)) }, set: { value = String($0) }
                ), in: 1...1000
              ).labelsHidden()
            }
          }
        } footer: {
          Text("Choose 1 to 1,000 objects, excluding the backpack. Recorded compositions are kept.")
        }
      }
      .disabled(saving)
      .navigationTitle("Maximum Objects").navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(saving)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(.iconOnly)
            .disabled(saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(saving ? "Saving…" : "Save") { save() }.disabled(saving || maximum == nil)
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
    guard !saving, let maximum else { return }
    saving = true
    focused = false
    Task {
      defer { saving = false }
      do {
        try await store.saveMaximumWeightObjects(maximum)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
