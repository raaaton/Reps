import Foundation

// Shared by completion and the one-time upgrade. Caller owns the SQLite transaction.
enum LatestExerciseGoals {
  static func update(
    _ database: SQLiteDatabase, exerciseIDs: Set<String>? = nil, scheduleIDs: Set<String>? = nil,
    variantIDs: Set<String>? = nil
  ) throws {
    let hasVariants =
      !(try database.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='exercise_variants'")).isEmpty
    let parents = try database.query("SELECT * FROM exercises").map(TrainingExercise.read)
    var targets: [TrainingExercise] = []
    for parent in parents {
      if hasVariants {
        let variants = try database.query(
          "SELECT payload FROM exercise_variants WHERE exercise_id=?", [.text(parent.id)]
        ).map {
          try JSONDecoder().decode(ExerciseVariant.self, from: Data($0.text("payload").utf8))
        }
        targets += variants.map { $0.applying(to: parent) }
      } else {
        targets.append(parent)
      }
    }
    for exercise in targets {
      guard exerciseIDs?.contains(exercise.id) ?? true,
        variantIDs?.contains(exercise.variantID) ?? true,
        let latest = try database.query(
          """
          SELECT e.*,w.schedule_id FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id
          WHERE \(hasVariants ? "(e.catalogue_id=? OR e.catalogue_id IN (SELECT source_id FROM exercise_identity_aliases WHERE exercise_id=?) OR e.id IN (SELECT v.exercise_id FROM workout_variants v JOIN exercise_variants d ON d.id=v.variant_id WHERE d.exercise_id=?))" : "e.catalogue_id=?") AND \(hasVariants ? "COALESCE((SELECT variant_id FROM workout_variants v WHERE v.exercise_id=e.id),e.catalogue_id||':base')=? AND" : "") w.status='completed' AND e.feeling_tenths IS NOT NULL
          ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1
          """,
          hasVariants
            ? [
              .text(exercise.id), .text(exercise.id), .text(exercise.id), .text(exercise.variantID),
            ]
            : [.text(exercise.id)]
        ).first
      else { continue }
      let previous = try WorkoutExercise.read(latest, database: database)
      let loads = try WeightInventory.loads(
        items: database.query("SELECT * FROM weight_items").map {
          WeightItem(
            id: try $0.text("id"), name: try $0.text("name"),
            grams: try $0.integer("grams"), isEnabled: try $0.integer("enabled") == 1,
            quantity: $0.values["quantity"] == nil ? 1 : try $0.integer("quantity"))
        }, maximumObjects: WeightLimitPreference.read(database),
        backpackGrams: WeightLimitPreference.backpackGrams(database))
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
        if hasVariants && exercise.variantID != ExerciseVariant.baseID(for: exercise.id) {
          try database.execute(
            "INSERT INTO variant_goals VALUES(?,?,?) ON CONFLICT(variant_id,schedule_id) DO UPDATE SET payload=excluded.payload",
            [.text(exercise.variantID), .text(scheduleID), try ExerciseGoal.encode(goal)])
          continue
        }
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
