import Foundation

public enum WorkoutFeeling {
  public static func tenths(_ input: String) throws -> Int {
    let scaled: Int
    do { scaled = try WorkoutWeight.grams(input) } catch {
      throw TrainingError.invalid("Enter a Feeling from 0 to 10, to one decimal place.")
    }
    guard scaled <= 10_000, scaled % 100 == 0 else {
      throw TrainingError.invalid("Enter a Feeling from 0 to 10, to one decimal place.")
    }
    return scaled / 100
  }
}

public struct ManualWorkout: Sendable {
  public var id: String
  public var name: String
  public var performedAt: Int
  public var exercises: [ManualWorkoutExercise]

  public init(id: String, name: String, performedAt: Int, exercises: [ManualWorkoutExercise]) {
    self.id = id
    self.name = name
    self.performedAt = performedAt
    self.exercises = exercises
  }
}

public struct ManualWorkoutExercise: Sendable {
  public var catalogueID: String
  public var tracking: TrackingMode
  public var sets: [ManualWorkoutSet]
  public var feelingTenths: Int?

  public init(
    catalogueID: String, tracking: TrackingMode, sets: [ManualWorkoutSet], feelingTenths: Int?
  ) {
    self.catalogueID = catalogueID
    self.tracking = tracking
    self.sets = sets
    self.feelingTenths = feelingTenths
  }
}

public struct ManualWorkoutSet: Sendable {
  public var repetitions: Int?
  public var durationMS: Int?
  public var weightGrams: Int
  public var sourceID: String?

  public init(
    repetitions: Int? = nil, durationMS: Int? = nil, weightGrams: Int, sourceID: String? = nil
  ) {
    self.repetitions = repetitions
    self.durationMS = durationMS
    self.weightGrams = weightGrams
    self.sourceID = sourceID
  }
}

extension SportRepository {
  public func addHistoricalWorkout(_ draft: ManualWorkout, now: Int, calendar: Calendar = .current)
    throws
  {
    try WorkoutClock.validate(now)
    try WorkoutClock.validate(draft.performedAt)
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !draft.id.isEmpty, !name.isEmpty else {
      throw TrainingError.invalid("Enter a workout name.")
    }
    try TrainingText.validate(name: name, id: draft.id)
    guard draft.performedAt <= now else {
      throw TrainingError.invalid("Choose today or a past date.")
    }
    try database.transaction {
      // A stable draft ID makes retries after an already committed save harmless.
      if let existing = try database.query(
        "SELECT status,schedule_id FROM workouts WHERE id=?", [.text(draft.id)]
      ).first {
        guard try existing.text("status") == "completed",
          try existing.text("schedule_id") == "manual"
        else {
          throw TrainingError.invalid("This identifier already belongs to another workout.")
        }
        return
      }
      guard !draft.exercises.isEmpty else {
        throw TrainingError.invalid("Add at least one exercise and its sets.")
      }
      guard Set(draft.exercises.map(\.catalogueID)).count == draft.exercises.count else {
        throw TrainingError.invalid("An exercise can appear only once in the workout.")
      }
      let snapshot = try readSnapshot()
      let definitions = try draft.exercises.map { entry in
        guard let definition = snapshot.exercises.first(where: { $0.id == entry.catalogueID }),
          definition.tracking == entry.tracking
        else {
          throw TrainingError.invalid(
            "An exercise was deleted or its tracking mode changed. Check your entry.")
        }
        guard !entry.sets.isEmpty, entry.feelingTenths.map({ (0...100).contains($0) }) == true
        else {
          throw TrainingError.invalid(
            "Add at least one set and a Feeling from 0 to 10 for each exercise.")
        }
        for set in entry.sets {
          let validPerformance =
            entry.tracking == .repetitions
            ? (set.repetitions ?? 0) > 0 && set.durationMS == nil
            : (set.durationMS ?? 0) > 0 && set.repetitions == nil
          guard validPerformance, set.weightGrams >= 0 else {
            throw TrainingError.invalid(
              "Each set needs a positive result and a nonnegative added weight.")
          }
        }
        return definition
      }
      try database.execute(
        "INSERT INTO workouts VALUES(?,'manual',?,?,?,?,'completed',?)",
        [
          .text(draft.id), .text(name),
          .text(WorkoutClock.dayKey(draft.performedAt, calendar: calendar)),
          .integer(draft.performedAt), .integer(draft.performedAt), .integer(snapshot.restSeconds),
        ])
      for (position, entry) in draft.exercises.enumerated() {
        let definition = definitions[position]
        let exerciseID = UUID().uuidString
        try database.execute(
          "INSERT INTO workout_exercises VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL,NULL,NULL,NULL)",
          [
            .text(exerciseID), .text(draft.id), .text(definition.id), .text(definition.name),
            .text(definition.tracking.rawValue), .integer(entry.sets.count),
            definition.minimumReps.map(SQLValue.integer) ?? .null,
            definition.maximumReps.map(SQLValue.integer) ?? .null,
            definition.durationSeconds.map(SQLValue.integer) ?? .null,
            .integer(position), entry.feelingTenths.map(SQLValue.integer) ?? .null,
          ])
        for (index, set) in entry.sets.enumerated() {
          try database.execute(
            "INSERT INTO workout_sets(id,exercise_id,number,repetitions,duration_ms,weight_grams,completed_at) VALUES(?,?,?,?,?,?,?)",
            [
              .text(UUID().uuidString), .text(exerciseID), .integer(index + 1),
              set.repetitions.map(SQLValue.integer) ?? .null,
              set.durationMS.map(SQLValue.integer) ?? .null, .integer(set.weightGrams),
              .integer(draft.performedAt),
            ])
        }
      }
    }
  }

  public func deleteHistoricalWorkout(id: String) throws {
    try database.transaction {
      guard
        let row = try database.query("SELECT status FROM workouts WHERE id=?", [.text(id)]).first
      else { return }
      guard try row.text("status") != "active" else {
        throw TrainingError.invalid(
          "Finish or cancel the active workout before deleting it from history.")
      }
      // Rest rows reference exercises without a cascade; remove them before workout cascades.
      try database.execute("DELETE FROM workout_rests WHERE workout_id=?", [.text(id)])
      try database.execute("DELETE FROM workouts WHERE id=?", [.text(id)])
    }
  }
}
