import Foundation

extension SportRepository {
  // Completion updates the baseline, never adopts a proposed load change.
  func matchGoalsToCompletedWorkout(id: String) throws {
    let workout = try readWorkout(id: id)
    guard workout.status == .completed else { return }
    let snapshot = try readSnapshot()
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    for performance in workout.exercises {
      guard
        try database.query(
          "SELECT exercise_id FROM workout_goal_decisions WHERE exercise_id=?",
          [.text(performance.id)]
        ).isEmpty,
        let target = snapshot.exercises.first(where: { $0.id == performance.definition.id }),
        let goal = GoalEngine.matchingGoal(target: target, previous: performance, loads: loads),
        try readLatestPerformance(exerciseID: target.id)?.id == performance.id
      else { continue }
      try database.execute(
        "INSERT INTO exercise_goals VALUES(?,?) ON CONFLICT(catalogue_id) DO UPDATE SET payload=excluded.payload",
        [.text(target.id), try ExerciseGoal.encode(goal)])
    }
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
  func readLatestPerformance(exerciseID: String, excludingWorkoutID: String = "") throws
    -> WorkoutExercise?
  {
    try database.query(
      "SELECT e.* FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE e.catalogue_id=? AND w.status='completed' AND e.feeling_tenths IS NOT NULL AND w.id!=? ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1",
      [.text(exerciseID), .text(excludingWorkoutID)]
    ).first.map(readExercise)
  }
  func readGoalContext(exerciseID: String) throws -> GoalContext {
    let snapshot = try readSnapshot()
    guard let exercise = snapshot.exercises.first(where: { $0.id == exerciseID }) else {
      throw TrainingError.invalid("This exercise has been deleted.")
    }
    let goal = snapshot.goals.first { $0.definition.id == exerciseID }
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    let previous = try readLatestPerformance(exerciseID: exerciseID)
    return GoalContext(
      exercise: exercise, adopted: goal,
      suggestion: GoalEngine.suggestion(target: exercise, previous: previous, loads: loads),
      isAvailable: goal.map { $0.isCompatible(with: exercise) && loads.contains($0.load) } ?? true)
  }
  public func goalContext(exerciseID: String) throws -> GoalContext {
    try database.transaction { try readGoalContext(exerciseID: exerciseID) }
  }
  public func saveGoal(_ goal: ExerciseGoal, original: ExerciseGoal?) throws {
    try database.transaction { try writeGoal(goal, original: original) }
  }
  public func saveTimedGoal(
    _ goal: ExerciseGoal, original: ExerciseGoal?, originalExercise: TrainingExercise
  ) throws {
    _ = try goal.validated()
    var expected = originalExercise
    expected.durationSeconds = goal.definition.durationSeconds
    guard originalExercise.tracking == .duration, goal.definition == expected else {
      throw TrainingError.invalid("Only the duration can be changed here.")
    }
    try database.transaction {
      let snapshot = try readSnapshot()
      guard snapshot.exercises.first(where: { $0.id == originalExercise.id }) == originalExercise
      else {
        throw TrainingError.invalid("The exercise has changed. Open its goal again.")
      }
      try database.execute(
        "UPDATE exercises SET duration_seconds=? WHERE id=?",
        [
          goal.definition.durationSeconds.map(SQLValue.integer) ?? .null,
          .text(originalExercise.id),
        ])
      try writeGoal(goal, original: original)
    }
  }
  public func adoptGoal(_ suggestion: GoalSuggestion, original: ExerciseGoal?) throws {
    try database.transaction {
      let context = try readGoalContext(exerciseID: suggestion.goal.definition.id)
      guard context.suggestion == suggestion else {
        throw TrainingError.invalid(
          "The latest result has changed. Review the suggestion again.")
      }
      try writeGoal(suggestion.goal, original: original)
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
    guard let target = snapshot.exercises.first(where: { $0.id == exercise.definition.id }) else {
      return nil
    }
    let loads = try WeightInventory.loads(items: snapshot.weightItems)
    let rated = WorkoutExercise(
      id: exercise.id, definition: exercise.definition, sets: exercise.sets,
      feelingTenths: feelingTenths, setStartedAt: exercise.setStartedAt,
      setWeightGrams: exercise.setWeightGrams,
      setEndedAt: exercise.setEndedAt, setComponents: exercise.setComponents, goal: exercise.goal)
    let original = snapshot.goals.first { $0.definition.id == target.id }
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
      guard
        try readExerciseLoadGoalDecision(
          workoutID: decision.workoutID, exerciseID: decision.exerciseID,
          feelingTenths: decision.feelingTenths, now: now) == decision
      else {
        throw TrainingError.invalid("The goal or result has changed. Review the choice again.")
      }
      if update { try writeGoal(decision.suggestion.goal, original: decision.original) }
      try database.execute(
        "INSERT INTO workout_goal_decisions VALUES(?)", [.text(decision.exerciseID)])
      try saveFeelingInTransaction(
        workoutID: decision.workoutID, exerciseID: decision.exerciseID,
        tenths: decision.feelingTenths, now: now)
    }
  }
  private func writeGoal(_ goal: ExerciseGoal, original: ExerciseGoal?) throws {
    _ = try goal.validated()
    let snapshot = try readSnapshot()
    guard let exercise = snapshot.exercises.first(where: { $0.id == goal.definition.id }),
      goal.isCompatible(with: exercise),
      snapshot.goals.first(where: { $0.definition.id == exercise.id }) == original
    else {
      throw TrainingError.invalid("The goal or exercise has changed. Open its details again.")
    }
    try validateLoad(goal.load, grams: goal.load.grams)
    try database.execute(
      "INSERT INTO exercise_goals VALUES(?,?) ON CONFLICT(catalogue_id) DO UPDATE SET payload=excluded.payload",
      [.text(exercise.id), try ExerciseGoal.encode(goal)])
  }
}
