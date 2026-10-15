import SportCore
import SwiftUI

struct ProgressionResult: View {
  let assessment: ProgressionAssessment
  var body: some View {
    switch assessment.status {
    case .insufficient: EmptyView()
    case .increase:
      if let load = assessment.nextLoad {
        Text("Next load: \(WorkoutLabels.weight(load.grams)) kg")
          .foregroundStyle(.tint)
      }
    case .noHeavierLoad:
      Text("Goal reached. No heavier load available.").foregroundStyle(.secondary)
    case .achieved:
      Text("Goal Reached").foregroundStyle(.secondary)
    case .maintain:
      if let grams = assessment.referenceGrams {
        Text("Keep working toward \(WorkoutLabels.weight(grams)) kg").foregroundStyle(.secondary)
      }
    }
  }
}

struct ProgressionRow: View {
  @EnvironmentObject private var store: TrainingStore
  let target: TrainingExercise
  var workoutID = ""
  @State private var previous: WorkoutExercise?
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let error {
        Text(error).foregroundStyle(.secondary)
      } else {
        ProgressionResult(
          assessment: Progression.assess(
            target: target, previous: previous, loads: store.availableLoads))
      }
    }
    .font(.subheadline)
    .task(id: store.historyRevision) {
      do {
        let value = try await store.previousPerformance(
          exerciseID: target.id, excludingWorkoutID: workoutID)
        guard !Task.isCancelled else { return }
        previous = value
        error = nil
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
  }
}
