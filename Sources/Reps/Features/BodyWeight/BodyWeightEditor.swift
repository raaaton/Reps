import RepsCore
import SwiftUI

struct BodyWeightDraft: Identifiable {
  let id = UUID()
  let measurement: BodyWeightMeasurement?
}

struct BodyWeightEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let initial: BodyWeightMeasurement?
  @State private var original: BodyWeightMeasurement?
  @State private var date: Date
  @State private var weight: String
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool

  init(measurement: BodyWeightMeasurement?) {
    initial = measurement
    _original = State(initialValue: measurement)
    _date = State(
      initialValue: measurement.flatMap { TrainingAnalytics.date(for: $0.dayKey) } ?? .now)
    _weight = State(initialValue: measurement.map { BodyWeightPresentation.input($0.grams) } ?? "")
  }
  private var dayKey: String { WorkoutClock.dayKey(Int(date.timeIntervalSince1970 * 1000)) }
  private var validation: String? {
    guard !weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    do {
      _ = try BodyWeightInput.grams(from: weight)
      return nil
    } catch {
      return error.localizedDescription
    }
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
          LabeledContent("Weight (kg)") {
            TextField("Required", text: $weight)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused)
              .accessibilityLabel("Body weight in kilograms")
          }
          if let validation { Text(validation).foregroundStyle(.secondary) }
        } footer: {
          if let original, original.dayKey != dayKey {
            Text(
              "This moves the measurement from \(WorkoutLabels.day(original.dayKey)) to the selected date."
            )
          } else if original != nil, initial?.id != original?.id {
            Text("A measurement already exists on this date. You’re editing that measurement.")
          }
        }
      }
      .disabled(saving).interactiveDismissDisabled(saving)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(original == nil ? "Add Body Weight" : "Edit Body Weight")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }
            .tint(.white).labelStyle(.iconOnly).disabled(saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          if saving {
            ProgressView().accessibilityLabel("Saving body weight")
          } else {
            RepsConfirmationButton(title: "Save") { save() }
              .labelStyle(.iconOnly)
              .disabled(
                weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validation != nil)
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
            focused = false
          }.tint(.white).labelStyle(.iconOnly)
        }
      }
      .onChange(of: date) { _, _ in loadExistingDate() }
      .task { loadExistingDate() }
      .alert(
        "Body Weight Not Saved",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }
  private func loadExistingDate() {
    let target = BodyWeightEditingTarget.resolve(
      adding: initial == nil, current: original,
      matching: store.bodyWeights.first(where: { $0.dayKey == dayKey }))
    original = target.original
    if target.resetsInput {
      weight = target.original.map { BodyWeightPresentation.input($0.grams) } ?? ""
    }
  }
  private func save() {
    guard !saving else { return }
    saving = true
    focused = false
    Task {
      defer { saving = false }
      do {
        let measurement = BodyWeightMeasurement(
          id: original?.id ?? UUID().uuidString, dayKey: dayKey,
          grams: try BodyWeightInput.grams(from: weight))
        try await store.saveBodyWeight(measurement, original: original)
        RepsHaptics.shared.play(.success)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
