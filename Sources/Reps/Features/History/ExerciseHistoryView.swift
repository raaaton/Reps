import RepsCore
import SwiftUI

struct ExerciseHistoryIndex: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var exercises: [TrainingExercise] = []
  @State private var loading = true
  @State private var error: String?
  var body: some View {
    Group {
      if let error {
        Text(error).foregroundStyle(.secondary)
      } else if loading {
        ProgressView("Loading…")
      } else if exercises.isEmpty {
        ContentUnavailableView(
          "No Results", systemImage: "figure.strengthtraining.traditional",
          description: Text("Your recorded exercises will appear here.")
        ).listRowBackground(Color.clear)
      } else {
        ForEach(exercises) { exercise in
          NavigationLink(exercise.name) { ExerciseHistoryView(exercise: exercise) }
        }
      }
    }
    .task(id: store.historyRevision) {
      do {
        let result = try await store.historyExercises()
        guard !Task.isCancelled else { return }
        exercises = result
        error = nil
        loading = false
      } catch {
        if !Task.isCancelled {
          self.error = error.localizedDescription
          loading = false
        }
      }
    }
  }
}

struct ExerciseHistoryView: View {
  @EnvironmentObject private var store: TrainingStore
  let exercise: TrainingExercise
  @State private var records: [ExercisePerformance] = []
  @State private var loading = true
  @State private var error: String?
  var body: some View {
    List {
      if let error {
        Text(error).foregroundStyle(.secondary)
      } else if loading {
        ProgressView("Loading…")
      } else if records.isEmpty {
        ContentUnavailableView("No Results", systemImage: "clock.arrow.circlepath")
          .listRowBackground(Color.clear)
      }
      ForEach(records) { record in
        Section(WorkoutLabels.day(record.dayKey)) {
          NavigationLink(record.workoutName) { WorkoutHistoryDetail(workoutID: record.workoutID) }
          if record.status == .cancelled { Text("Workout Canceled").foregroundStyle(.secondary) }
          ForEach(record.exercise.sets) { set in
            LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
          }
          if let feeling = record.exercise.feelingTenths {
            LabeledContent("Feeling", value: "\(WorkoutLabels.feeling(feeling)) / 10")
          }
          if record.exercise.sets.isEmpty {
            Text("No Recorded Sets").foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
    .task(id: store.historyRevision) {
      do {
        let result = try await store.exerciseHistory(exerciseID: exercise.id)
        guard !Task.isCancelled else { return }
        records = result
        error = nil
        loading = false
      } catch {
        if !Task.isCancelled {
          self.error = error.localizedDescription
          loading = false
        }
      }
    }
  }
}
