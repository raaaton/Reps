import SportCore
import SwiftUI

enum WorkoutInputField: Hashable { case repetitions, weight }

struct ActiveSetForm: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  let exercise: WorkoutExercise
  @State private var repetitions = ""
  @State private var load: AvailableLoad = .bodyweight
  @State private var initialized = false
  @State private var previousSet: WorkoutSet?
  @State private var saving = false
  @State private var error: String?
  @FocusState.Binding var focused: WorkoutInputField?

  var body: some View {
    Group {
      Section {
        if let end = exercise.setEndedAt, let start = exercise.setStartedAt {
          WorkoutTimerDisplay(value: WorkoutLabels.time(end - start), label: "Set duration")
        } else {
          LabeledContent("Repetitions") {
            TextField("Count", text: $repetitions).keyboardType(.numberPad)
              .multilineTextAlignment(.trailing).focused($focused, equals: .repetitions)
              .accessibilityLabel("Repetitions Completed")
          }
        }
        WeightSelectionRow(selection: $load)
        if let previousSet {
          LabeledContent("Last Time", value: WorkoutLabels.performance(previousSet)).font(
            .subheadline
          ).foregroundStyle(.secondary)
        }
        if let target = WorkoutInputDefaults.repetitionTarget(for: exercise),
          exercise.definition.tracking == .repetitions
        {
          LabeledContent("Target for This Set", value: "\(target) repetitions").foregroundStyle(
            .secondary)
        }
        if !store.availableLoads.contains(load) {
          Text("This combination has changed. Choose the load you used.").font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Set \(exercise.sets.count + 1) of \(exercise.definition.setCount)")
      }
      .disabled(saving)
      Section {
        Button {
          save(
            confirmedReps: repetitions.isEmpty
              ? WorkoutInputDefaults.repetitionTarget(for: exercise) : nil)
        } label: {
          WorkoutActionLabel(
            title: saving
              ? "Saving…"
              : exercise.setEndedAt != nil
                ? "Save Set"
                : repetitions.isEmpty
                  ? "Completed \(WorkoutInputDefaults.repetitionTarget(for: exercise) ?? 0) repetitions"
                  : "Finish Set",
            systemImage: "checkmark",
            isWorking: saving)
        }
        .sportProminentButton().controlSize(.large)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .disabled(
          saving || !store.availableLoads.contains(load)
            || (exercise.definition.tracking == .repetitions && repetitions.isEmpty
              && WorkoutInputDefaults.repetitionTarget(for: exercise) == nil)
        )
      } footer: {
        Text(
          exercise.setEndedAt != nil
            ? "Timer stopped. Enter the added weight, then save the set. 0 kg means bodyweight."
            : "0 kg means bodyweight.")
      }
      .disabled(saving)
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
      .alert(
        "Set Not Saved",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }

  private func save(confirmedReps: Int? = nil) {
    guard !saving else { return }
    focused = nil
    saving = true
    Task {
      defer { saving = false }
      do {
        let grams = load.grams
        let reps: Int?
        if exercise.definition.tracking == .repetitions {
          guard let parsed = confirmedReps ?? Int(repetitions), parsed > 0 else {
            throw TrainingError.invalid("Enter at least one repetition.")
          }
          reps = parsed
        } else {
          reps = nil
        }
        try await store.recordSet(
          workout: workout, exercise: exercise, repetitions: reps, weightGrams: grams, load: load)
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct RestControls: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let rest: WorkoutRest
  let nextSet: Int
  let busy: Bool
  let action: (RestAction) -> Void

  var body: some View {
    Group {
      Section {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let remaining = rest.remaining(at: Int(context.date.timeIntervalSince1970 * 1000))
          // Round up so the last fraction of a second does not read 0:00 early.
          let countdown = WorkoutLabels.time(
            remaining / 1000 * 1000 + (remaining % 1000 == 0 ? 0 : 1000))
          WorkoutTimerDisplay(value: countdown, label: "Rest time remaining")
        }
      } header: {
        Text(rest.status == .paused ? "Rest Paused" : "Rest")
      }
      Section {
        VStack(spacing: 12) {
          Button {
            action(rest.status == .paused ? .resume : .pause)
          } label: {
            Label {
              Text(rest.status == .paused ? "Resume Rest" : "Pause")
            } icon: {
              if rest.status == .paused {
                Image(systemName: "play.fill")
              } else {
                Image(systemName: "pause.fill").foregroundStyle(.black)
              }
            }
            .tint(.black)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .frame(maxWidth: .infinity)
          }
          .sportAnimation(value: rest.status)
          .sportProminentButton().controlSize(.large)
          Button {
            action(.skip)
          } label: {
            Label("Skip Rest", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered).controlSize(.large)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
      } footer: {
        Text("Up next: set \(nextSet).")
      }
      .disabled(busy)
    }
  }
}

struct FeelingForm: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  let exercise: WorkoutExercise
  @State private var feeling = 5.0
  @State private var saving = false
  @State private var error: String?

  var body: some View {
    Group {
      Section {
        LabeledContent(
          "Perceived effort", value: "\(WorkoutLabels.feeling(Int((feeling * 10).rounded()))) / 10")
        Slider(value: $feeling, in: 0...10, step: 0.5) {
          Text("Feeling")
        } minimumValueLabel: {
          Text("0")
        } maximumValueLabel: {
          Text("10")
        }
        .accessibilityValue(WorkoutLabels.feeling(Int((feeling * 10).rounded())))
        ProgressionResult(
          assessment: Progression.assess(
            target: exercise.definition, previous: exercise, loads: store.availableLoads,
            feelingTenths: Int((feeling * 10).rounded()))
        )
        .font(.subheadline)
      } header: {
        Text("Feeling")
      }
      .disabled(saving)
      Section {
        Button {
          guard !saving else { return }
          saving = true
          Task {
            defer { saving = false }
            do {
              try await store.saveFeeling(
                workout: workout, exercise: exercise, tenths: Int((feeling * 10).rounded()))
            } catch { self.error = error.localizedDescription }
          }
        } label: {
          WorkoutActionLabel(
            title: saving
              ? "Saving…"
              : workout.exercises.last?.id == exercise.id
                ? "Finish Workout" : "Next Exercise",
            systemImage: "checkmark", isWorking: saving
          )
        }
        .sportProminentButton().controlSize(.large)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
      } footer: {
        Text("0: no effort · 10: maximum effort.")
      }
      .disabled(saving)
      .alert(
        "Feeling Not Saved",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }
}

struct PreviousPerformanceRow: View {
  @EnvironmentObject private var store: TrainingStore
  let exerciseID: String
  let workoutID: String
  @State private var performance: WorkoutExercise?
  @State private var loading = true
  @State private var error: String?

  var body: some View {
    DisclosureGroup("Previous Result") {
      if let performance {
        ForEach(performance.sets) { set in
          LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
        }
        if let feeling = performance.feelingTenths {
          LabeledContent("Feeling", value: "\(WorkoutLabels.feeling(feeling)) / 10")
        }
      } else if let error {
        Text(error).foregroundStyle(.secondary)
      } else if loading {
        ProgressView()
      } else {
        Text("No Previous Result").foregroundStyle(.secondary)
      }
    }
    .task(id: store.historyRevision) {
      loading = true
      error = nil
      performance = nil
      do {
        let result = try await store.previousPerformance(
          exerciseID: exerciseID, excludingWorkoutID: workoutID)
        guard !Task.isCancelled else { return }
        performance = result
      } catch {
        guard !Task.isCancelled else { return }
        self.error = error.localizedDescription
      }
      loading = false
    }
  }
}

struct WorkoutTimerDisplay: View {
  let value: String
  let label: String
  @ScaledMetric(relativeTo: .largeTitle) private var size = 56

  var body: some View {
    Text(value)
      .font(.system(size: size, weight: .semibold, design: .rounded))
      .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
      .frame(maxWidth: .infinity).padding(.vertical, 16)
      .accessibilityLabel(label).accessibilityValue(value)
  }
}
