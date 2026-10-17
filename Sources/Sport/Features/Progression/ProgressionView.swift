import SportCore
import SwiftUI

struct ProgressionView: View {
  @EnvironmentObject private var store: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @State private var vaultOpen = false
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
          history: summaries, scheduledWeekdays: scheduledWeekdays, ending: context.date)
        List {
          Section("Consistency") {
            LabeledContent(
              "Days with Completed Workouts",
              value: String(days.filter { $0.state == .completed }.count))
            AttendanceGrid(days: days) { selectedDay = $0 }
            NavigationLink("View Days as a List") { AttendanceListView(days: days) }
          }
          Section("Exercises") {
            ForEach(snapshot.exercises + old) { exercise in
              NavigationLink {
                ExerciseProgressView(exercise: exercise)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(exercise.name).foregroundStyle(.primary)
                  if let goal = snapshot.goals.first(where: { $0.definition.id == exercise.id }) {
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
                  }
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
    .modifier(ArchivedExerciseDeletion(selection: $deletingArchived))
    .fullScreenCover(isPresented: $vaultOpen, onDismiss: { vault.lock() }) { PhotoVaultView() }
    .task(id: store.historyRevision) {
      do {
        let data = try await store.historyExercises()
        guard !Task.isCancelled else { return }
        archived = data
        error = nil
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    .sheet(item: $selectedDay) { day in
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
  private var summaries: [WorkoutSummary] { TrainingAnalytics.summaries(in: store.workouts) }
}
