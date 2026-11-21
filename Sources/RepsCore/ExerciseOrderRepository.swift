import Foundation

extension RepsRepository {
  public func reorderExercises(ids: [String]) throws {
    try database.transaction {
      let current = try readSnapshot().exercises.map(\.id)
      guard ids.count == current.count, Set(ids).count == ids.count,
        Set(ids) == Set(current)
      else {
        throw TrainingError.invalid("The exercise list has changed. Try moving the exercise again.")
      }
      // Free the nonnegative positions before swapping rows with a UNIQUE position.
      // No reader can observe these temporary values outside this transaction.
      try database.execute("UPDATE exercises SET position=-position-1")
      let hidden = try database.query(
        "SELECT id FROM exercises WHERE id IN (SELECT source_id FROM exercise_identity_aliases WHERE source_id!=exercise_id)"
      ).map { try $0.text("id") }
      for (position, id) in (ids + hidden).enumerated() {
        try database.execute(
          "UPDATE exercises SET position=? WHERE id=?", [.integer(position), .text(id)])
      }
    }
  }
}
