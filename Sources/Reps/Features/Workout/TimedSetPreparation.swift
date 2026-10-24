import RepsCore
import SwiftUI

struct TimedSetPreparation: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  let exercise: WorkoutExercise
  let busy: Bool
  @State private var load: AvailableLoad = .bodyweight
  @State private var initialized = false
  @State private var previousSet: WorkoutSet?
  @State private var starting = false
  @State private var error: String?
  @FocusState.Binding var focused: WorkoutInputField?

  var body: some View {
    Group {
      Section {
        WeightSelectionRow(selection: $load)
        if let previousSet {
          LabeledContent("Last Time", value: WorkoutLabels.performance(previousSet)).font(
            .subheadline
          ).foregroundStyle(.secondary)
        }
        if let target = exercise.goal?.durationTargetMS(forSet: exercise.sets.count + 1) {
          LabeledContent("Target for This Set", value: "\(WorkoutLabels.seconds(target)) s")
            .foregroundStyle(.secondary)
        }
        if !store.isLoadAvailable(load) {
          Text("This combination has changed. Choose your added weight.").foregroundStyle(
            .secondary)
        }
      } header: {
        Text("Set \(exercise.sets.count + 1) of \(exercise.definition.setCount)")
      } footer: {
        Text("Choose added weight before starting. 0 kg means bodyweight.")
      }
      Section {
        Button {
          guard !starting, !busy else { return }
          focused = nil
          starting = true
          Task {
            defer { starting = false }
            do {
              let grams = load.grams
              try await store.beginSet(
                workout: workout, exercise: exercise, weightGrams: grams, load: load)
            } catch { self.error = error.localizedDescription }
          }
        } label: {
          WorkoutActionLabel(
            title: starting ? "Starting…" : "Start Set", systemImage: "play.fill",
            isWorking: starting)
        }
        .repsProminentButton().controlSize(.large)
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
        .disabled(!store.isLoadAvailable(load))
      } footer: {
        Text("A 3-second countdown comes before timing starts.")
      }
    }
    .task {
      if !initialized {
        load = WorkoutInputDefaults.load(for: exercise, available: store.availableLoads)
        initialized = true
      }
      do {
        let previous = try await store.previousPerformance(
          exerciseID: exercise.definition.id, excludingWorkoutID: workout.id)
        guard !Task.isCancelled else { return }
        previousSet = previous?.sets.first { $0.number == exercise.sets.count + 1 }
      } catch { self.error = error.localizedDescription }
    }
    .disabled(starting || busy)
    .alert(
      "Set Not Started",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
}
