import SportCore
import SwiftUI

struct ProgressFactLabel: View {
  let fact: ProgressFact
  var body: some View {
    switch fact {
    case .repetitionsAdded(let delta, let grams):
      Text("\(delta) more repetition(s) at \(WorkoutLabels.weight(grams)) kg")
    case .durationAdded(let delta, let grams):
      Text("\(WorkoutLabels.weight(delta)) more seconds at \(WorkoutLabels.weight(grams)) kg")
    case .effortLower(let previous, let current):
      Text(
        "Reported effort: \(WorkoutLabels.feeling(previous)) → \(WorkoutLabels.feeling(current))")
    case .loadChanged(let previous, let current):
      Text(
        "Load used: \(WorkoutLabels.weight(previous)) → \(WorkoutLabels.weight(current)) kg")
    }
  }
}
