import SportCore
import SwiftUI

struct GoalDescription: View {
  let goal: ExerciseGoal
  var body: some View {
    Text(summary)
      .accessibilityLabel(
        (goal.repetitions.map { WorkoutLabels.repetitionDescription($0) } ?? target)
          + ", "
          + (goal.load.grams == 0
            ? "Bodyweight" : "\(WorkoutLabels.weight(goal.load.grams)) kilograms added"))
  }
  private var target: String {
    if let reps = goal.repetitions { return RepetitionNotation.compact(reps) }
    return goal.definition.durationSeconds.map { "\(goal.definition.setCount)×\($0) s" }
      ?? "\(goal.definition.setCount) sets · untimed"
  }
  private var summary: String {
    target + " · "
      + (goal.load.grams == 0 ? "Bodyweight" : "+\(WorkoutLabels.weight(goal.load.grams)) kg")
  }
}

struct ExerciseGoalRow: View {
  @EnvironmentObject private var store: TrainingStore
  let exercise: TrainingExercise
  @State private var context: GoalContext?
  @State private var editing = false
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let context {
        Button {
          editing = true
        } label: {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
              if let goal = context.adopted {
                Text("Goal").font(.caption).foregroundStyle(.secondary)
                GoalDescription(goal: goal).font(.subheadline).foregroundStyle(.primary)
                if !context.isAvailable {
                  Text("Review needed: exercise or load changed.").font(.caption).foregroundStyle(
                    .secondary)
                }
              } else {
                Text(TrainingLabels.target(exercise)).font(.subheadline).foregroundStyle(.secondary)
                Text("Choose a Goal").font(.subheadline).foregroundStyle(.tint)
              }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
          }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityHint("Review the goal, suggestion or customize")
      } else if let error {
        Text(error).font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .sportAnimation(value: context?.adopted)
    .task(id: store.historyRevision) {
      do {
        let result = try await store.goalContext(exerciseID: exercise.id)
        guard !Task.isCancelled else { return }
        context = result
        error = nil
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    .sheet(isPresented: $editing) { if let context { GoalEditor(context: context) } }
  }
}

private enum GoalRoute: Hashable { case customize }

struct GoalEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let context: GoalContext
  @State private var saving = false
  @State private var path: [GoalRoute] = []
  @State private var error: String?
  var body: some View {
    NavigationStack(path: $path) {
      List {
        if let goal = context.adopted {
          Section("Current Goal") {
            GoalDescription(goal: goal).font(.headline)
            if !context.isAvailable {
              Text("The exercise or load has changed. Customize the goal before using it.")
                .font(.subheadline).foregroundStyle(.secondary)
            }
          }
        }
        if let suggestion = context.suggestion, suggestion.goal != context.adopted {
          Section(context.adopted == nil ? "Starting Point" : "Suggestion") {
            GoalDescription(goal: suggestion.goal).font(.headline)
            Text(reason(suggestion.reason)).font(.subheadline).foregroundStyle(.secondary)
            Button(
              context.adopted == nil ? "Use This Goal" : "Use Suggestion",
              systemImage: "checkmark"
            ) { adopt(suggestion) }
          }
        }
        Section {
          NavigationLink(value: GoalRoute.customize) {
            Label("Customize", systemImage: "slider.horizontal.3")
          }
          LabeledContent("Program", value: TrainingLabels.target(context.exercise))
            .font(.subheadline).foregroundStyle(.secondary)
        } footer: {
          Text(
            "Changes apply to future workouts. The active workout stays unchanged."
          )
        }
      }
      .navigationDestination(for: GoalRoute.self) { _ in
        GoalCustomizationView(context: context, onSaved: { dismiss() })
      }
      .disabled(saving)
      .navigationTitle(context.exercise.name).navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(saving)
      .toolbar {
        if path.isEmpty {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { dismiss() }.tint(.white).disabled(
              saving)
          }
        }
      }
      .alert(
        "Goal Not Saved",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }
  private func reason(_ reason: GoalReason) -> String {
    switch reason {
    case .initial: "A starting target to adapt to your preferred load."
    case .increaseLoad:
      "Feeling below 8: try the next available load at the minimum repetition target."
    case .decreaseLoad:
      "Feeling above 9: try the next lighter available load with the same targets."
    case .addRepetition: "Keep the same load and add one repetition to a weaker set."
    case .keep: "Keep the target from the last comparable workout."
    case .duration: "Keep the configured duration. Added weight is your choice."
    }
  }
  private func adopt(_ suggestion: GoalSuggestion) {
    guard !saving else { return }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await store.adoptGoal(suggestion, original: context.adopted)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}

private struct GoalCustomizationView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let context: GoalContext
  let onSaved: () -> Void
  @State private var load: AvailableLoad
  @State private var reps: [Int]
  @State private var saving = false
  @State private var error: String?
  init(context: GoalContext, onSaved: @escaping () -> Void) {
    self.context = context
    self.onSaved = onSaved
    _load = State(
      initialValue: context.adopted?.load ?? context.suggestion?.goal.load ?? .bodyweight)
    let count = min(1000, context.exercise.setCount)
    let initial = context.adopted?.repetitions
    _reps = State(
      initialValue: initial?.count == count
        ? initial!.map { max(1, $0) }
        : Array(repeating: context.exercise.minimumReps ?? 1, count: count))
  }
  var body: some View {
    Form {
      Section {
        WeightSelectionRow(selection: $load)
        if context.exercise.tracking == .repetitions {
          ForEach(reps.indices, id: \.self) { index in
            Stepper(
              "Set \(index + 1): \(reps[index]) repetitions", value: $reps[index],
              in:
                1...max(context.exercise.maximumReps ?? 1, context.adopted?.repetitions?.max() ?? 1)
            )
          }
        } else {
          LabeledContent(
            "Duration per Set",
            value: context.exercise.durationSeconds.map { "\($0) s" } ?? "Untimed")
        }
      } header: {
        Text("Customize Goal")
      } footer: {
        Text(
          "Change duration in Settings → Exercises."
        )
      }
      if !store.availableLoads.contains(load) {
        Section {
          Text(
            "This combination is unavailable. Choose a load before saving."
          ).foregroundStyle(.secondary)
        }
      }
    }
    .disabled(saving)
    .navigationTitle("Customize").navigationBarTitleDisplayMode(.inline)
    .interactiveDismissDisabled(saving)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        SportConfirmationButton(title: "Save") {
          save()
        }.labelStyle(.iconOnly).disabled(
          saving || !store.availableLoads.contains(load) || context.exercise.setCount > 1000)
      }
    }
    .alert(
      "Goal Not Saved",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func save() {
    guard !saving else { return }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await store.saveGoal(
          ExerciseGoal(
            definition: context.exercise, load: load,
            repetitions: context.exercise.tracking == .repetitions ? reps : nil),
          original: context.adopted)
        onSaved()
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct WorkoutGoalLabel: View {
  let exercise: WorkoutExercise
  var body: some View {
    if let goal = exercise.goal { GoalDescription(goal: goal).font(.subheadline) }
  }
}
