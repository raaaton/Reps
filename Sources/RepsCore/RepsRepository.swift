import Foundation

public actor RepsRepository {
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
      schedule.setCounts = schedule.setCounts.filter { schedule.exerciseIDs.contains($0.key) }
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
      let old = snapshot.schedules.first { $0.id == schedule.id }
      guard schedule.setCounts.keys.allSatisfy({ schedule.exerciseIDs.contains($0) }),
        schedule.setCounts.values.allSatisfy({ (1...1000).contains($0) })
      else {
        throw TrainingError.invalid("Choose between 1 and 1000 sets for each exercise.")
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
          "INSERT INTO schedule_exercises(schedule_id,exercise_id,position,set_count,goal_payload) VALUES(?,?,?,?,?)",
          [
            .text(schedule.id), .text(id), .integer(position),
            .integer(schedule.setCounts[id] ?? old?.setCounts[id] ?? 4),
            try old?.goals[id].map { goal in
              var definition = goal.definition
              definition.setCount = schedule.setCounts[id] ?? old?.setCounts[id] ?? 4
              return try ExerciseGoal.encode(goal.resized(to: definition))
            } ?? .null,
          ])
      }
      try writeScheduleSkills(schedule)
      let added = Set(schedule.exerciseIDs).subtracting(old?.exerciseIDs ?? [])
      if !added.isEmpty {
        try LatestExerciseGoals.update(database, exerciseIDs: added, scheduleIDs: [schedule.id])
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
      try GoalReconciliation.update(for: exercise, database: database)
    }
  }

  public func saveRest(seconds: Int) throws {
    guard seconds > 0 else {
      throw TrainingError.invalid("Choose a positive rest duration.")
    }
    try database.execute("UPDATE preferences SET rest_seconds=? WHERE id=1", [.integer(seconds)])
  }

  public func saveStretching(enabled: Bool) throws {
    try database.transaction {
      try database.execute(
        "UPDATE preferences SET stretching_enabled=? WHERE id=1", [.integer(enabled ? 1 : 0)])
    }
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
    let exercises = try database.query("SELECT * FROM exercises ORDER BY position").map(
      TrainingExercise.read)
    let schedules = try database.query("SELECT * FROM schedules ORDER BY weekday").map { row in
      let id = try row.text("id")
      let assignments = try database.query(
        "SELECT * FROM schedule_exercises WHERE schedule_id=? ORDER BY position", [.text(id)])
      let exerciseIDs = try assignments.map { try $0.text("exercise_id") }
      let setCounts = try Dictionary(
        uniqueKeysWithValues: assignments.map {
          (try $0.text("exercise_id"), try $0.integer("set_count"))
        })
      var goals: [String: ExerciseGoal] = [:]
      for assignment in assignments {
        if let payload = try assignment.optionalText("goal_payload") {
          goals[try assignment.text("exercise_id")] = try ExerciseGoal.decode(payload)
        }
      }
      let skillBlocks = try readScheduleSkills(id: id)
      return TrainingSchedule(
        id: id, name: try row.text("name"), weekday: try row.integer("weekday"),
        isEnabled: try row.integer("enabled") == 1,
        reminderMinutes: try row.optionalInteger("reminder_minutes"), exerciseIDs: exerciseIDs,
        setCounts: setCounts, goals: goals, skills: skillBlocks.blocks,
        skillPlacement: skillBlocks.placement)
    }
    guard let rest = try database.query("SELECT * FROM preferences WHERE id=1").first
    else { throw TrainingError.storage }
    return TrainingSnapshot(
      exercises: exercises, schedules: schedules, restSeconds: try rest.integer("rest_seconds"),
      weightItems: try readWeightItems(), goals: try readGoals(),
      stretchingEnabled: try rest.integer("stretching_enabled") == 1,
      skills: try readSkills(), skillProgress: try readSkillProgress(),
      maximumWeightObjects: try rest.integer("maximum_weight_objects"))
  }
}
