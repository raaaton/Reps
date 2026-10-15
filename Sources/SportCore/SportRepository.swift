import Foundation

public actor SportRepository {
  let database: SQLiteDatabase

  public init(path: String) throws {
    let database = try SQLiteDatabase(path: path)
    try TrainingSchema.migrate(database)
    self.database = database
  }

  public func snapshot() throws -> TrainingSnapshot {
    try database.transaction { try readSnapshot() }
  }

  public func saveSchedule(_ proposed: TrainingSchedule, creating: Bool = false) throws {
    try database.transaction {
      let snapshot = try readSnapshot()
      var schedule = proposed
      schedule.name = schedule.name.trimmingCharacters(in: .whitespacesAndNewlines)
      let exists = snapshot.schedules.contains(where: { $0.id == schedule.id })
      guard creating ? !exists : exists else {
        throw TrainingError.invalid(
          creating ? "This workout already exists." : "This workout no longer exists.")
      }
      guard !schedule.id.isEmpty, !schedule.name.isEmpty else {
        throw TrainingError.invalid("Enter a workout name.")
      }
      try TrainingText.validate(name: schedule.name, id: schedule.id)
      guard (1...7).contains(schedule.weekday) else {
        throw TrainingError.invalid("Choose a day of the week.")
      }
      guard
        !snapshot.schedules.contains(where: {
          $0.id != schedule.id && $0.weekday == schedule.weekday
        })
      else {
        throw TrainingError.invalid("This day already has a workout. Choose an available day.")
      }
      if let time = schedule.reminderMinutes, !(0..<1440).contains(time) {
        throw TrainingError.invalid("Choose a valid reminder time.")
      }
      guard Set(schedule.exerciseIDs).count == schedule.exerciseIDs.count else {
        throw TrainingError.invalid("An exercise can appear only once in a workout.")
      }
      guard schedule.exerciseIDs.allSatisfy({ id in snapshot.exercises.contains { $0.id == id } })
      else {
        throw TrainingError.invalid("A selected exercise no longer exists.")
      }
      guard !schedule.isEnabled || !snapshot.exercises(for: schedule).isEmpty else {
        throw TrainingError.invalid(
          "Choose at least one active exercise, or disable this workout.")
      }
      let values: [SQLValue] = [
        .text(schedule.name), .integer(schedule.weekday), .integer(schedule.isEnabled ? 1 : 0),
        schedule.reminderMinutes.map(SQLValue.integer) ?? .null, .text(schedule.id),
      ]
      try database.execute(
        creating
          ? "INSERT INTO schedules(name,weekday,enabled,reminder_minutes,id) VALUES(?,?,?,?,?)"
          : "UPDATE schedules SET name=?,weekday=?,enabled=?,reminder_minutes=? WHERE id=?", values)
      try database.execute(
        "DELETE FROM schedule_exercises WHERE schedule_id=?", [.text(schedule.id)])
      for (position, id) in schedule.exerciseIDs.enumerated() {
        try database.execute(
          "INSERT INTO schedule_exercises VALUES(?,?,?)",
          [.text(schedule.id), .text(id), .integer(position)])
      }
    }
  }

  public func saveExercise(_ proposed: TrainingExercise) throws {
    let exercise = try proposed.validated()
    try database.transaction {
      var snapshot = try readSnapshot()
      if let index = snapshot.exercises.firstIndex(where: { $0.id == exercise.id }) {
        snapshot.exercises[index] = exercise
      } else {
        snapshot.exercises.append(exercise)
      }
      guard
        !snapshot.schedules.contains(where: { $0.isEnabled && snapshot.exercises(for: $0).isEmpty })
      else {
        throw TrainingError.invalid(
          "This is the last exercise in an enabled workout. Edit or disable that workout in Workouts first."
        )
      }
      let values: [SQLValue] = [
        .text(exercise.name), .text(exercise.tracking.rawValue), .integer(exercise.setCount),
        exercise.minimumReps.map(SQLValue.integer) ?? .null,
        exercise.maximumReps.map(SQLValue.integer) ?? .null,
        exercise.durationSeconds.map(SQLValue.integer) ?? .null,
        .integer(exercise.isEnabled ? 1 : 0), .text(exercise.id),
      ]
      if try database.query("SELECT id FROM exercises WHERE id=?", [.text(exercise.id)]).isEmpty {
        try database.execute(
          """
          INSERT INTO exercises(name,tracking,set_count,minimum_reps,maximum_reps,duration_seconds,enabled,id,position)
          VALUES(?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(position),-1)+1 FROM exercises))
          """, values)
      } else {
        try database.execute(
          "UPDATE exercises SET name=?,tracking=?,set_count=?,minimum_reps=?,maximum_reps=?,duration_seconds=?,enabled=? WHERE id=?",
          values)
      }
    }
  }

  public func saveRest(seconds: Int) throws {
    guard seconds > 0 else {
      throw TrainingError.invalid("Choose a positive rest duration.")
    }
    try database.execute("UPDATE preferences SET rest_seconds=? WHERE id=1", [.integer(seconds)])
  }

  public func deleteSchedule(id: String) throws {
    try database.transaction {
      // Foreign keys remove this schedule's assignments, never the exercise catalogue.
      try database.execute("DELETE FROM schedules WHERE id=?", [.text(id)])
    }
  }

  public func deleteExercise(id: String) throws {
    try database.transaction {
      let snapshot = try readSnapshot()
      let emptied = snapshot.schedulesEmptied(removingExerciseID: id)
      try database.execute("DELETE FROM schedule_exercises WHERE exercise_id=?", [.text(id)])
      for schedule in emptied {
        try database.execute("UPDATE schedules SET enabled=0 WHERE id=?", [.text(schedule.id)])
      }
      try database.execute("DELETE FROM exercises WHERE id=?", [.text(id)])
    }
  }

  func readSnapshot() throws -> TrainingSnapshot {
    let exercises = try database.query("SELECT * FROM exercises ORDER BY position").map { row in
      guard let tracking = TrackingMode(rawValue: try row.text("tracking")) else {
        throw TrainingError.storage
      }
      return TrainingExercise(
        id: try row.text("id"), name: try row.text("name"), tracking: tracking,
        setCount: try row.integer("set_count"),
        minimumReps: try row.optionalInteger("minimum_reps"),
        maximumReps: try row.optionalInteger("maximum_reps"),
        durationSeconds: try row.optionalInteger("duration_seconds"),
        isEnabled: try row.integer("enabled") == 1)
    }
    let schedules = try database.query("SELECT * FROM schedules ORDER BY weekday").map { row in
      let id = try row.text("id")
      let exerciseIDs = try database.query(
        "SELECT exercise_id FROM schedule_exercises WHERE schedule_id=? ORDER BY position",
        [.text(id)]
      )
      .map { try $0.text("exercise_id") }
      return TrainingSchedule(
        id: id, name: try row.text("name"), weekday: try row.integer("weekday"),
        isEnabled: try row.integer("enabled") == 1,
        reminderMinutes: try row.optionalInteger("reminder_minutes"), exerciseIDs: exerciseIDs)
    }
    guard let rest = try database.query("SELECT rest_seconds FROM preferences WHERE id=1").first
    else { throw TrainingError.storage }
    return TrainingSnapshot(
      exercises: exercises, schedules: schedules, restSeconds: try rest.integer("rest_seconds"),
      weightItems: try readWeightItems(), goals: try readGoals())
  }
}
