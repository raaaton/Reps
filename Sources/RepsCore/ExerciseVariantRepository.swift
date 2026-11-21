import Foundation

extension RepsRepository {
  func readVariants() throws -> [ExerciseVariant] {
    try database.query("SELECT payload FROM exercise_variants ORDER BY rowid").map {
      try JSONDecoder().decode(ExerciseVariant.self, from: Data($0.text("payload").utf8))
    }
  }
  public func saveVariant(_ proposed: ExerciseVariant) throws {
    let variant = try proposed.validated()
    try database.transaction {
      let snapshot = try readSnapshot()
      guard snapshot.exercises.contains(where: { $0.id == variant.exerciseID }),
        !variant.isArchived,
        snapshot.variants.first(where: { $0.id == variant.id }).map({
          $0.exerciseID == variant.exerciseID
        }) ?? true
      else { throw TrainingError.invalid("This exercise or progression is no longer available.") }
      try writeVariant(variant)
      if variant.isBase {
        try database.execute(
          "UPDATE exercises SET tracking=?,minimum_reps=?,maximum_reps=?,duration_seconds=? WHERE id=?",
          [
            .text(variant.tracking.rawValue), variant.minimumReps.map(SQLValue.integer) ?? .null,
            variant.maximumReps.map(SQLValue.integer) ?? .null,
            variant.durationSeconds.map(SQLValue.integer) ?? .null, .text(variant.exerciseID),
          ])
        try GoalReconciliation.update(
          for: variant.applying(to: snapshot.exercises.first { $0.id == variant.exerciseID }!),
          database: database)
      }
      for item in snapshot.variantGoals where item.variantID == variant.id {
        guard
          var target = snapshot.definition(
            exerciseID: variant.exerciseID, variantID: variant.id)
        else { continue }
        target = variant.applying(to: target)
        target.setCount = item.goal.definition.setCount
        try database.execute(
          "UPDATE variant_goals SET payload=? WHERE variant_id=? AND schedule_id=?",
          [
            try ExerciseGoal.encode(item.goal.reconciled(to: target)), .text(variant.id),
            .text(item.scheduleID),
          ])
      }
    }
  }
  func writeVariant(_ variant: ExerciseVariant) throws {
    try database.execute(
      "INSERT INTO exercise_variants VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,exercise_id=excluded.exercise_id",
      [.text(variant.id), .text(variant.exerciseID), try ExerciseVariantSchema.encode(variant)])
  }
  public func archiveVariant(id: String) throws {
    try database.transaction {
      guard var variant = try readVariants().first(where: { $0.id == id }), !variant.isBase else {
        throw TrainingError.invalid("The base progression must remain available.")
      }
      variant.isArchived = true
      try writeVariant(variant)
    }
  }
  func writeWorkoutVariant(
    _ definition: TrainingExercise, occurrenceID: String, locked: Bool = false
  ) throws {
    try database.execute(
      "INSERT INTO workout_variants VALUES(?,?,?,?) ON CONFLICT(exercise_id) DO UPDATE SET variant_id=excluded.variant_id,payload=excluded.payload,locked=MAX(locked,excluded.locked)",
      [
        .text(occurrenceID), .text(definition.variantID),
        try definition.variant.map(ExerciseVariantSchema.encode) ?? .null, .integer(locked ? 1 : 0),
      ])
  }
}

extension TrainingSnapshot {
  public func definition(exerciseID: String, variantID: String? = nil) -> TrainingExercise? {
    let parentID =
      identityAliases.first(where: { $0.sourceID == exerciseID })?.exerciseID ?? exerciseID
    guard var parent = (exercises + archivedExercises).first(where: { $0.id == parentID }) else {
      return nil
    }
    let id =
      variantID ?? identityAliases.first(where: { $0.sourceID == exerciseID })?.variantID
      ?? ExerciseVariant.baseID(for: exerciseID)
    parent.id = exerciseID
    if let variant = variants.first(where: { $0.id == id && $0.exerciseID == parentID }) {
      return variant.applying(to: parent)
    }
    return id == ExerciseVariant.baseID(for: exerciseID) ? parent : nil
  }
}

extension RepsRepository {
  func variantGoal(variantID: String, scheduleID: String?) throws -> ExerciseGoal? {
    try database.query(
      "SELECT payload FROM variant_goals WHERE variant_id=? AND schedule_id=?",
      [.text(variantID), .text(scheduleID ?? "")]
    )
    .first.map { try ExerciseGoal.decode($0.text("payload")) }
  }
  public func selectWorkoutVariant(workoutID: String, exerciseID: String, variantID: String) throws
  {
    try database.transaction {
      let workout = try readWorkout(id: workoutID)
      guard workout.status == .active,
        let exercise = workout.exercises.first(where: { $0.id == exerciseID }),
        exercise.sets.isEmpty, exercise.setStartedAt == nil, exercise.feelingTenths == nil,
        try database.query(
          "SELECT locked FROM workout_variants WHERE exercise_id=?", [.text(exerciseID)]
        ).first?.integer("locked") != 1
      else { throw TrainingError.invalid("The progression is locked after the first set starts.") }
      let snapshot = try readSnapshot()
      guard
        let variant = snapshot.variants.first(where: {
          $0.id == variantID && $0.exerciseID == exercise.definition.parentExerciseID
            && !$0.isArchived
        }),
        var definition = snapshot.definition(
          exerciseID: exercise.definition.id, variantID: variant.id)
      else { throw TrainingError.invalid("Choose an active progression.") }
      definition.setCount = exercise.definition.setCount
      let context = try readGoalContext(
        exerciseID: definition.id, scheduleID: workout.scheduleID, variantID: variant.id)
      try database.execute(
        "UPDATE workout_exercises SET tracking=?,minimum_reps=?,maximum_reps=?,duration_seconds=? WHERE id=?",
        [
          .text(definition.tracking.rawValue),
          definition.minimumReps.map(SQLValue.integer) ?? .null,
          definition.maximumReps.map(SQLValue.integer) ?? .null,
          definition.durationSeconds.map(SQLValue.integer) ?? .null, .text(exerciseID),
        ])
      try writeWorkoutVariant(definition, occurrenceID: exerciseID)
      try database.execute("DELETE FROM workout_goals WHERE exercise_id=?", [.text(exerciseID)])
      if let goal = context.adopted ?? context.suggestion?.goal {
        let resized = goal.resized(to: definition)
        try writeWorkoutGoal(
          ExerciseGoal(
            definition: definition, load: resized.load, repetitions: resized.repetitions,
            durationsMS: resized.durationsMS), exerciseID: exerciseID)
      }
    }
  }
}

extension RepsRepository {
  /// A progression menu changes only this assignment, never sibling settings/goals.
  public func setScheduleVariant(scheduleID: String, exerciseID: String, variantID: String) throws {
    try database.transaction {
      let snapshot = try readSnapshot()
      guard let schedule = snapshot.schedules.first(where: { $0.id == scheduleID }),
        schedule.exerciseIDs.contains(exerciseID),
        let parent = snapshot.definition(exerciseID: exerciseID),
        snapshot.variants.contains(where: {
          $0.id == variantID && $0.exerciseID == parent.parentExerciseID && !$0.isArchived
        })
      else { throw TrainingError.invalid("Choose an available progression for this workout.") }
      try database.execute(
        "INSERT INTO schedule_variants VALUES(?,?,?) ON CONFLICT(schedule_id,exercise_id) DO UPDATE SET variant_id=excluded.variant_id",
        [.text(scheduleID), .text(exerciseID), .text(variantID)])
    }
  }
}

extension ExerciseGoal {
  // Rebind an aliased assignment and resize its sets without masking stale settings.
  func assigned(to exercise: TrainingExercise) -> Self {
    let resized = resized(to: exercise)
    var definition = resized.definition
    if definition.id != exercise.id || definition.parentExerciseID != exercise.parentExerciseID {
      definition.variant = exercise.variant
    }
    definition.id = exercise.id
    return Self(
      definition: definition, load: resized.load,
      repetitions: resized.repetitions, durationsMS: resized.durationsMS)
  }
}

extension TrainingSnapshot {
  /// The original snapshot remains authoritative until another identity is chosen.
  public func historicalDefinition(_ original: TrainingExercise, selecting variantID: String) throws
    -> TrainingExercise
  {
    if variantID == original.variantID { return original }
    let parentID =
      identityAliases.first(where: { $0.sourceID == original.id })?.exerciseID
      ?? original.parentExerciseID
    guard let variant = variants.first(where: { $0.id == variantID && $0.exerciseID == parentID })
    else {
      throw TrainingError.invalid("This progression is no longer available for this exercise.")
    }
    return variant.applying(to: original)
  }

  public func historicalDefinitions(for original: TrainingExercise) -> [TrainingExercise] {
    let parentID =
      identityAliases.first(where: { $0.sourceID == original.id })?.exerciseID
      ?? original.parentExerciseID
    var choices = variants.filter { $0.exerciseID == parentID }.map {
      $0.id == original.variantID ? original : $0.applying(to: original)
    }
    if !choices.contains(where: { $0.variantID == original.variantID }) {
      choices.insert(original, at: 0)
    }
    return choices
  }
}
