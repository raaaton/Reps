extension TrainingExercise {
  static func read(_ row: SQLRow) throws -> Self {
    guard let tracking = TrackingMode(rawValue: try row.text("tracking")) else {
      throw TrainingError.storage
    }
    return Self(
      id: try row.text("id"), name: try row.text("name"), tracking: tracking,
      setCount: try row.integer("set_count"), minimumReps: try row.optionalInteger("minimum_reps"),
      maximumReps: try row.optionalInteger("maximum_reps"),
      durationSeconds: try row.optionalInteger("duration_seconds"),
      isEnabled: try row.integer("enabled") == 1)
  }
}

// Call only inside the caller's transaction. Never touches saved/active workout snapshots.
enum GoalReconciliation {
  static func updateAll(_ database: SQLiteDatabase) throws {
    for row in try database.query("SELECT * FROM exercises") {
      try update(for: TrainingExercise.read(row), database: database)
    }
  }

  static func update(for exercise: TrainingExercise, database: SQLiteDatabase) throws {
    for row in try database.query(
      "SELECT schedule_id,set_count,goal_payload FROM schedule_exercises WHERE exercise_id=? AND goal_payload IS NOT NULL",
      [.text(exercise.id)])
    {
      let goal = try ExerciseGoal.decode(row.text("goal_payload"))
      var target = exercise
      target.setCount = try row.integer("set_count")
      if !goal.isCompatible(with: target) {
        try database.execute(
          "UPDATE schedule_exercises SET goal_payload=? WHERE schedule_id=? AND exercise_id=?",
          [
            try ExerciseGoal.encode(goal.reconciled(to: target)),
            .text(try row.text("schedule_id")), .text(exercise.id),
          ])
      }
    }
    if let row = try database.query(
      "SELECT payload FROM exercise_goals WHERE catalogue_id=?", [.text(exercise.id)]
    ).first {
      let goal = try ExerciseGoal.decode(row.text("payload"))
      if !goal.isCompatible(with: exercise) {
        try database.execute(
          "UPDATE exercise_goals SET payload=? WHERE catalogue_id=?",
          [try ExerciseGoal.encode(goal.reconciled(to: exercise)), .text(exercise.id)])
      }
    }
  }
}

extension TrainingSnapshot {
  // Restore preview and application share the same future-goal normalization.
  func reconcilingGoals() throws -> Self {
    var result = self
    for index in result.schedules.indices {
      for id in result.schedules[index].exerciseIDs {
        guard var target = exercises.first(where: { $0.id == id }),
          let goal = result.schedules[index].goals[id]
        else { continue }
        target.setCount = result.schedules[index].setCounts[id] ?? target.setCount
        if !goal.isCompatible(with: target) {
          result.schedules[index].goals[id] = try goal.reconciled(to: target)
        }
      }
    }
    result.goals = try goals.map { goal in
      guard let target = exercises.first(where: { $0.id == goal.definition.id }),
        !goal.isCompatible(with: target)
      else { return goal }
      return try goal.reconciled(to: target)
    }
    return result
  }

  public func needsGoalReview(for exercise: TrainingExercise, availableLoads _: [AvailableLoad])
    -> Bool
  {
    schedules.contains { schedule in
      guard schedule.exerciseIDs.contains(exercise.id), let goal = schedule.goals[exercise.id]
      else {
        return false
      }
      var target = exercise
      target.setCount = schedule.setCounts[exercise.id] ?? exercise.setCount
      return !goal.isCompatible(with: target)
        || !WeightInventory.isAvailable(
          goal.load, items: weightItems, maximumObjects: maximumWeightObjects)
    }
  }
}
