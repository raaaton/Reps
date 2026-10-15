import SportCore
import SwiftUI

struct BackpackPreparation: View {
  @EnvironmentObject private var store: TrainingStore
  let exercises: [TrainingExercise]
  let goals: [ExerciseGoal]
  @Binding var overrides: [String: AvailableLoad]
  var body: some View {
    Section {
      ForEach(exercises) { exercise in
        DisclosureGroup(exercise.name) {
          let selected =
            overrides[exercise.id] ?? goals.first { $0.definition.id == exercise.id }?.load
            ?? .bodyweight
          WeightSelectionRow(
            selection: Binding(get: { selected }, set: { overrides[exercise.id] = $0 }))
          if selected.grams == 0 { Text("No added weight needed.").foregroundStyle(.secondary) }
          ForEach(selected.components) { component in
            LabeledContent(component.name, value: "\(WorkoutLabels.weight(component.grams)) kg")
          }
        }
      }
    } header: {
      Text("Prepare Backpack")
    } footer: {
      Text(
        "Check the items for each load. Choosing another load here affects only this workout; your usual goal stays unchanged."
      )
    }
  }
}
