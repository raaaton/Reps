import SportCore
import SwiftUI

struct WorkoutSupportPreview: View {
  let first: TrainingExercise
  let goal: ExerciseGoal?
  let override: AvailableLoad?
  let restSeconds: Int
  @Binding var stretch: StretchMovement?
  @Binding var stretchSeconds: Int
  private var plan: WorkoutSupport? {
    var exercise = WorkoutExercise(
      id: first.id, definition: first, sets: [], feelingTenths: nil,
      setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil, goal: goal)
    if let override {
      exercise.goal = ExerciseGoal(
        definition: first, load: override,
        repetitions: goal?.repetitions
          ?? (first.tracking == .repetitions
            ? Array(repeating: first.minimumReps ?? 1, count: first.setCount) : nil))
    }
    return try? WorkoutSupport.make(
      first: exercise, restSeconds: restSeconds,
      stretch: stretch ?? .suggested(firstID: first.id), stretchSeconds: stretchSeconds)
  }
  var body: some View {
    Section("Warm-up") {
      if let step = plan?.steps.first {
        LabeledContent(first.name, value: "\(step.count) × \(supportTarget(step))")
        Text("Bodyweight only · \(TrainingLabels.rest(restSeconds)) rest before working sets")
          .font(.subheadline).foregroundStyle(.secondary)
        if step.count == 2 {
          Text("Half rest between the two warm-up sets.").font(.subheadline).foregroundStyle(
            .secondary)
        }
      }
    }
    Section {
      Picker("Movement", selection: $stretch) {
        Text("Automatic").tag(StretchMovement?.none)
        ForEach(StretchMovement.allCases, id: \.self) { Text($0.name).tag(Optional($0)) }
      }
      let movement = stretch ?? .suggested(firstID: first.id)
      Text(movement.name).foregroundStyle(.secondary)
      Stepper(
        "\(stretchSeconds) s\(movement.sides == 2 ? " per side" : "")", value: $stretchSeconds,
        in: 5...600, step: 5)
    } header: {
      Text("Stretch After Workout")
    } footer: {
      Text("Warm-up and stretch results stay separate from your exercise progression.")
    }
  }
}

private func supportTarget(_ step: WorkoutSupportStep) -> String {
  if let reps = step.targetRepetitions { return "\(reps) reps" }
  if let ms = step.targetDurationMS {
    return "\((Double(ms) / 1000).formatted(.number.precision(.fractionLength(0...1)))) s"
  }
  return "Free duration"
}

struct WorkoutSupportFlowView: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  @State private var busy = false
  @State private var repetitions = ""
  @State private var error: String?
  @FocusState private var editing: Bool
  var body: some View {
    List {
      if workout.phase == .resting, let rest = workout.rest {
        Section {
          Text(workout.currentSupport?.kind == .warmUp ? "Warm-up" : "Warm-up Complete")
            .font(.title2).fontWeight(.semibold)
          Text(
            workout.currentSupport?.kind == .warmUp
              ? "Half rest before the next warm-up set."
              : "Full rest before your first working set."
          )
          .foregroundStyle(.secondary)
        }.listRowBackground(Color.clear)
        RestControls(rest: rest, nextSet: workout.currentSupport?.number ?? 1, busy: busy) {
          action in
          perform { try await store.changeRest(id: rest.id, action: action) }
        }
      } else if let step = workout.currentSupport {
        Section {
          Text(
            step.kind == .warmUp
              ? "Warm-up · \(step.number) of \(step.count)"
              : "Stretch\(step.count == 2 ? " · Side \(step.number) of 2" : "")"
          )
          .font(.subheadline).foregroundStyle(.secondary)
          Text(step.name).font(.title2).fontWeight(.semibold).accessibilityAddTraits(.isHeader)
          Text(supportTarget(step)).font(.headline)
          if step.kind == .warmUp { Text("Bodyweight only").foregroundStyle(.secondary) }
          Text(step.instructions).font(.subheadline).foregroundStyle(.secondary)
        }.listRowBackground(Color.clear)
        if step.startedAt == nil {
          Section {
            Button {
              perform { try await store.beginSupport(workout: workout, step: step) }
            } label: {
              WorkoutActionLabel(
                title: step.kind == .warmUp ? "Start Warm-up Set" : "Start Stretch",
                systemImage: "play.fill", isWorking: busy)
            }.sportProminentButton().controlSize(.large).disabled(busy)
          }.listRowBackground(Color.clear)
        } else if step.tracking == .duration {
          WorkoutTimedSetView(
            workout: workout, exercise: displayExercise(step), busy: busy,
            cancel: {
              perform { try await store.cancelSupportCountdown(workout: workout, step: step) }
            },
            finish: {
              perform {
                try await store.finishSupport(workout: workout, step: step, repetitions: nil)
              }
            }, automaticDeadline: step.automaticDeadline, showsWeight: false,
            finishTitle: step.kind == .warmUp ? "Finish Warm-up Set" : "Finish Stretch",
            headerTitle: step.kind == .warmUp
              ? "Warm-up Set \(step.number) of \(step.count)"
              : "Hold \(step.number) of \(step.count)")
        } else {
          Section {
            LabeledContent("Repetitions") {
              TextField("Reps", text: $repetitions).keyboardType(.numberPad).multilineTextAlignment(
                .trailing
              )
              .focused($editing).accessibilityLabel("Warm-up repetitions")
            }
          }
          Section {
            Button {
              editing = false
              perform {
                try await store.finishSupport(
                  workout: workout, step: step, repetitions: Int(repetitions))
              }
            } label: {
              WorkoutActionLabel(
                title: "Finish Warm-up Set", systemImage: "checkmark", isWorking: busy)
            }
            .sportProminentButton().controlSize(.large).disabled(
              busy || (Int(repetitions) ?? 0) <= 0)
          }.listRowBackground(Color.clear)
        }
      }
      if let error { Section { Text(error).foregroundStyle(.secondary) } }
      if let message = store.liveActivityMessage {
        Section {
          Text(message).foregroundStyle(.secondary)
          Button("Retry Live Activity") { Task { await store.refreshLiveActivity(retry: true) } }
        }
      }
    }
    .listSectionSpacing(.compact)
    .scrollDismissesKeyboard(.interactively)
    .onAppear { repetitions = workout.currentSupport?.targetRepetitions.map(String.init) ?? "" }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") { editing = false }
          .labelStyle(.iconOnly).tint(.white)
      }
    }
  }
  // Presentation adapter only: reuse the exact native timer/countdown and its feedback.
  // These are not working sets and are never inserted into the exercise catalogue or analytics.
  private func displayExercise(_ step: WorkoutSupportStep) -> WorkoutExercise {
    let prior =
      workout.support?.steps.filter {
        $0.kind == step.kind && $0.number < step.number && $0.completedAt != nil
      } ?? []
    let sets = prior.map {
      WorkoutSet(
        id: $0.id, number: $0.number, repetitions: nil,
        durationMS: $0.durationMS, weightGrams: 0, completedAt: $0.completedAt ?? workout.startedAt)
    }
    let definition = TrainingExercise(
      id: step.id, name: step.name, tracking: .duration,
      setCount: step.count, minimumReps: nil, maximumReps: nil, durationSeconds: nil,
      isEnabled: true)
    return WorkoutExercise(
      id: step.id, definition: definition, sets: sets, feelingTenths: nil,
      setStartedAt: step.startedAt, setWeightGrams: 0, setEndedAt: nil)
  }
  private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do { try await operation() } catch { self.error = error.localizedDescription }
    }
  }
}
