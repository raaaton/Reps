import RepsCore
import SwiftUI

struct ProgressionView: View {
  @EnvironmentObject private var store: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var vaultOpen = false
  @State private var bodyWeightOpen = false
  @State private var bodyWeightVisible = false
  @State private var awaitingBodyWeightDismissal = false
  @State private var selectedDay: AttendanceDay?
  @StateObject private var exerciseOrder = ExerciseOrderEditor()
  var body: some View {
    TrainingContent { snapshot in
      let exercises = exerciseOrder.displayed(snapshot.exercises)
      TimelineView(.periodic(from: .now, by: 60)) { context in
        let scheduledWeekdays = Set(
          snapshot.schedules.filter {
            $0.isEnabled && !snapshot.exercises(for: $0).isEmpty
          }.map(\.weekday))
        let days = TrainingAnalytics.attendance(
          history: summaries, scheduledWeekdays: scheduledWeekdays, ending: context.date,
          photoCounts: vault.photoActivity?.countsByDay ?? [:])
        List {
          Section("Consistency") {
            StreakSummaryRow(
              days: WorkoutStreak.days(attendance: days, workoutsPerWeek: scheduledWeekdays.count))
            AttendanceGrid(days: days) { selectedDay = $0 }
            NavigationLink("View Days as a List") { AttendanceListView(days: days) }
            if vault.photoActivity?.needsUnlock == true {
              Text("Unlock Private Vault once to show earlier photo days here.")
                .font(.footnote).foregroundStyle(.secondary)
            }
            if let error = vault.photoActivityError {
              Text(error).font(.footnote).foregroundStyle(.secondary)
            }
          }
          Section {
            SkillsNavigationRow()
          }
          Section {
            NavigationLink {
              BodyWeightView()
                .onAppear { bodyWeightVisible = true }
                .onDisappear { bodyWeightVisible = false }
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text("Body Weight").foregroundStyle(.primary)
                if let latest = store.bodyWeights.last {
                  Text(
                    "\(BodyWeightPresentation.value(latest.grams)) · \(WorkoutLabels.day(latest.dayKey))"
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                } else {
                  Text("No measurements yet").font(.subheadline).foregroundStyle(.secondary)
                }
              }
            }
          }
          Section("Exercises") {
            ForEach(exercises) { exercise in
              NavigationLink {
                ExerciseProgressView(exercise: exercise)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(exercise.name).foregroundStyle(.primary)
                  if snapshot.needsGoalReview(for: exercise, availableLoads: store.availableLoads) {
                    Text("Review needed").font(.subheadline).foregroundStyle(.secondary)
                  } else if let goal = snapshot.primaryGoal(for: exercise) {
                    GoalDescription(goal: goal).font(.subheadline)
                  } else {
                    Text("Goal and Progress").font(.subheadline).foregroundStyle(.secondary)
                  }
                }
              }
              .moveDisabled(exerciseOrder.saving)
            }
            .onMove { source, destination in
              exerciseOrder.move(from: source, to: destination, exercises: exercises, store: store)
            }
          }
          Section {
            NavigationLink {
              ArchivedExercisesView()
            } label: {
              Label("Archived Exercises", systemImage: "archivebox")
            }
          }
          Section {
            Button {
              vaultOpen = true
            } label: {
              Label("Private Vault", systemImage: "lock")
            }.foregroundStyle(.primary)
          }
        }
        // Keep the native list out of the invalid deletion batch seen on iPhone.
        // Goal, attendance and timer updates retain identity and scroll position.
        .id(snapshot.exercises.map(\.id).sorted())
      }
    }
    .navigationTitle("Progress")
    .modifier(ExerciseOrderControls(editor: exerciseOrder))
    .navigationDestination(isPresented: $bodyWeightOpen) {
      BodyWeightView()
        .onAppear { bodyWeightVisible = true }
        .onDisappear { bodyWeightVisible = false }
    }
    .onChange(of: store.bodyWeightEntryRequest) { _, _ in openBodyWeightRequest() }
    .onChange(of: store.isReady) { _, _ in openBodyWeightRequest() }
    .task { openBodyWeightRequest() }
    .task(id: scenePhase) {
      if scenePhase == .active { await vault.refreshPhotoActivity() }
    }
    .fullScreenCover(isPresented: $vaultOpen, onDismiss: vaultDismissed) { PhotoVaultView() }
    .sheet(item: $selectedDay, onDismiss: modalDismissed) { day in
      NavigationStack {
        AttendanceDayView(day: day).toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { selectedDay = nil }.tint(.white)
              .labelStyle(.iconOnly)
          }
        }
      }
    }
  }
  private func vaultDismissed() {
    vault.lock()
    modalDismissed()
  }
  private func modalDismissed() {
    awaitingBodyWeightDismissal = false
    openBodyWeightRequest()
  }
  private func openBodyWeightRequest() {
    guard store.isReady, store.bodyWeightEntryRequest != nil else { return }
    if vaultOpen {
      awaitingBodyWeightDismissal = true
      vault.leaveVault()
      vaultOpen = false
      return
    }
    if selectedDay != nil {
      awaitingBodyWeightDismissal = true
      selectedDay = nil
      return
    }
    guard !awaitingBodyWeightDismissal, !bodyWeightVisible else { return }
    bodyWeightOpen = true
  }
  private var summaries: [WorkoutSummary] { TrainingAnalytics.summaries(in: store.workouts) }
}

private struct SkillsNavigationRow: View {
  var body: some View {
    NavigationLink {
      SkillsView()
    } label: {
      Label("Skills", systemImage: "figure.gymnastics")
    }
  }
}
