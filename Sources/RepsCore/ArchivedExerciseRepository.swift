import Foundation

extension RepsRepository {
  public func archiveExercise(id: String) throws {
    try database.transaction {
      let snapshot = try readSnapshot()
      guard let exercise = snapshot.exercises.first(where: { $0.id == id }) else {
        throw TrainingError.invalid("This exercise is no longer in the catalog.")
      }
      guard snapshot.archivedExercises.count < 1000 else {
        throw TrainingError.invalid(
          "The archive is full. Delete an archived exercise before archiving another.")
      }
      try database.execute(
        "INSERT INTO archived_exercises VALUES(?,?)",
        [.text(id), .text(String(decoding: try JSONEncoder().encode(exercise), as: UTF8.self))])
      // Catalogue assignments change; active and historical workout snapshots remain frozen.
      try removeCatalogueExercise(id: id, snapshot: snapshot)
    }
  }

  func readArchivedExercises() throws -> [TrainingExercise] {
    try database.query("SELECT payload FROM archived_exercises ORDER BY rowid").map {
      try JSONDecoder().decode(TrainingExercise.self, from: Data($0.text("payload").utf8))
    }
  }

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
      try database.execute("DELETE FROM archived_exercises WHERE id=?", [.text(id)])
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
