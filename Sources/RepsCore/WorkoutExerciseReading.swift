import Foundation

extension WorkoutExercise {
  static func read(_ row: SQLRow, database: SQLiteDatabase) throws -> WorkoutExercise {
    let id = try row.text("id")
    guard let tracking = TrackingMode(rawValue: try row.text("tracking")) else {
      throw TrainingError.storage
    }
    var definition = TrainingExercise(
      id: try row.text("catalogue_id"), name: try row.text("name"), tracking: tracking,
      setCount: try row.integer("set_count"), minimumReps: try row.optionalInteger("minimum_reps"),
      maximumReps: try row.optionalInteger("maximum_reps"),
      durationSeconds: try row.optionalInteger("duration_seconds"), isEnabled: true)
    let hasVariants =
      !(try database.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='workout_variants'")).isEmpty
    if hasVariants,
      let value = try database.query(
        "SELECT payload FROM workout_variants WHERE exercise_id=?", [.text(id)]
      ).first?.optionalText("payload")
    {
      definition.variant = try JSONDecoder().decode(ExerciseVariant.self, from: Data(value.utf8))
    }
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
    var exercise = WorkoutExercise(
      id: id, definition: definition, sets: sets,
      feelingTenths: try row.optionalInteger("feeling_tenths"),
      setStartedAt: try row.optionalInteger("set_started_at"),
      setWeightGrams: try row.optionalInteger("set_weight_grams"),
      setEndedAt: try row.optionalInteger("set_ended_at"),
      setComponents: try WeightInventory.decode(row.optionalText("set_load_components")),
      goal: try database.query("SELECT payload FROM workout_goals WHERE exercise_id=?", [.text(id)])
        .first.map { try ExerciseGoal.decode($0.text("payload")) })
    if hasVariants, sets.isEmpty, exercise.setStartedAt == nil,
      !(try database.query(
        "SELECT 1 FROM workout_exercises e JOIN workouts w ON w.id=e.workout_id WHERE e.id=? AND w.status='active'",
        [.text(id)])).isEmpty,
      try database.query("SELECT locked FROM workout_variants WHERE exercise_id=?", [.text(id)])
        .first?.integer("locked") == 1
    {
      exercise.variantSelectionLocked = true
    }
    return exercise
  }

}
