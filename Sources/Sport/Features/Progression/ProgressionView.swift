import SportCore
import SwiftUI

struct ProgressionView: View {
  @EnvironmentObject private var store: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var vaultOpen = false
  @State private var bodyWeightOpen = false
  @State private var bodyWeightVisible = false
  @State private var awaitingBodyWeightDismissal = false
  @State private var archived: [TrainingExercise] = []
  @State private var error: String?
  @State private var selectedDay: AttendanceDay?
  @State private var deletingArchived: TrainingExercise?
  var body: some View {
    TrainingContent { snapshot in
      let old = archived.filter { item in !snapshot.exercises.contains { $0.id == item.id } }
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
              Text("Unlock Private Photos once to show earlier photo days here.")
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
            ForEach(snapshot.exercises + old) { exercise in
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
                    Text(
                      snapshot.exercises.contains { $0.id == exercise.id }
                        ? "Goal and Progress" : "Archived exercise"
                    ).font(.subheadline).foregroundStyle(.secondary)
                  }
                }
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !snapshot.exercises.contains(where: { $0.id == exercise.id }) {
                  Button("Delete", systemImage: "trash", role: .destructive) {
                    deletingArchived = exercise
                  }.labelStyle(.titleAndIcon)
                }
              }
              .contextMenu {
                if !snapshot.exercises.contains(where: { $0.id == exercise.id }) {
                  SportDestructiveButton("Delete", systemImage: "trash") {
                    deletingArchived = exercise
                  }
                }
              }
            }
            if let error { Text(error).foregroundStyle(.secondary) }
          }
          Section {
            Button {
              vaultOpen = true
            } label: {
              Label("Private Photos", systemImage: "lock")
            }.foregroundStyle(.primary)
          }
        }
        // Keep the native list out of the invalid deletion batch seen on iPhone.
        // Goal, attendance and timer updates retain identity and scroll position.
        .id([snapshot.exercises.map(\.id), old.map(\.id)])
      }
    }
    .navigationTitle("Progress")
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
    .modifier(ArchivedExerciseDeletion(selection: $deletingArchived))
    .fullScreenCover(isPresented: $vaultOpen, onDismiss: vaultDismissed) { PhotoVaultView() }
    .task(id: store.historyRevision) {
      do {
        let data = try await store.historyExercises()
        guard !Task.isCancelled else { return }
        archived = data
        error = nil
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
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
