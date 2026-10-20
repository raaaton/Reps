import SportCore
import SwiftUI

struct WorkoutRoute: Identifiable {
  let id = UUID()
  let scheduleID: String?
  let workoutID: String?
  var restart = false
}

struct WorkoutFlowView: View {
  @Environment(\.dismiss) private var dismiss
  let route: WorkoutRoute
  @State private var workoutID: String?

  init(route: WorkoutRoute) {
    self.route = route
    _workoutID = State(initialValue: route.workoutID)
  }

  var body: some View {
    NavigationStack {
      Group {
        if let workoutID {
          WorkoutSessionView(workoutID: workoutID)
            .transition(.opacity)
        } else if let scheduleID = route.scheduleID {
          WorkoutPreparationView(scheduleID: scheduleID, restart: route.restart) { workoutID = $0 }
            .transition(.opacity)
        }
      }
      .sportAnimation(value: workoutID)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
      }
    }
  }
}

private struct WorkoutPreparationView: View {
  @EnvironmentObject private var store: TrainingStore
  let scheduleID: String
  let restart: Bool
  let onStart: (String) -> Void
  @State private var stretch: StretchMovement?
  @State private var stretchSeconds = 30
  @State private var overrides: [String: AvailableLoad] = [:]
  @State private var starting = false
  @State private var error: String?

  var body: some View {
    TrainingContent { snapshot in
      if let schedule = snapshot.schedules.first(where: { $0.id == scheduleID }) {
        List {
          if let first = snapshot.exercises(for: schedule).first {
            WorkoutSupportPreview(
              first: first, goal: schedule.goals[first.id],
              override: overrides[first.id], restSeconds: snapshot.restSeconds,
              stretch: $stretch, stretchSeconds: $stretchSeconds)
          }
          Section("Planned Exercises") {
            ForEach(snapshot.exercises(for: schedule)) { exercise in
              VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                ExerciseGoalRow(exercise: exercise, scheduleID: schedule.id)
              }
            }
          }
          BackpackPreparation(
            exercises: snapshot.exercises(for: schedule), goals: Array(schedule.goals.values),
            overrides: $overrides)
          Section {
            LabeledContent(
              "Rest Between Sets", value: TrainingLabels.rest(snapshot.restSeconds))
          } footer: {
            Text(
              "Goals and rest duration stay fixed during this workout."
            )
          }
          Section {
            Button {
              start()
            } label: {
              WorkoutActionLabel(
                title: starting
                  ? "Starting…" : restart ? "Start Again" : "Start Workout",
                systemImage: "play.fill", isWorking: starting
              )
            }
            .sportProminentButton().controlSize(.large)
            .listRowBackground(Color.clear)
            .disabled(starting)
          }
        }
        .listSectionSpacing(.compact)
        .navigationTitle(schedule.name)
      } else {
        ContentUnavailableView(
          "Workout Deleted", systemImage: "calendar",
          description: Text("Close this screen and check Workouts."))
      }
    }
    .alert(
      "Workout Not Started",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }

  private func start() {
    starting = true
    Task {
      defer { starting = false }
      do {
        onStart(
          try await store.startWorkout(
            scheduleID: scheduleID, restart: restart, loadOverrides: overrides, stretch: stretch,
            stretchSeconds: stretchSeconds))
      } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

struct WorkoutSessionView: View {
  @EnvironmentObject private var store: TrainingStore
  let workoutID: String
  @State private var correcting: WorkoutSet?
  @State private var terminal: WorkoutSession?
  @State private var loadError: String?
  @State private var actionError: String?
  @State private var busy = false
  @State private var confirmCancel = false
  @FocusState private var focused: WorkoutInputField?

  private var session: WorkoutSession? {
    if store.workouts.active?.id == workoutID { return store.workouts.active }
    return loadError == nil ? terminal : nil
  }

  var body: some View {
    Group {
      if let session {
        switch session.phase {
        case .support:
          WorkoutSupportFlowView(workout: session).id(session.currentSupport?.id)
        case .resting where session.isSupportRest:
          WorkoutSupportFlowView(workout: session).id(session.rest?.id)
        case .completed, .cancelled:
          WorkoutSummaryList(workout: session, showsProgression: true)
            .transition(.opacity)
        default:
          if let exercise = session.currentExercise {
            List {
              Section {
                VStack(alignment: .leading, spacing: 8) {
                  let index = session.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
                  Text("Exercise \(index + 1) of \(session.exercises.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
                  Text(exercise.definition.name).font(.title2).fontWeight(.semibold)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                  Text(TrainingLabels.target(exercise.definition))
                    .font(.subheadline).foregroundStyle(.secondary)
                  WorkoutSetProgress(exercise: exercise)
                  WorkoutGoalLabel(exercise: exercise)
                }
                .padding(.vertical, 4)
              }
              .listRowBackground(Color.clear)
              switch session.phase {
              case .readySet:
                if exercise.definition.tracking == .duration {
                  TimedSetPreparation(
                    workout: session, exercise: exercise, busy: busy, focused: $focused
                  ).id("\(exercise.id)-\(exercise.sets.count)")
                } else {
                  Section {
                    Button {
                      perform { try await store.beginSet(workout: session, exercise: exercise) }
                    } label: {
                      WorkoutActionLabel(
                        title: busy ? "Starting…" : "Start Set", systemImage: "play.fill",
                        isWorking: busy)
                    }
                    .sportProminentButton().controlSize(.large)
                    .listRowBackground(Color.clear)
                    .disabled(busy)
                  } header: {
                    Text("Set \(exercise.sets.count + 1) of \(exercise.definition.setCount)")
                  } footer: {
                    if !exercise.sets.isEmpty {
                      Text("Rest complete.")
                    }
                  }
                }
              case .countdown, .activeSet:
                if exercise.definition.tracking == .duration {
                  WorkoutTimedSetView(
                    workout: session, exercise: exercise, busy: busy,
                    cancel: {
                      perform {
                        try await store.cancelSetCountdown(workout: session, exercise: exercise)
                      }
                    },
                    finish: {
                      perform {
                        try await store.finishTimedSet(workout: session, exercise: exercise)
                      }
                    }
                  ).id("\(exercise.id)-\(exercise.sets.count)")
                } else {
                  ActiveSetForm(workout: session, exercise: exercise, focused: $focused)
                    .id("\(exercise.id)-\(exercise.sets.count)")
                }
              case .completedSet:
                ActiveSetForm(workout: session, exercise: exercise, focused: $focused)
                  .id("\(exercise.id)-\(exercise.sets.count)")
              case .resting:
                if let rest = session.rest {
                  RestControls(rest: rest, nextSet: exercise.sets.count + 1, busy: busy) { action in
                    perform { try await store.changeRest(id: rest.id, action: action) }
                  }
                }
                if let message = store.liveActivityMessage {
                  Section {
                    Text(message).foregroundStyle(.secondary)
                    Button("Retry Live Activity") {
                      Task { await store.refreshLiveActivity(retry: true) }
                    }
                  }
                }
              case .feeling:
                FeelingForm(workout: session, exercise: exercise).id(exercise.id)
              case .support, .completed, .cancelled: EmptyView()
              }
              Section("Reference") {
                if !exercise.sets.isEmpty {
                  DisclosureGroup("Recorded Sets (\(exercise.sets.count))") {
                    ForEach(exercise.sets) { set in
                      Button {
                        correcting = set
                      } label: {
                        LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
                          .foregroundStyle(.primary)
                      }.buttonStyle(.plain)
                        .accessibilityHint("Edit this recorded set")
                    }
                  }
                }
                PreviousPerformanceRow(exerciseID: exercise.definition.id, workoutID: workoutID)
                  .id(exercise.id)
                if let index = session.exercises.firstIndex(where: { $0.id == exercise.id }),
                  index + 1 < session.exercises.count
                {
                  LabeledContent("Up Next", value: session.exercises[index + 1].definition.name)
                }
              }
              if let error = store.workoutError {
                Section {
                  Text(error).foregroundStyle(.secondary)
                  Button("Try Again") { Task { await store.refreshWorkouts() } }
                }
              }
            }
            .sportAnimation(value: session.phase)
            .sportAnimation(value: exercise.id)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 8, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
          }
        }
      } else if let loadError {
        ContentUnavailableView {
          Label("Workout Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadError)
        } actions: {
          Button("Try Again") { Task { await loadTerminal() } }
        }
      } else {
        ProgressView("Loading…")
      }
    }
    .sportAnimation(value: session?.status)
    .disabled(store.workouts.active?.id != workoutID && terminal?.status == .active)
    .onChange(of: store.workouts.active, initial: true) { _, active in
      // Keep the last rendered content while loading the saved terminal summary.
      if let active, active.id == workoutID { terminal = active }
    }
    .navigationTitle(
      session?.phase == .completed
        ? "Workout Complete"
        : session?.phase == .cancelled ? "Workout Cancelled" : session?.name ?? "Workout"
    )
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
          focused = nil
        }.tint(.white)
          .labelStyle(.iconOnly)
      }
      if session?.status == .active {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            SportDestructiveButton("Cancel Workout", systemImage: "stop.fill") {
              confirmCancel = true
            }
          } label: {
            Label("Options", systemImage: "ellipsis")
          }.tint(.white)
            .disabled(busy)
        }
      }
    }
    .sportConfirmation(
      "Cancel Workout?", isPresented: $confirmCancel
    ) {
      Button("Cancel Workout", role: .destructive) {
        perform { try await store.cancelWorkout(id: workoutID) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Recorded sets will remain in history. The rest timer will stop.")
    }
    .alert(
      "Action Not Saved",
      isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
    ) {
      Button("OK", role: .cancel) { actionError = nil }
    } message: {
      Text(actionError ?? "")
    }
    .sheet(item: $correcting) { set in
      if let exercise = session?.exercises.first(where: {
        $0.sets.contains(where: { $0.id == set.id })
      }) {
        SetCorrectionEditor(workoutID: workoutID, exerciseID: exercise.id, set: set)
      }
    }
    .task(id: store.workouts.active?.id == workoutID) {
      if store.workouts.active?.id != workoutID { await loadTerminal() }
    }
  }

  private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }
    busy = true
    Task {
      defer { busy = false }
      do { try await operation() } catch { actionError = error.localizedDescription }
    }
  }

  private func loadTerminal() async {
    do {
      terminal = try await store.workout(id: workoutID)
      loadError = nil
    } catch { loadError = error.localizedDescription }
  }
}
