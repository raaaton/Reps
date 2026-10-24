extension WorkoutExercise {
  static func read(_ row: SQLRow, database: SQLiteDatabase) throws -> WorkoutExercise {
    let id = try row.text("id")
    guard let tracking = TrackingMode(rawValue: try row.text("tracking")) else {
      throw TrainingError.storage
    }
    let definition = TrainingExercise(
      id: try row.text("catalogue_id"), name: try row.text("name"), tracking: tracking,
      setCount: try row.integer("set_count"), minimumReps: try row.optionalInteger("minimum_reps"),
      maximumReps: try row.optionalInteger("maximum_reps"),
      durationSeconds: try row.optionalInteger("duration_seconds"), isEnabled: true)
    let sets = try database.query(
      "SELECT * FROM workout_sets WHERE exercise_id=? ORDER BY number", [.text(id)]
    ).map { row in
      WorkoutSet(
        id: try row.text("id"), number: try row.integer("number"),
        repetitions: try row.optionalInteger("repetitions"),
        durationMS: try row.optionalInteger("duration_ms"),
        weightGrams: try row.integer("weight_grams"), completedAt: try row.integer("completed_at"),
        components: try WeightInventory.decode(row.optionalText("load_components")))
    }
    return WorkoutExercise(
      id: id, definition: definition, sets: sets,
      feelingTenths: try row.optionalInteger("feeling_tenths"),
      setStartedAt: try row.optionalInteger("set_started_at"),
      setWeightGrams: try row.optionalInteger("set_weight_grams"),
      setEndedAt: try row.optionalInteger("set_ended_at"),
      setComponents: try WeightInventory.decode(row.optionalText("set_load_components")),
      goal: try database.query("SELECT payload FROM workout_goals WHERE exercise_id=?", [.text(id)])
        .first.map { try ExerciseGoal.decode($0.text("payload")) })
  }

}
