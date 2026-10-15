import SportCore

// Keep the chosen snapshot visible even when it is no longer selectable; never hide it with 0 kg.
enum WorkoutInputDefaults {
  static func load(for exercise: WorkoutExercise, available: [AvailableLoad]) -> AvailableLoad {
    if let last = exercise.sets.last {
      if let components = last.components {
        return AvailableLoad(grams: last.weightGrams, components: components)
      }
      return available.first { $0.grams == last.weightGrams }
        ?? AvailableLoad(grams: last.weightGrams, components: [])
    }
    return exercise.goal?.load ?? .bodyweight
  }
  static func repetitionTarget(for exercise: WorkoutExercise) -> Int? {
    let index = exercise.sets.count
    if let targets = exercise.goal?.repetitions, targets.indices.contains(index) {
      return targets[index]
    }
    return exercise.definition.minimumReps
  }
}
