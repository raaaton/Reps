extension RepsRepository {
  public func deleteArchivedExercise(id: String) throws {
    try database.transaction {
      guard try database.query("SELECT id FROM exercises WHERE id=?", [.text(id)]).isEmpty else {
        throw TrainingError.invalid(
          "This exercise is still in the catalog. Remove it from Exercises first.")
      }
      guard
        try database.query(
          "SELECT e.id FROM workout_exercises e JOIN workouts w ON w.id=e.workout_id WHERE e.catalogue_id=? AND w.status='active'",
          [.text(id)]
        ).isEmpty
      else {
        throw TrainingError.invalid(
          "Finish or cancel the active workout before deleting this archived exercise.")
      }
      let affected = try database.query(
        "SELECT DISTINCT workout_id FROM workout_exercises WHERE catalogue_id=?", [.text(id)]
      )
      .map { try $0.text("workout_id") }
      try database.execute(
        "DELETE FROM workout_rests WHERE exercise_id IN (SELECT id FROM workout_exercises WHERE catalogue_id=?)",
        [.text(id)])
      try database.execute("DELETE FROM workout_exercises WHERE catalogue_id=?", [.text(id)])
      for workoutID in affected {
        let remaining = try database.query(
          "SELECT id FROM workout_exercises WHERE workout_id=? ORDER BY position",
          [.text(workoutID)])
        if remaining.isEmpty {
          try database.execute("DELETE FROM workout_rests WHERE workout_id=?", [.text(workoutID)])
          try database.execute("DELETE FROM workouts WHERE id=?", [.text(workoutID)])
        } else {
          // Move toward earlier vacant positions in order, preserving the UNIQUE constraint.
          for (position, row) in remaining.enumerated() {
            try database.execute(
              "UPDATE workout_exercises SET position=? WHERE id=?",
              [.integer(position), .text(try row.text("id"))])
          }
        }
      }
    }
  }
}
