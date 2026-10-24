// Shared by completion and the one-time upgrade. Caller owns the SQLite transaction.
enum LatestExerciseGoals {
  static func update(
    _ database: SQLiteDatabase, exerciseIDs: Set<String>? = nil, scheduleIDs: Set<String>? = nil
  ) throws {
    for row in try database.query("SELECT * FROM exercises") {
      let exercise = try TrainingExercise.read(row)
      guard exerciseIDs?.contains(exercise.id) ?? true,
        let latest = try database.query(
          """
          SELECT e.*,w.schedule_id FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id
          WHERE e.catalogue_id=? AND w.status='completed' AND e.feeling_tenths IS NOT NULL
          ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1
          """, [.text(exercise.id)]
        ).first
      else { continue }
      let previous = try WorkoutExercise.read(latest, database: database)
      let loads = try WeightInventory.loads(
        items: database.query("SELECT * FROM weight_items").map {
          WeightItem(
            id: try $0.text("id"), name: try $0.text("name"),
            grams: try $0.integer("grams"), isEnabled: try $0.integer("enabled") == 1,
            quantity: $0.values["quantity"] == nil ? 1 : try $0.integer("quantity"))
        }, maximumObjects: WeightLimitPreference.read(database))
      // Capture the explicit choice once; later goal edits must not rewrite that decision.
      let payload = try database.query(
        "SELECT goal_payload FROM workout_goal_decisions WHERE exercise_id=?",
        [.text(previous.id)]
      ).first?.optionalText("goal_payload")
      let chosen = try payload.map(ExerciseGoal.decode)
      for assignment in try database.query(
        "SELECT schedule_id,set_count FROM schedule_exercises WHERE exercise_id=?",
        [.text(exercise.id)])
      {
        let scheduleID = try assignment.text("schedule_id")
        guard scheduleIDs?.contains(scheduleID) ?? true else { continue }
        var target = exercise
        target.setCount = try assignment.integer("set_count")
        let goal: ExerciseGoal?
        let baseline = GoalEngine.lastSessionGoal(target: target, previous: previous, loads: loads)
        var choiceDefinition = target
        choiceDefinition.setCount = chosen?.definition.setCount ?? target.setCount
        if let chosen, chosen.isCompatible(with: choiceDefinition),
          chosen.load != baseline?.load
        {
          goal = chosen.averaged(to: target)
        } else {
          goal = baseline
        }
        guard let goal else { continue }
        try database.execute(
          "UPDATE schedule_exercises SET goal_payload=? WHERE schedule_id=? AND exercise_id=?",
          [
            try ExerciseGoal.encode(goal), .text(scheduleID),
            .text(exercise.id),
          ])
      }
    }
  }
}
