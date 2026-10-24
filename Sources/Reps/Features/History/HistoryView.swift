import RepsCore
import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var adding = false
  @State private var byExercise = false
  @State private var deleting: WorkoutSummary?
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    TrainingContent { _ in
      List {
        Section {
          Picker("Show", selection: $byExercise) {
            Text("Workouts").tag(false)
            Text("Exercises").tag(true)
          }.pickerStyle(.segmented)
        }.listRowBackground(Color.clear)
        Section { NavigationLink("Skill Practices") { SkillHistoryView() } }
        if byExercise {
          ExerciseHistoryIndex()
        } else {
          if store.workouts.history.isEmpty {
            ContentUnavailableView(
              "No Recorded Workouts", systemImage: "clock.arrow.circlepath",
              description: Text(
                "Your workouts will appear here. Use + to record a past workout.")
            )
            .listRowBackground(Color.clear)
          }
          ForEach(store.workouts.history) { workout in
            NavigationLink {
              WorkoutHistoryDetail(workoutID: workout.id)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(workout.name).font(.headline).foregroundStyle(.primary)
                Text("\(WorkoutLabels.day(workout.dayKey)) · \(workout.setCount) sets")
                  .font(.subheadline).foregroundStyle(.secondary)
                if workout.status == .cancelled {
                  Text("Canceled").font(.caption).foregroundStyle(.secondary)
                }
              }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", systemImage: "trash", role: .destructive) { deleting = workout }
                .labelStyle(.titleAndIcon)
            }
            .contextMenu {
              RepsDestructiveButton("Delete", systemImage: "trash") { deleting = workout }
            }
          }
        }
      }
      .disabled(busy)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Workout", systemImage: "plus") { adding = true }.tint(.white)
            .disabled(busy)
        }
      }
      .sheet(isPresented: $adding) { ManualWorkoutEditor() }
      .repsConfirmation(
        "Delete This Workout?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        presenting: deleting
      ) { workout in
        Button("Delete Workout", role: .destructive) { delete(workout) }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: { workout in
        Text(
          "“\(workout.name)” from \(WorkoutLabels.day(workout.dayKey)) and all its sets will be deleted from history. Workouts and exercises in Settings will be kept."
        )
      }
      .alert(
        "Unable to Delete",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
    .navigationTitle("History")
  }

  private func delete(_ workout: WorkoutSummary) {
    guard !busy else { return }
    deleting = nil
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteHistoricalWorkout(id: workout.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

struct WorkoutHistoryDetail: View {
  @EnvironmentObject private var store: TrainingStore
  let workoutID: String
  @State private var editing = false
  @State private var workout: WorkoutSession?
  @State private var error: String?
  private var exists: Bool { store.workouts.history.contains { $0.id == workoutID } }

  var body: some View {
    Group {
      if !exists {
        ContentUnavailableView(
          "Workout Deleted", systemImage: "clock.arrow.circlepath",
          description: Text("This workout is no longer in your history."))
      } else if let workout {
        WorkoutSummaryList(workout: workout)
      } else if let error {
        ContentUnavailableView {
          Label("Workout Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Try Again") { Task { await load() } }
        }
      } else {
        ProgressView("Loading…")
      }
    }
    .navigationTitle(workout?.name ?? "Workout")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if exists, workout != nil {
        ToolbarItem(placement: .primaryAction) {
          Button("Edit", systemImage: "pencil") { editing = true }.tint(.white)
            .labelStyle(.iconOnly)
        }
      }
    }
    .sheet(isPresented: $editing) {
      if let workout { ManualWorkoutEditor(workout: workout) }
    }
    .task(id: store.historyRevision) {
      if exists { await load() } else { workout = nil }
    }
  }

  private func load() async {
    do {
      workout = try await store.workout(id: workoutID)
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}

struct WorkoutSummaryList: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  var showsProgression = false
  @State private var reports: [ExerciseReport] = []
  @State private var reportError: String?

  var body: some View {
    List {
      Section {
        LabeledContent("Date", value: WorkoutLabels.day(workout.dayKey))
        if let elapsed = workout.totalElapsedMS {
          LabeledContent("Total Time", value: WorkoutLabels.elapsed(elapsed))
        }
        LabeledContent(
          "Status",
          value: workout.status == .completed
            ? "Completed" : workout.status == .cancelled ? "Canceled" : "In Progress")
      }
      if let support = workout.support {
        ForEach([SupportKind.warmUp, .stretch], id: \.self) { kind in
          Section(kind == .warmUp ? "Warm-up" : "Stretch") {
            ForEach(support.steps.filter { $0.kind == kind }) { step in
              VStack(alignment: .leading, spacing: 4) {
                Text(step.name).font(.headline)
                if let reps = step.repetitions {
                  Text("Set \(step.number): \(reps) reps · Bodyweight").foregroundStyle(.secondary)
                } else if let duration = step.durationMS {
                  Text("Hold \(step.number): \(WorkoutLabels.time(duration))").foregroundStyle(
                    .secondary)
                } else {
                  Text("Not completed").foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
      if let skills = workout.skills {
        ForEach(skills.blocks) { SkillPracticeResultSections(practice: $0) }
      }
      ForEach(workout.exercises) { exercise in
        Section(exercise.definition.name) {
          ForEach(exercise.sets) { set in
            if let components = set.components, !components.isEmpty {
              DisclosureGroup {
                ForEach(components) { component in
                  LabeledContent(
                    component.name, value: "\(WorkoutLabels.weight(component.grams)) kg")
                }
              } label: {
                LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
              }
            } else {
              VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
                if set.weightGrams > 0, set.components == nil {
                  Text("Composition not recorded").font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
          if exercise.sets.isEmpty { Text("No Recorded Sets").foregroundStyle(.secondary) }
          if showsProgression, workout.status == .completed {
            if let report = reports.first(where: { $0.exerciseID == exercise.definition.id }) {
              ForEach(Array(report.facts.enumerated()), id: \.offset) { _, fact in
                ProgressFactLabel(fact: fact).font(.subheadline).foregroundStyle(.secondary)
              }
            }
            if case .ready(let snapshot) = store.phase,
              snapshot.exercises.contains(where: { $0.id == exercise.definition.id })
            {
              ExerciseWorkoutGoals(exercise: exercise.definition)
            }
          }
          if let feeling = exercise.feelingTenths {
            LabeledContent("Feeling", value: "\(WorkoutLabels.feeling(feeling)) / 10")
          }
        }
      }
      if let reportError { Section { Text(reportError).foregroundStyle(.secondary) } }
    }
    .task(id: store.historyRevision) {
      guard showsProgression, workout.status == .completed else { return }
      do {
        let data = try await store.progressReports(workoutID: workout.id)
        guard !Task.isCancelled else { return }
        reports = data
        reportError = nil
      } catch { if !Task.isCancelled { reportError = error.localizedDescription } }
    }
  }
}
