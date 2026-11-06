import RepsCore
import SwiftUI

struct ArchivedExercisesView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var history: [TrainingExercise] = []
  @State private var deleting: TrainingExercise?
  @State private var error: String?

  var body: some View {
    TrainingContent { snapshot in
      let exercises =
        snapshot.archivedExercises
        + history.filter { exercise in
          !snapshot.exercises.contains { $0.id == exercise.id }
            && !snapshot.archivedExercises.contains { $0.id == exercise.id }
        }
      List {
        if exercises.isEmpty {
          ContentUnavailableView(
            "No Archived Exercises", systemImage: "archivebox",
            description: Text(
              "Archive an exercise in Settings → Exercises to keep its results here."))
        } else {
          ForEach(exercises) { exercise in
            NavigationLink {
              ExerciseProgressView(exercise: exercise)
            } label: {
              Text(exercise.name).foregroundStyle(.primary)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", systemImage: "trash", role: .destructive) {
                deleting = exercise
              }.tint(.red).labelStyle(.titleAndIcon)
            }
            .contextMenu {
              RepsDestructiveButton("Delete", systemImage: "trash") { deleting = exercise }
            }
          }
        }
        if let error { Text(error).foregroundStyle(.secondary) }
      }
      // Recreate membership after a permanent deletion, outside native List batch updates.
      .id(exercises.map(\.id))
    }
    .navigationTitle("Archived Exercises")
    .modifier(ArchivedExerciseDeletion(selection: $deleting))
    .task(id: store.historyRevision) {
      do {
        let exercises = try await store.historyExercises()
        guard !Task.isCancelled else { return }
        history = exercises
        error = nil
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
  }
}
