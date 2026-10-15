import Foundation

extension SportRepository {
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
