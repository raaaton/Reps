import Foundation

extension RepsRepository {
  // Called inside the same transaction that completes the workout.
  func matchGoalsToCompletedWorkout(id: String) throws {
    let workout = try readWorkout(id: id)
    guard workout.status == .completed else { return }
    try LatestExerciseGoals.update(
      database, exerciseIDs: Set(workout.exercises.map { $0.definition.parentExerciseID }),
      variantIDs: Set(workout.exercises.map { $0.definition.variantID }))
  }
  func readGoals() throws -> [ExerciseGoal] {
    try database.query("SELECT payload FROM exercise_goals ORDER BY catalogue_id").map {
      try ExerciseGoal.decode($0.text("payload"))
    }
  }
  func readWorkoutGoal(id: String) throws -> ExerciseGoal? {
    try database.query("SELECT payload FROM workout_goals WHERE exercise_id=?", [.text(id)]).first
      .map { try ExerciseGoal.decode($0.text("payload")) }
  }
  func writeWorkoutGoal(_ goal: ExerciseGoal, exerciseID: String) throws {
    try database.execute(
      "INSERT INTO workout_goals VALUES(?,?)", [.text(exerciseID), try ExerciseGoal.encode(goal)])
  }
  func readLatestPerformance(
    exerciseID: String, excludingWorkoutID: String = "", scheduleID: String? = nil,
    setCount: Int? = nil, variantID: String? = nil
  ) throws
    -> WorkoutExercise?
  {
    try database.query(
      "SELECT e.* FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE (e.catalogue_id=? OR e.catalogue_id IN (SELECT source_id FROM exercise_identity_aliases WHERE exercise_id=?) OR e.id IN (SELECT v.exercise_id FROM workout_variants v JOIN exercise_variants d ON d.id=v.variant_id WHERE d.exercise_id=?)) AND COALESCE((SELECT variant_id FROM workout_variants v WHERE v.exercise_id=e.id),e.catalogue_id||':base')=? AND w.status='completed' AND e.feeling_tenths IS NOT NULL AND w.id!=? AND (? IS NULL OR w.schedule_id=? OR w.schedule_id='manual') AND (? IS NULL OR e.set_count=?) ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1",
      [
        .text(exerciseID), .text(exerciseID), .text(exerciseID),
        .text(variantID ?? ExerciseVariant.baseID(for: exerciseID)),
        .text(excludingWorkoutID), scheduleID.map(SQLValue.text) ?? .null,
        scheduleID.map(SQLValue.text) ?? .null, setCount.map(SQLValue.integer) ?? .null,
        setCount.map(SQLValue.integer) ?? .null,
      ]
    ).first.map(readExercise)
  }
  // Explicit workout context wins. Existing callers for a uniquely assigned exercise remain valid.
  func goalTarget(
    exerciseID: String, scheduleID: String?, snapshot: TrainingSnapshot, variantID: String? = nil
  ) throws -> (
    TrainingExercise, TrainingSchedule?
  ) {
    guard var exercise = snapshot.definition(exerciseID: exerciseID, variantID: variantID) else {
      throw TrainingError.invalid("This exercise has been deleted.")
    }
    let assignments = snapshot.schedules.filter { $0.exerciseIDs.contains(exerciseID) }
    let schedule: TrainingSchedule?
    if let scheduleID {
      guard let match = assignments.first(where: { $0.id == scheduleID }) else {
        throw TrainingError.invalid("This exercise is no longer in this workout.")
      }
      schedule = match
    } else {
      schedule = assignments.count == 1 ? assignments.first : nil
    }
    let selection = variantID ?? schedule?.variantIDs[exerciseID] ?? exercise.variantID
    guard let resolved = snapshot.definition(exerciseID: exerciseID, variantID: selection) else {
      throw TrainingError.invalid("This progression is no longer available.")
    }
    exercise = resolved
    let slotID =
      (exerciseID != exercise.parentExerciseID && schedule?.exerciseIDs.contains(exerciseID) == true
        ? exerciseID : nil)
      ?? schedule?.exerciseIDs.first(where: { slot in
        (schedule?.variantIDs[slot] ?? ExerciseVariant.baseID(for: slot)) == selection
          && snapshot.definition(exerciseID: slot)?.parentExerciseID == exercise.parentExerciseID
      }) ?? exerciseID
    if let count = schedule?.setCounts[slotID] { exercise.setCount = count }
    return (exercise, schedule)
  }

  func readGoalContext(exerciseID: String, scheduleID: String? = nil, variantID: String? = nil)
    throws -> GoalContext
  {
    let snapshot = try readSnapshot()
    let (exercise, schedule) = try goalTarget(
      exerciseID: exerciseID, scheduleID: scheduleID, snapshot: snapshot, variantID: variantID)
    let parentID = exercise.parentExerciseID
    let isBase = exercise.variantID == ExerciseVariant.baseID(for: parentID)
    let storedGoal: ExerciseGoal?
    if isBase {
      let legacy =
        schedule.map { $0.baseGoals[parentID] }
        ?? snapshot.goals.first {
          $0.definition.id == parentID && $0.definition.variantID == exercise.variantID
        }
      storedGoal =
        try legacy ?? variantGoal(variantID: exercise.variantID, scheduleID: schedule?.id)
    } else {
      storedGoal = try variantGoal(variantID: exercise.variantID, scheduleID: schedule?.id)
    }
    let goal =
      (!isBase || exercise.id != parentID) ? storedGoal?.assigned(to: exercise) : storedGoal
    let loads = try WeightInventory.loads(
      items: snapshot.weightItems, maximumObjects: snapshot.maximumWeightObjects,
      backpackGrams: snapshot.backpackWeightGrams)
    let previous = try readLatestPerformance(
      exerciseID: exerciseID, variantID: exercise.variantID)
    return GoalContext(
      exercise: exercise, adopted: goal,
      suggestion: GoalEngine.suggestion(target: exercise, previous: previous, loads: loads),
      isAvailable: goal.map {
        $0.isCompatible(with: exercise)
          && WeightInventory.isAvailable(
            $0.load, items: snapshot.weightItems, maximumObjects: snapshot.maximumWeightObjects,
            backpackGrams: snapshot.backpackWeightGrams)
      } ?? true,
      scheduleID: schedule?.id)
  }
  public func goalContext(exerciseID: String, scheduleID: String? = nil, variantID: String? = nil)
    throws -> GoalContext
  {
    try database.transaction {
      try readGoalContext(exerciseID: exerciseID, scheduleID: scheduleID, variantID: variantID)
    }
  }
  public func saveGoal(_ goal: ExerciseGoal, original: ExerciseGoal?, scheduleID: String? = nil)
    throws
  {
    try database.transaction { try writeGoal(goal, original: original, scheduleID: scheduleID) }
  }
  public func saveTimedGoal(
    _ goal: ExerciseGoal, original: ExerciseGoal?, originalExercise: TrainingExercise,
    scheduleID: String? = nil
  ) throws {
    _ = try goal.validated()
    var expected = originalExercise
    expected.durationSeconds = goal.definition.durationSeconds
    guard originalExercise.tracking == .duration, goal.definition == expected else {
      throw TrainingError.invalid("Only the duration can be changed here.")
    }
    try database.transaction {
      let snapshot = try readSnapshot()
      guard
        try goalTarget(
          exerciseID: originalExercise.id, scheduleID: scheduleID, snapshot: snapshot,
          variantID: originalExercise.variantID
        )
        .0 == originalExercise
      else {
        throw TrainingError.invalid("The exercise has changed. Open its goal again.")
      }
      guard
        try readGoalContext(
          exerciseID: originalExercise.id, scheduleID: scheduleID,
          variantID: originalExercise.variantID
        ).adopted == original
      else {
        throw TrainingError.invalid("The goal has changed. Open its details again.")
      }
      if originalExercise.variant != nil {
        guard var variant = snapshot.variants.first(where: { $0.id == originalExercise.variantID })
        else { throw TrainingError.storage }
        variant.durationSeconds = goal.definition.durationSeconds
        try writeVariant(variant)
      } else {
        try database.execute(
          "UPDATE exercises SET duration_seconds=? WHERE id=?",
          [
            goal.definition.durationSeconds.map(SQLValue.integer) ?? .null,
            .text(originalExercise.id),
          ])
      }
      if originalExercise.variant == nil,
        let parent = try database.query(
          "SELECT * FROM exercises WHERE id=?", [.text(originalExercise.id)]
        ).first
      {
        try writeVariant(ExerciseVariant.base(for: TrainingExercise.read(parent)))
      }
      let refreshedOriginal = try readGoalContext(
        exerciseID: originalExercise.id, scheduleID: scheduleID,
        variantID: originalExercise.variantID
      ).adopted
      try writeGoal(goal, original: refreshedOriginal, scheduleID: scheduleID)
      try GoalReconciliation.updateAll(database)
    }
  }
  public func adoptGoal(
    _ suggestion: GoalSuggestion, original: ExerciseGoal?, scheduleID: String? = nil
  ) throws {
    try database.transaction {
      let context = try readGoalContext(
        exerciseID: suggestion.goal.definition.id, scheduleID: scheduleID,
        variantID: suggestion.goal.definition.variantID)
      guard context.suggestion == suggestion else {
        throw TrainingError.invalid(
          "The latest result has changed. Review the suggestion again.")
      }
      try writeGoal(suggestion.goal, original: original, scheduleID: scheduleID)
    }
  }
  public func exerciseLoadGoalDecision(
    workoutID: String, exerciseID: String, feelingTenths: Int, now: Int
  ) throws -> ExerciseLoadGoalDecision? {
    try WorkoutClock.validate(now)
    return try database.transaction {
      try readExerciseLoadGoalDecision(
        workoutID: workoutID, exerciseID: exerciseID, feelingTenths: feelingTenths, now: now)
    }
  }
  private func readExerciseLoadGoalDecision(
    workoutID: String, exerciseID: String, feelingTenths: Int, now: Int
  ) throws -> ExerciseLoadGoalDecision? {
    let workout = try readWorkout(id: workoutID)
    guard let exercise = workout.currentExercise, exercise.id == exerciseID else {
      throw TrainingError.invalid("This exercise is no longer current.")
    }
    guard workout.status == .active, workout.phase(at: now) == .feeling,
      exercise.feelingTenths == nil, (0...100).contains(feelingTenths)
    else {
      throw TrainingError.invalid("This exercise is no longer waiting for Feeling.")
    }
    let snapshot = try readSnapshot()
    guard let schedule = snapshot.schedules.first(where: { $0.id == workout.scheduleID }),
      schedule.exerciseIDs.contains(exercise.definition.id),
      var target = snapshot.definition(
        exerciseID: exercise.definition.id, variantID: exercise.definition.variantID)
    else { return nil }
    target.setCount = schedule.setCounts[exercise.definition.id] ?? target.setCount
    guard target == exercise.definition else { return nil }
    let loads = try WeightInventory.loads(
      items: snapshot.weightItems, maximumObjects: snapshot.maximumWeightObjects,
      backpackGrams: snapshot.backpackWeightGrams)
    let rated = WorkoutExercise(
      id: exercise.id, definition: exercise.definition, sets: exercise.sets,
      feelingTenths: feelingTenths, setStartedAt: exercise.setStartedAt,
      setWeightGrams: exercise.setWeightGrams,
      setEndedAt: exercise.setEndedAt, setComponents: exercise.setComponents, goal: exercise.goal)
    let original = try readGoalContext(
      exerciseID: target.id, scheduleID: schedule.id, variantID: target.variantID
    ).adopted
    guard let suggestion = GoalEngine.suggestion(target: target, previous: rated, loads: loads),
      suggestion.reason == .increaseLoad || suggestion.reason == .decreaseLoad,
      suggestion.goal != original
    else { return nil }
    return ExerciseLoadGoalDecision(
      workoutID: workoutID, exerciseID: exerciseID,
      feelingTenths: feelingTenths, original: original, suggestion: suggestion)
  }
  public func resolveExerciseLoadGoal(_ decision: ExerciseLoadGoalDecision, update: Bool, now: Int)
    throws
  {
    try WorkoutClock.validate(now)
    try database.transaction {
      let scheduleID = try readWorkout(id: decision.workoutID).scheduleID
      guard
        try readExerciseLoadGoalDecision(
          workoutID: decision.workoutID, exerciseID: decision.exerciseID,
          feelingTenths: decision.feelingTenths, now: now) == decision
      else {
        throw TrainingError.invalid("The goal or result has changed. Review the choice again.")
      }
      if update {
        try writeGoal(decision.suggestion.goal, original: decision.original, scheduleID: scheduleID)
      }
      try database.execute(
        "INSERT INTO workout_goal_decisions(exercise_id,goal_payload) VALUES(?,?)",
        [
          .text(decision.exerciseID),
          try (update ? decision.suggestion.goal : decision.original).map(ExerciseGoal.encode)
            ?? .null,
        ])
      try saveFeelingInTransaction(
        workoutID: decision.workoutID, exerciseID: decision.exerciseID,
        tenths: decision.feelingTenths, now: now)
    }
  }
  private func writeGoal(_ goal: ExerciseGoal, original: ExerciseGoal?, scheduleID: String? = nil)
    throws
  {
    _ = try goal.validated()
    let context = try readGoalContext(
      exerciseID: goal.definition.id, scheduleID: scheduleID, variantID: goal.definition.variantID)
    guard goal.isCompatible(with: context.exercise), context.adopted == original else {
      throw TrainingError.invalid("The goal or exercise has changed. Open its details again.")
    }
    try validateLoad(goal.load, grams: goal.load.grams)
    try storeGoal(goal, scheduleID: context.scheduleID)
  }

  func storeGoal(_ proposed: ExerciseGoal, scheduleID: String?) throws {
    var definition = proposed.definition
    definition.id = definition.parentExerciseID
    let goal = ExerciseGoal(
      definition: definition, load: proposed.load, repetitions: proposed.repetitions,
      durationsMS: proposed.durationsMS)
    if goal.definition.variantID != ExerciseVariant.baseID(for: goal.definition.id) {
      try database.execute(
        "INSERT INTO variant_goals VALUES(?,?,?) ON CONFLICT(variant_id,schedule_id) DO UPDATE SET payload=excluded.payload",
        [.text(goal.definition.variantID), .text(scheduleID ?? ""), try ExerciseGoal.encode(goal)])
      return
    }
    if let scheduleID {
      try database.execute(
        "UPDATE schedule_exercises SET goal_payload=? WHERE schedule_id=? AND exercise_id=?",
        [try ExerciseGoal.encode(goal), .text(scheduleID), .text(goal.definition.id)])
    } else {
      try database.execute(
        "INSERT INTO exercise_goals VALUES(?,?) ON CONFLICT(catalogue_id) DO UPDATE SET payload=excluded.payload",
        [.text(goal.definition.id), try ExerciseGoal.encode(goal)])
    }
  }
}
