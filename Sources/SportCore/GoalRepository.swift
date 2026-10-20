import Foundation

extension SportRepository {
  // Called inside the same transaction that completes the workout.
  func matchGoalsToCompletedWorkout(id: String) throws {
    let workout = try readWorkout(id: id)
    guard workout.status == .completed else { return }
    try LatestExerciseGoals.update(
      database, exerciseIDs: Set(workout.exercises.map { $0.definition.id }))
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
    setCount: Int? = nil
  ) throws
    -> WorkoutExercise?
  {
    try database.query(
      "SELECT e.* FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE e.catalogue_id=? AND w.status='completed' AND e.feeling_tenths IS NOT NULL AND w.id!=? AND (? IS NULL OR w.schedule_id=? OR w.schedule_id='manual') AND (? IS NULL OR e.set_count=?) ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1",
      [
        .text(exerciseID), .text(excludingWorkoutID), scheduleID.map(SQLValue.text) ?? .null,
        scheduleID.map(SQLValue.text) ?? .null, setCount.map(SQLValue.integer) ?? .null,
        setCount.map(SQLValue.integer) ?? .null,
      ]
    ).first.map(readExercise)
  }
  // Explicit workout context wins. Existing callers for a uniquely assigned exercise remain valid.
  func goalTarget(exerciseID: String, scheduleID: String?, snapshot: TrainingSnapshot) throws -> (
    TrainingExercise, TrainingSchedule?
  ) {
    guard var exercise = snapshot.exercises.first(where: { $0.id == exerciseID }) else {
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
    if let count = schedule?.setCounts[exerciseID] { exercise.setCount = count }
    return (exercise, schedule)
  }

  func readGoalContext(exerciseID: String, scheduleID: String? = nil) throws -> GoalContext {
    let snapshot = try readSnapshot()
    let (exercise, schedule) = try goalTarget(
      exerciseID: exerciseID, scheduleID: scheduleID, snapshot: snapshot)
    let goal =
      schedule.map { $0.goals[exerciseID] }
      ?? snapshot.goals.first { $0.definition.id == exerciseID }
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    let previous = try readLatestPerformance(
      exerciseID: exerciseID)
    return GoalContext(
      exercise: exercise, adopted: goal,
      suggestion: GoalEngine.suggestion(target: exercise, previous: previous, loads: loads),
      isAvailable: goal.map { $0.isCompatible(with: exercise) && loads.contains($0.load) } ?? true,
      scheduleID: schedule?.id)
  }
  public func goalContext(exerciseID: String, scheduleID: String? = nil) throws -> GoalContext {
    try database.transaction { try readGoalContext(exerciseID: exerciseID, scheduleID: scheduleID) }
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
        try goalTarget(exerciseID: originalExercise.id, scheduleID: scheduleID, snapshot: snapshot)
          .0 == originalExercise
      else {
        throw TrainingError.invalid("The exercise has changed. Open its goal again.")
      }
      try database.execute(
        "UPDATE exercises SET duration_seconds=? WHERE id=?",
        [
          goal.definition.durationSeconds.map(SQLValue.integer) ?? .null,
          .text(originalExercise.id),
        ])
      try writeGoal(goal, original: original, scheduleID: scheduleID)
      try GoalReconciliation.updateAll(database)
    }
  }
  public func adoptGoal(
    _ suggestion: GoalSuggestion, original: ExerciseGoal?, scheduleID: String? = nil
  ) throws {
    try database.transaction {
      let context = try readGoalContext(
        exerciseID: suggestion.goal.definition.id, scheduleID: scheduleID)
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
      let target = snapshot.exercises(for: schedule).first(where: {
        $0.id == exercise.definition.id
      }),
      target == exercise.definition
    else { return nil }
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    let rated = WorkoutExercise(
      id: exercise.id, definition: exercise.definition, sets: exercise.sets,
      feelingTenths: feelingTenths, setStartedAt: exercise.setStartedAt,
      setWeightGrams: exercise.setWeightGrams,
      setEndedAt: exercise.setEndedAt, setComponents: exercise.setComponents, goal: exercise.goal)
    let original = schedule.goals[target.id]
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
    let context = try readGoalContext(exerciseID: goal.definition.id, scheduleID: scheduleID)
    guard goal.isCompatible(with: context.exercise), context.adopted == original else {
      throw TrainingError.invalid("The goal or exercise has changed. Open its details again.")
    }
    try validateLoad(goal.load, grams: goal.load.grams)
    try storeGoal(goal, scheduleID: context.scheduleID)
  }

  func storeGoal(_ goal: ExerciseGoal, scheduleID: String?) throws {
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
