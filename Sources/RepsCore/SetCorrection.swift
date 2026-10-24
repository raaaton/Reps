extension RepsRepository {
  public func correctSet(
    workoutID: String, exerciseID: String, original: WorkoutSet, repetitions: Int?,
    durationMS: Int?, weightGrams: Int, load: AvailableLoad? = nil
  ) throws {
    try database.transaction {
      let workout = try readWorkout(id: workoutID)
      guard workout.status == .active,
        let exercise = workout.exercises.first(where: { $0.id == exerciseID }),
        exercise.sets.first(where: { $0.id == original.id }) == original
      else {
        throw TrainingError.invalid(
          "This set or workout has changed. Open the correction again.")
      }
      let valid =
        exercise.definition.tracking == .repetitions
        ? (repetitions ?? 0) > 0 && durationMS == nil : (durationMS ?? 0) > 0 && repetitions == nil
      guard valid, weightGrams >= 0 else {
        throw TrainingError.invalid("Enter a positive result and a valid added weight.")
      }
      let components: [LoadComponent]?
      if weightGrams == original.weightGrams {
        components = original.components
      } else if let load {
        try validateLoad(load, grams: weightGrams)
        components = load.components
      } else {
        components = nil
      }
      try database.execute(
        "UPDATE workout_sets SET repetitions=?,duration_ms=?,weight_grams=?,load_components=? WHERE id=?",
        [
          repetitions.map(SQLValue.integer) ?? .null, durationMS.map(SQLValue.integer) ?? .null,
          .integer(weightGrams), try WeightInventory.encode(components), .text(original.id),
        ])
    }
  }
}
