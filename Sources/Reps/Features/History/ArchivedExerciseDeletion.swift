import RepsCore
import SwiftUI

struct ArchivedExerciseDeletion: ViewModifier {
  @EnvironmentObject private var store: TrainingStore
  @Binding var selection: TrainingExercise?
  @State private var busy = false
  @State private var error: String?
  func body(content: Content) -> some View {
    content.disabled(busy)
      .repsConfirmation(
        "Delete Archived Exercise?",
        isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }),
        presenting: selection
      ) { exercise in
        Button("Delete Past Results", role: .destructive) { remove(exercise) }
        Button("Cancel", role: .cancel) { selection = nil }
      } message: { exercise in
        Text(
          "All past results for “\(exercise.name)” will be permanently deleted. Workouts containing only this exercise will also be deleted. Other exercises will be kept."
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
  private func remove(_ exercise: TrainingExercise) {
    guard !busy else { return }
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteArchivedExercise(id: exercise.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
