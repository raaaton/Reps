import Foundation
import SportCore
import SportLiveSupport
import SwiftUI
import UIKit

@MainActor
final class TrainingStore: ObservableObject {
  enum Phase {
    case loading
    case ready(TrainingSnapshot)
    case failed(String)
  }

  @Published private(set) var phase: Phase = .loading
  @Published private(set) var availableLoads: [AvailableLoad] = [.bodyweight]
  @Published private(set) var historyRevision = 0
  @Published private(set) var notificationPreferences = NotificationPreferences()
  @Published private(set) var workouts: WorkoutOverview = .empty
  @Published private(set) var workoutError: String?
  @Published private(set) var liveActivityMessage: String?
  @Published private(set) var pendingWorkoutID: String?
  var isReady: Bool {
    if case .ready = phase { return true }
    return false
  }
  private var refreshingWorkouts = false
  private var workoutRefreshPending = false
  private var pendingRestFeedback = false
  private var workoutFeedback = WorkoutFeedbackTracker()
  private lazy var restFeedback = RestFeedback()
  private var repository: SportRepository?
  private var loading = false
  private var generation = 0
  private var workoutGeneration = 0

  func reload() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    generation += 1
    let request = generation
    do {
      if repository == nil {
        repository = try await SportRuntime.shared.repository()
      }
      guard let repository else { throw TrainingError.storage }
      workoutGeneration += 1
      let workoutRequest = workoutGeneration
      let overview = try await repository.workoutOverview(now: WorkoutClock.now)
      let snapshot = try await repository.snapshot()
      let preferences = try await repository.reminderContext().preferences
      consumeFeedback(overview)
      if workoutGeneration == workoutRequest {
        workouts = overview
        workoutError = nil
      }
      if generation == request {
        availableLoads = try WeightInventory.loads(items: snapshot.weightItems)
        phase = .ready(snapshot)
        notificationPreferences = preferences
        if !overview.expiredStretchIDs.isEmpty { historyRevision += 1 }
      }
      await refreshLiveActivity(retry: true)
      await LocalReminderCoordinator.shared.refresh()
    } catch {
      if generation == request { phase = .failed(error.localizedDescription) }
    }
  }

  func saveSchedule(_ schedule: TrainingSchedule, creating: Bool = false) async throws {
    try await commit { try await $0.saveSchedule(schedule, creating: creating) }
  }

  func deleteSchedule(id: String) async throws {
    try await commit { try await $0.deleteSchedule(id: id) }
  }

  func deleteExercise(id: String) async throws {
    try await commit { try await $0.deleteExercise(id: id) }
  }
  func deleteArchivedExercise(id: String) async throws {
    try await commit { try await $0.deleteArchivedExercise(id: id) }
  }

  func saveExercise(_ exercise: TrainingExercise) async throws {
    try await commit { try await $0.saveExercise(exercise) }
  }

  func saveRest(seconds: Int) async throws {
    try await commit { try await $0.saveRest(seconds: seconds) }
  }

  func saveNotificationPreferences(_ preferences: NotificationPreferences) async throws {
    try await commit { try await $0.saveNotificationPreferences(preferences) }
  }

  func startWorkout(
    scheduleID: String, restart: Bool, loadOverrides: [String: AvailableLoad] = [:],
    stretch: StretchMovement? = nil, stretchSeconds: Int = 30
  )
    async throws -> String
  {
    guard let repository else { throw TrainingError.storage }
    generation += 1
    workoutGeneration += 1
    let feedbackBaseline = workouts
    let session = try await repository.startWorkout(
      scheduleID: scheduleID, now: WorkoutClock.now, restart: restart, loadOverrides: loadOverrides,
      includeSupport: true, stretch: stretch, stretchSeconds: stretchSeconds)
    try await refreshState(repository, feedbackBaseline: feedbackBaseline)
    return session.id
  }

  func beginSet(
    workout: WorkoutSession, exercise: WorkoutExercise, weightGrams: Int? = nil,
    load: AvailableLoad? = nil
  ) async throws {
    try await commit {
      try await $0.beginSet(
        workoutID: workout.id, exerciseID: exercise.id, number: exercise.sets.count + 1,
        weightGrams: weightGrams, load: load, now: WorkoutClock.now)
    }
  }

  func finishTimedSet(workout: WorkoutSession, exercise: WorkoutExercise) async throws {
    try await commit {
      try await $0.finishTimedSet(
        workoutID: workout.id, exerciseID: exercise.id, number: exercise.sets.count + 1,
        now: WorkoutClock.now)
    }
  }

  func cancelSetCountdown(workout: WorkoutSession, exercise: WorkoutExercise) async throws {
    guard let start = exercise.setStartedAt else { return }
    try await commit {
      try await $0.cancelSetCountdown(
        workoutID: workout.id, exerciseID: exercise.id, number: exercise.sets.count + 1,
        expectedStart: start, now: WorkoutClock.now)
    }
  }

  func recordSet(
    workout: WorkoutSession, exercise: WorkoutExercise, repetitions: Int?, weightGrams: Int,
    load: AvailableLoad? = nil
  ) async throws {
    try await commit {
      try await $0.recordSet(
        workoutID: workout.id, exerciseID: exercise.id, number: exercise.sets.count + 1,
        repetitions: repetitions, weightGrams: weightGrams, load: load, now: WorkoutClock.now)
    }
  }

  func saveFeeling(workout: WorkoutSession, exercise: WorkoutExercise, tenths: Int) async throws {
    try await commit {
      try await $0.saveFeeling(
        workoutID: workout.id, exerciseID: exercise.id, tenths: tenths, now: WorkoutClock.now)
    }
  }

  func beginSupport(workout: WorkoutSession, step: WorkoutSupportStep) async throws {
    try await commit {
      try await $0.beginSupport(workoutID: workout.id, stepID: step.id, now: WorkoutClock.now)
    }
  }
  func finishSupport(workout: WorkoutSession, step: WorkoutSupportStep, repetitions: Int?)
    async throws
  {
    try await commit {
      try await $0.finishSupport(
        workoutID: workout.id, stepID: step.id, repetitions: repetitions, now: WorkoutClock.now)
    }
  }
  func cancelSupportCountdown(workout: WorkoutSession, step: WorkoutSupportStep) async throws {
    guard let start = step.startedAt else { return }
    try await commit {
      try await $0.cancelSupportCountdown(
        workoutID: workout.id, stepID: step.id, expectedStart: start, now: WorkoutClock.now)
    }
  }

  func changeRest(id: String, action: RestAction) async throws {
    try await commit { try await $0.changeRest(id: id, action: action, now: WorkoutClock.now) }
  }

  func cancelWorkout(id: String) async throws {
    try await commit { try await $0.cancelWorkout(id: id, now: WorkoutClock.now) }
  }

  func addHistoricalWorkout(_ draft: ManualWorkout) async throws {
    try await commit { try await $0.addHistoricalWorkout(draft, now: WorkoutClock.now) }
  }

  func saveWeightItem(_ item: WeightItem) async throws {
    try await commit { try await $0.saveWeightItem(item) }
  }
  func deleteWeightItem(id: String) async throws {
    try await commit { try await $0.deleteWeightItem(id: id) }
  }
  func updateHistoricalWorkout(_ draft: ManualWorkout, original: WorkoutSession) async throws {
    try await commit {
      try await $0.updateHistoricalWorkout(draft, original: original, now: WorkoutClock.now)
    }
  }
  func historyExercises() async throws -> [TrainingExercise] {
    guard let repository else { throw TrainingError.storage }
    return try await repository.historyExercises()
  }
  func exerciseHistory(exerciseID: String) async throws -> [ExercisePerformance] {
    guard let repository else { throw TrainingError.storage }
    return try await repository.exerciseHistory(exerciseID: exerciseID)
  }

  func deleteHistoricalWorkout(id: String) async throws {
    try await commit { try await $0.deleteHistoricalWorkout(id: id) }
  }

  func workout(id: String) async throws -> WorkoutSession {
    guard let repository else { throw TrainingError.storage }
    return try await repository.workout(id: id)
  }

  func previousPerformance(exerciseID: String, excludingWorkoutID: String) async throws
    -> WorkoutExercise?
  {
    guard let repository else { throw TrainingError.storage }
    return try await repository.previousPerformance(
      exerciseID: exerciseID, excludingWorkoutID: excludingWorkoutID)
  }

  func goalContext(exerciseID: String) async throws -> GoalContext {
    guard let repository else { throw TrainingError.storage }
    return try await repository.goalContext(exerciseID: exerciseID)
  }
  func saveGoal(_ goal: ExerciseGoal, original: ExerciseGoal?) async throws {
    try await commit { try await $0.saveGoal(goal, original: original) }
  }
  func adoptGoal(_ suggestion: GoalSuggestion, original: ExerciseGoal?) async throws {
    try await commit { try await $0.adoptGoal(suggestion, original: original) }
  }
  func exerciseLoadGoalDecision(workout: WorkoutSession, exercise: WorkoutExercise, tenths: Int)
    async throws -> ExerciseLoadGoalDecision?
  {
    guard let repository else { throw TrainingError.storage }
    return try await repository.exerciseLoadGoalDecision(
      workoutID: workout.id, exerciseID: exercise.id,
      feelingTenths: tenths, now: WorkoutClock.now)
  }
  func resolveExerciseLoadGoal(_ decision: ExerciseLoadGoalDecision, update: Bool) async throws {
    try await commit {
      try await $0.resolveExerciseLoadGoal(decision, update: update, now: WorkoutClock.now)
    }
  }
  func correctSet(
    workoutID: String, exerciseID: String, original: WorkoutSet, repetitions: Int?,
    durationMS: Int?, weightGrams: Int
  ) async throws {
    try await commit {
      try await $0.correctSet(
        workoutID: workoutID, exerciseID: exerciseID, original: original, repetitions: repetitions,
        durationMS: durationMS, weightGrams: weightGrams)
    }
  }
  func progressReports(workoutID: String) async throws -> [ExerciseReport] {
    guard let repository else { throw TrainingError.storage }
    return try await repository.progressReports(workoutID: workoutID)
  }

  func exportTraining() async throws -> TrainingArchive {
    guard let repository else { throw TrainingError.storage }
    return try await repository.exportTraining(now: WorkoutClock.now)
  }
  func recoveryArchive() async throws -> TrainingArchive? {
    guard let repository else { throw TrainingError.storage }
    return try await repository.recoveryArchive()
  }
  func previewCSVImport(_ records: [WorkoutSession]) async throws -> TrainingImportPreview {
    guard let repository else { throw TrainingError.storage }
    return try await repository.previewCSVImport(records, now: WorkoutClock.now)
  }
  func previewArchiveImport(_ archive: TrainingArchive) async throws -> TrainingImportPreview {
    guard let repository else { throw TrainingError.storage }
    return try await repository.previewArchiveImport(archive, now: WorkoutClock.now)
  }
  func applyTrainingImport(_ preview: TrainingImportPreview) async throws {
    try await commit { try await $0.applyTrainingImport(preview, now: WorkoutClock.now) }
  }

  func refreshWorkouts() async {
    guard let repository else { return }
    workoutRefreshPending = true
    guard !refreshingWorkouts else { return }
    refreshingWorkouts = true
    defer { refreshingWorkouts = false }
    repeat {
      workoutRefreshPending = false
      workoutGeneration += 1
      let request = workoutGeneration
      let configurationRequest = generation
      do {
        let overview = try await repository.workoutOverview(now: WorkoutClock.now)
        consumeFeedback(overview)
        if !overview.expiredStretchIDs.isEmpty {
          let snapshot = try await repository.snapshot()
          if generation == configurationRequest && workoutGeneration == request {
            availableLoads = try WeightInventory.loads(items: snapshot.weightItems)
            phase = .ready(snapshot)
            historyRevision += 1
          }
        }
        if workoutGeneration == request {
          workouts = overview
          workoutError = nil
        }
        await refreshLiveActivity()
      } catch {
        if workoutGeneration == request { workoutError = error.localizedDescription }
      }
    } while workoutRefreshPending
  }

  private func refreshState(_ repository: SportRepository, feedbackBaseline: WorkoutOverview)
    async throws
  {
    generation += 1
    let request = generation
    workoutGeneration += 1
    let workoutRequest = workoutGeneration
    let overview = try await repository.workoutOverview(now: WorkoutClock.now)
    let snapshot = try await repository.snapshot()
    let preferences = try await repository.reminderContext().preferences
    consumeFeedback(overview)
    var event = workoutFeedback.event(from: feedbackBaseline, to: overview)
    if workoutGeneration == workoutRequest {
      workouts = overview
      workoutError = nil
    }
    if generation == request {
      if case .ready(let previous) = phase, previous.goals != snapshot.goals {
        event = .success
      }
      availableLoads = try WeightInventory.loads(items: snapshot.weightItems)
      phase = .ready(snapshot)
      notificationPreferences = preferences
      historyRevision += 1
    }
    // Do not wait for ActivityKit or notification reconciliation to acknowledge saved state.
    if let event, overview.expiredRestIDs.isEmpty && overview.expiredStretchIDs.isEmpty {
      SportHaptics.shared.play(event)
    }
    await refreshLiveActivity()
    await LocalReminderCoordinator.shared.refresh()
  }

  func refreshLiveActivity(retry: Bool = false) async {
    await RestActivityCoordinator.shared.refresh(retry: retry)
    liveActivityMessage = RestActivityCoordinator.shared.message
  }

  func requestWorkoutLink(_ url: URL) {
    guard url.scheme == "sport", url.host == "workout",
      UUID(uuidString: url.lastPathComponent) != nil
    else { return }
    pendingWorkoutID = url.lastPathComponent
  }

  func consumeWorkoutLink() { pendingWorkoutID = nil }

  private func consumeFeedback(_ overview: WorkoutOverview) {
    pendingRestFeedback =
      pendingRestFeedback || !overview.expiredRestIDs.isEmpty || !overview.expiredStretchIDs.isEmpty
    if pendingRestFeedback && UIApplication.shared.applicationState == .active {
      pendingRestFeedback = false
      restFeedback.play()
    }
  }

  private func commit(_ operation: (SportRepository) async throws -> Void) async throws {
    guard let repository else { throw TrainingError.storage }
    generation += 1
    workoutGeneration += 1
    let feedbackBaseline = workouts
    try await operation(repository)
    try await refreshState(repository, feedbackBaseline: feedbackBaseline)
  }
}

struct TrainingContent<Content: View>: View {
  @EnvironmentObject private var store: TrainingStore
  @ViewBuilder var content: (TrainingSnapshot) -> Content

  var body: some View {
    switch store.phase {
    case .loading:
      ProgressView("Loading…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .ready(let snapshot):
      content(snapshot)
    case .failed(let message):
      ContentUnavailableView {
        Label("Data Unavailable", systemImage: "exclamationmark.triangle")
      } description: {
        Text(message)
      } actions: {
        Button("Try Again") { Task { await store.reload() } }
      }
    }
  }
}
