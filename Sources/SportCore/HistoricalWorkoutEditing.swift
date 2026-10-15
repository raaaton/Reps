import Foundation

public struct ExercisePerformance: Identifiable, Equatable, Sendable {
  public var id: String { exercise.id }
  public let workoutID: String
  public let workoutName: String
  public let dayKey: String
  public let status: WorkoutStatus
  public let exercise: WorkoutExercise
  public var restSeconds: Int? = nil
}

extension SportRepository {
  public func historyExercises() throws -> [TrainingExercise] {
    try database.transaction {
      let rows = try database.query(
        "SELECT e.* FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE w.status!='active' ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC,e.position"
      )
      var seen = Set<String>()
      return try rows.compactMap { row in
        let id = try row.text("catalogue_id")
        guard seen.insert(id).inserted else { return nil }
        return try readExercise(row).definition
      }
    }
  }
  public func exerciseHistory(exerciseID: String) throws -> [ExercisePerformance] {
    try database.transaction {
      try database.query(
        "SELECT e.*,w.id AS session_id,w.name AS session_name,w.day_key,w.status,w.schedule_id,w.rest_seconds FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE e.catalogue_id=? AND w.status!='active' ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC",
        [.text(exerciseID)]
      ).map { row in
        guard let status = WorkoutStatus(rawValue: try row.text("status")) else {
          throw TrainingError.storage
        }
        return ExercisePerformance(
          workoutID: try row.text("session_id"), workoutName: try row.text("session_name"),
          dayKey: try row.text("day_key"), status: status, exercise: try readExercise(row),
          restSeconds: try row.text("schedule_id") == "manual" ? nil : row.integer("rest_seconds"))
      }
    }
  }

  public func updateHistoricalWorkout(
    _ draft: ManualWorkout, original: WorkoutSession, now: Int, calendar: Calendar = .current
  ) throws {
    try WorkoutClock.validate(now)
    try WorkoutClock.validate(draft.performedAt)
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard draft.id == original.id, !name.isEmpty, draft.performedAt <= now,
      !draft.exercises.isEmpty,
      Set(draft.exercises.map(\.catalogueID)).count == draft.exercises.count
    else {
      throw TrainingError.invalid("Check the workout name, past date and exercises.")
    }
    try TrainingText.validate(name: name, id: draft.id)
    try database.transaction {
      let stored = try readWorkout(id: draft.id)
      guard stored.status != .active, stored == original else {
        throw TrainingError.invalid(
          "This workout has changed. Close the editor and open it again.")
      }
      let snapshot = try readSnapshot()
      let definitions = try draft.exercises.map { entry -> TrainingExercise in
        let definition =
          stored.exercises.first { $0.definition.id == entry.catalogueID }?.definition
          ?? snapshot.exercises.first { $0.id == entry.catalogueID }
        guard let definition, definition.tracking == entry.tracking else {
          throw TrainingError.invalid(
            "A selected exercise is no longer available or its tracking mode changed.")
        }
        guard entry.feelingTenths.map({ (0...100).contains($0) }) ?? (stored.status == .cancelled),
          !entry.sets.isEmpty || stored.status == .cancelled
        else {
          throw TrainingError.invalid(
            "Enter the sets and Feeling for each completed exercise.")
        }
        var sourceIDs = Set<String>()
        for set in entry.sets {
          let valid =
            entry.tracking == .repetitions
            ? (set.repetitions ?? 0) > 0 && set.durationMS == nil
            : (set.durationMS ?? 0) > 0 && set.repetitions == nil
          guard valid, set.weightGrams >= 0 else {
            throw TrainingError.invalid("Check each result and its added weight.")
          }
          if let source = set.sourceID {
            guard sourceIDs.insert(source).inserted,
              stored.exercises.first(where: { $0.definition.id == entry.catalogueID })?.sets
                .contains(where: { $0.id == source }) == true
            else {
              throw TrainingError.invalid("A set has changed. Open the editor again.")
            }
          }
        }
        return definition
      }
      // Date is a calendar record. Original timestamps/status/schedule remain forensic facts.
      try database.execute(
        "UPDATE workouts SET name=?,day_key=? WHERE id=?",
        [
          .text(name), .text(WorkoutClock.dayKey(draft.performedAt, calendar: calendar)),
          .text(draft.id),
        ])
      try database.execute("DELETE FROM workout_rests WHERE workout_id=?", [.text(draft.id)])
      try database.execute("DELETE FROM workout_exercises WHERE workout_id=?", [.text(draft.id)])
      for (position, entry) in draft.exercises.enumerated() {
        let definition = definitions[position]
        let prior = stored.exercises.first { $0.definition.id == entry.catalogueID }
        let exerciseID = prior?.id ?? UUID().uuidString
        try database.execute(
          "INSERT INTO workout_exercises VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL,NULL,NULL,NULL)",
          [
            .text(exerciseID), .text(draft.id), .text(definition.id), .text(definition.name),
            .text(definition.tracking.rawValue), .integer(definition.setCount),
            definition.minimumReps.map(SQLValue.integer) ?? .null,
            definition.maximumReps.map(SQLValue.integer) ?? .null,
            definition.durationSeconds.map(SQLValue.integer) ?? .null, .integer(position),
            entry.feelingTenths.map(SQLValue.integer) ?? .null,
          ])
        if let goal = prior?.goal { try writeWorkoutGoal(goal, exerciseID: exerciseID) }
        for (index, set) in entry.sets.enumerated() {
          let previous = prior?.sets.first { $0.id == set.sourceID }
          let components = previous?.weightGrams == set.weightGrams ? previous?.components : nil
          try database.execute(
            "INSERT INTO workout_sets VALUES(?,?,?,?,?,?,?,?)",
            [
              .text(previous?.id ?? UUID().uuidString), .text(exerciseID), .integer(index + 1),
              set.repetitions.map(SQLValue.integer) ?? .null,
              set.durationMS.map(SQLValue.integer) ?? .null, .integer(set.weightGrams),
              .integer(previous?.completedAt ?? draft.performedAt),
              try WeightInventory.encode(components),
            ])
        }
      }
    }
  }
}
