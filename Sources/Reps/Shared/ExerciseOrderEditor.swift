import RepsCore
import SwiftUI

@MainActor
final class ExerciseOrderEditor: ObservableObject {
  @Published private(set) var saving = false
  @Published private var pendingIDs: [String]?
  @Published var error: String?

  func displayed(_ exercises: [TrainingExercise]) -> [TrainingExercise] {
    guard let pendingIDs, Set(pendingIDs) == Set(exercises.map(\.id)) else { return exercises }
    let definitions = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    return pendingIDs.compactMap { definitions[$0] }
  }

  func move(
    from source: IndexSet, to destination: Int, exercises: [TrainingExercise], store: TrainingStore
  ) {
    guard !saving else { return }
    var ids = exercises.map(\.id)
    ids.move(fromOffsets: source, toOffset: destination)
    guard ids != exercises.map(\.id) else { return }
    pendingIDs = ids
    saving = true
    Task {
      defer {
        pendingIDs = nil
        saving = false
      }
      do { try await store.reorderExercises(ids: ids) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

struct ExerciseOrderControls: ViewModifier {
  @EnvironmentObject private var store: TrainingStore
  @ObservedObject var editor: ExerciseOrderEditor
  @State private var editMode: EditMode = .inactive

  private var canReorder: Bool {
    guard case .ready(let snapshot) = store.phase else { return false }
    return snapshot.exercises.count > 1
  }

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if canReorder || editMode.isEditing {
            EditButton().disabled(editor.saving).tint(.white)
          }
        }
      }
      .alert(
        "Unable to Reorder",
        isPresented: Binding(get: { editor.error != nil }, set: { if !$0 { editor.error = nil } })
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(editor.error ?? "")
      }
      .environment(\.editMode, $editMode)
      .onDisappear { editMode = .inactive }
  }
}
