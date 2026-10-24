import Foundation

extension RepsRepository {
  public func startWorkout(
    scheduleID: String, now: Int, calendar: Calendar = .current, restart: Bool = false,
    loadOverrides: [String: AvailableLoad] = [:], includeSupport: Bool = false,
    stretch: StretchMovement? = nil, stretchSeconds: Int = 30
  ) throws -> WorkoutSession {
    try WorkoutClock.validate(now)
    return try database.transaction {
      guard try activeSkillPracticeInTransaction() == nil else {
        throw TrainingError.invalid("Resume or finish the active skill practice first.")
      }
      if let active = try activeWorkoutID() { return try readWorkout(id: active) }
      let snapshot = try readSnapshot()
      guard let schedule = snapshot.schedule(on: WorkoutClock.date(now), calendar: calendar),
        schedule.id == scheduleID
      else {
        throw TrainingError.invalid(
          "This workout is no longer scheduled for today. Check Workouts.")
      }
      let day = WorkoutClock.dayKey(now, calendar: calendar)
      if !restart,
        !(try database.query(
          "SELECT id FROM workouts WHERE schedule_id=? AND day_key=? AND status='completed'",
          [.text(scheduleID), .text(day)])).isEmpty
      {
        throw TrainingError.invalid(
          "This workout is already complete. Use Start Again to record a new one.")
      }
      let (duration, overflow) = snapshot.restSeconds.multipliedReportingOverflow(by: 1000)
      guard !overflow else {
        throw TrainingError.invalid("Reduce the rest duration in Settings.")
      }
      _ = try WorkoutClock.adding(duration, to: now)
      let id = UUID().uuidString
      try database.execute(
        "INSERT INTO workouts VALUES(?,?,?,?,?,NULL,'active',?)",
        [
          .text(id), .text(schedule.id), .text(schedule.name), .text(day), .integer(now),
          .integer(snapshot.restSeconds),
        ])
      let definitions = snapshot.exercises(for: schedule)
      guard loadOverrides.keys.allSatisfy({ id in definitions.contains { $0.id == id } }) else {
        throw TrainingError.invalid("A backpack item has changed.")
      }
      for (position, exercise) in definitions.enumerated() {
        let exerciseID = UUID().uuidString
        try database.execute(
          "INSERT INTO workout_exercises VALUES(?,?,?,?,?,?,?,?,?,?,NULL,NULL,NULL,NULL,NULL)",
          [
            .text(exerciseID), .text(id), .text(exercise.id), .text(exercise.name),
            .text(exercise.tracking.rawValue), .integer(exercise.setCount),
            exercise.minimumReps.sql, exercise.maximumReps.sql, exercise.durationSeconds.sql,
            .integer(position),
          ])
        if var goal = schedule.goals[exercise.id] {
          if let override = loadOverrides[exercise.id] { goal.load = override }
          guard goal.isCompatible(with: exercise) else {
            throw TrainingError.invalid(
              "The goal for \(exercise.name) has changed. Edit it before starting.")
          }
          try validateLoad(goal.load, grams: goal.load.grams)
          try writeWorkoutGoal(goal, exerciseID: exerciseID)
        } else if let override = loadOverrides[exercise.id],
          let initial = GoalEngine.suggestion(
            target: exercise, previous: nil, loads: [.bodyweight])?.goal
        {
          var goal = initial
          goal.load = override
          try validateLoad(override, grams: override.grams)
          try writeWorkoutGoal(goal, exerciseID: exerciseID)
        }
      }
      try freezeWorkoutSkills(schedule: schedule, workoutID: id, now: now)
      if includeSupport {
        let session = try readWorkout(id: id)
        if let first = session.exercises.first {
          try writeSupport(
            WorkoutSupport.make(
              first: first, restSeconds: session.restSeconds,
              stretch: stretch ?? StretchMovement.suggested(firstID: first.definition.id),
              stretchSeconds: stretchSeconds, stretchingEnabled: snapshot.stretchingEnabled),
            workoutID: id)
        }
      }
      return try readWorkout(id: id)
    }
  }

  public func workout(id: String) throws -> WorkoutSession {
    try database.transaction { try readWorkout(id: id) }
  }

  public func restActivitySnapshot(now: Int) throws -> RestActivitySnapshot? {
    try WorkoutClock.validate(now)
    return try database.transaction {
      let workout = try activeWorkoutID().map { try readWorkout(id: $0) }
      return RestActivitySnapshot.current(in: workout, at: now)
    }
  }

  public func workoutOverview(now: Int) throws -> WorkoutOverview {
    try WorkoutClock.validate(now)
    return try database.transaction {
      let expired = try database.query(
        "SELECT id FROM workout_rests WHERE status='running' AND deadline<=?", [.integer(now)]
      ).map { try $0.text("id") }
      for id in expired {
        try database.execute(
          "UPDATE workout_rests SET status='finished',deadline=NULL,remaining_ms=NULL WHERE id=?",
          [.text(id)])
      }
      var expiredStretchIDs: [String] = []
      if let id = try activeWorkoutID() {
        let workout = try readWorkout(id: id)
        if let step = workout.currentSupport, let deadline = step.automaticDeadline,
          deadline <= now
        {
          try finishSupportInTransaction(
            workoutID: id, stepID: step.id, repetitions: nil, now: deadline)
          expiredStretchIDs.append(step.id)
        }
      }
      let active = try activeWorkoutID().map { try readWorkout(id: $0) }
      let history = try database.query(
        """
        SELECT w.*, (SELECT count(*) FROM workout_sets s JOIN workout_exercises e ON s.exercise_id=e.id WHERE e.workout_id=w.id) AS recorded_sets
        FROM workouts w WHERE status!='active' ORDER BY day_key DESC, started_at DESC, rowid DESC
        """
      ).map { row in
        guard let status = WorkoutStatus(rawValue: try row.text("status")) else {
          throw TrainingError.storage
        }
        return WorkoutSummary(
          id: try row.text("id"), scheduleID: try row.text("schedule_id"),
          name: try row.text("name"), dayKey: try row.text("day_key"),
          startedAt: try row.integer("started_at"), endedAt: try row.optionalInteger("ended_at"),
          status: status, setCount: try row.integer("recorded_sets"))
      }
      return WorkoutOverview(
        active: active, history: history, expiredRestIDs: expired,
        expiredStretchIDs: expiredStretchIDs)
    }
  }

  public func beginSet(
    workoutID: String, exerciseID: String, number: Int, weightGrams: Int? = nil,
    load: AvailableLoad? = nil, now: Int
  ) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      let workout = try readWorkout(id: workoutID)
      let exercise = try expectedExercise(workout, exerciseID)
      guard number == exercise.sets.count + 1,
        workout.phase(at: now) == .readySet || workout.phase(at: now) == .countdown
          || workout.phase(at: now) == .activeSet
      else { throw staleAction }
      try validateChronology(workout, now: now)
      if exercise.setStartedAt != nil { return }
      if let load { try validateLoad(load, grams: weightGrams ?? load.grams) }
      if let weightGrams, weightGrams < 0 {
        throw TrainingError.invalid("Added weight cannot be negative.")
      }
      let start =
        exercise.definition.tracking == .duration
        ? try WorkoutClock.adding(3000, to: now) : now
      try WorkoutClock.validate(start)
      try database.execute(
        "UPDATE workout_exercises SET set_started_at=?,set_weight_grams=?,set_ended_at=NULL,set_load_components=? WHERE id=?",
        [
          .integer(start),
          exercise.definition.tracking == .duration ? (weightGrams ?? load?.grams).sql : .null,
          try WeightInventory.encode(
            exercise.definition.tracking == .duration ? load?.components : nil),
          .text(exerciseID),
        ])
    }
  }

  public func cancelSetCountdown(
    workoutID: String, exerciseID: String, number: Int, expectedStart: Int, now: Int
  )
    throws
  {
    try WorkoutClock.validate(now)
    try database.transaction {
      let workout = try readWorkout(id: workoutID)
      let exercise = try expectedExercise(workout, exerciseID)
      guard number == exercise.sets.count + 1 else { throw staleAction }
      // A late or repeated Cancel must never reset an already-running series.
      guard workout.phase(at: now) == .countdown, exercise.setStartedAt == expectedStart else {
        return
      }
      try database.execute(
        "UPDATE workout_exercises SET set_started_at=NULL,set_weight_grams=NULL,set_ended_at=NULL,set_load_components=NULL WHERE id=?",
        [.text(exerciseID)])
    }
  }

  public func recordSet(
    workoutID: String, exerciseID: String, number: Int, repetitions: Int?, weightGrams: Int,
    load: AvailableLoad? = nil, now: Int
  ) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      try recordSetInTransaction(
        workoutID: workoutID, exerciseID: exerciseID, number: number,
        repetitions: repetitions, weightGrams: weightGrams, load: load, now: now)
    }
  }

  // New timed sets have their weight captured before Begin. Legacy sets stop first,
  // then wait for weight entry without adding that time to their performance or rest.
  public func finishTimedSet(workoutID: String, exerciseID: String, number: Int, now: Int) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      let workout = try readWorkout(id: workoutID)
      if workout.exercises.first(where: { $0.id == exerciseID })?.sets.contains(where: {
        $0.number == number
      }) == true {
        return
      }
      let exercise = try expectedExercise(workout, exerciseID)
      guard exercise.definition.tracking == .duration, number == exercise.sets.count + 1 else {
        throw staleAction
      }
      if exercise.setEndedAt != nil { return }
      guard workout.phase(at: now) == .activeSet, let start = exercise.setStartedAt else {
        throw staleAction
      }
      guard now > start else { throw invalidClock }
      if let grams = exercise.setWeightGrams {
        try recordSetInTransaction(
          workoutID: workoutID, exerciseID: exerciseID, number: number,
          repetitions: nil, weightGrams: grams, now: now)
      } else {
        try database.execute(
          "UPDATE workout_exercises SET set_ended_at=? WHERE id=?",
          [.integer(now), .text(exerciseID)])
      }
    }
  }

  private func recordSetInTransaction(
    workoutID: String, exerciseID: String, number: Int, repetitions: Int?, weightGrams: Int,
    load: AvailableLoad? = nil, now: Int
  ) throws {
    let workout = try readWorkout(id: workoutID)
    // Repeated delivery of the same completed action must never record the next set.
    if workout.exercises.first(where: { $0.id == exerciseID })?.sets.contains(where: {
      $0.number == number
    }) == true {
      return
    }
    let exercise = try expectedExercise(workout, exerciseID)
    guard workout.phase(at: now) == .activeSet || workout.phase(at: now) == .completedSet,
      number == exercise.sets.count + 1,
      let start = exercise.setStartedAt
    else { throw staleAction }
    let completedAt = exercise.setEndedAt ?? now
    guard now >= completedAt, completedAt > start else { throw invalidClock }
    guard weightGrams >= 0 else {
      throw TrainingError.invalid("Added weight cannot be negative.")
    }
    if exercise.setWeightGrams == nil, let load { try validateLoad(load, grams: weightGrams) }
    let duration: Int?
    let reps: Int?
    if exercise.definition.tracking == .repetitions {
      guard let repetitions, repetitions > 0 else {
        throw TrainingError.invalid("Enter at least one repetition.")
      }
      reps = repetitions
      duration = nil
    } else {
      reps = nil
      duration = completedAt - start
    }
    try database.execute(
      "INSERT INTO workout_sets VALUES(?,?,?,?,?,?,?,?)",
      [
        .text(UUID().uuidString), .text(exerciseID), .integer(number), reps.sql, duration.sql,
        .integer(exercise.setWeightGrams ?? weightGrams), .integer(completedAt),
        try WeightInventory.encode(
          exercise.setWeightGrams != nil ? exercise.setComponents : load?.components),
      ])
    try database.execute(
      "UPDATE workout_exercises SET set_started_at=NULL,set_weight_grams=NULL,set_ended_at=NULL,set_load_components=NULL WHERE id=?",
      [.text(exerciseID)])
    if number < exercise.definition.setCount || workout.exercises.last?.id != exerciseID {
      let (duration, overflow) = workout.restSeconds.multipliedReportingOverflow(by: 1000)
      guard !overflow else { throw TrainingError.invalid("The rest duration is too long.") }
      let deadline = try WorkoutClock.adding(duration, to: completedAt)
      try database.execute(
        "INSERT INTO workout_rests VALUES(?,?,?,?,'running',?,NULL)",
        [
          .text(UUID().uuidString), .text(workoutID), .text(exerciseID), .integer(number),
          .integer(deadline),
        ])
    }
  }

  public func saveFeeling(workoutID: String, exerciseID: String, tenths: Int, now: Int) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      try saveFeelingInTransaction(
        workoutID: workoutID, exerciseID: exerciseID, tenths: tenths, now: now)
    }
  }
  func saveFeelingInTransaction(workoutID: String, exerciseID: String, tenths: Int, now: Int) throws
  {
    let workout = try readWorkout(id: workoutID)
    if workout.exercises.first(where: { $0.id == exerciseID })?.feelingTenths != nil { return }
    let exercise = try expectedExercise(workout, exerciseID)
    guard workout.phase(at: now) == .feeling, (0...100).contains(tenths) else {
      throw TrainingError.invalid("Complete the sets, then choose a Feeling from 0 to 10.")
    }
    guard now >= (exercise.sets.last?.completedAt ?? workout.startedAt) else {
      throw invalidClock
    }
    try validateChronology(workout, now: now)
    try database.execute(
      "UPDATE workout_exercises SET feeling_tenths=? WHERE id=?",
      [.integer(tenths), .text(exerciseID)])
    try markSkillAvailability(workoutID: workoutID, now: now)
    try completeWorkoutIfReady(id: workoutID, now: now)
  }

  public func changeRest(id: String, action: RestAction, expectedTime: Int? = nil, now: Int) throws
  {
    try WorkoutClock.validate(now)
    try database.transaction {
      guard
        let row = try database.query("SELECT * FROM workout_rests WHERE id=?", [.text(id)]).first
      else { return }
      let rest = try readRest(row)
      let workout = try readWorkout(id: row.text("workout_id"))
      guard workout.status == .active, workout.restDestination != nil,
        workout.phase(at: now) == .resting || workout.phase(at: now) == .feeling,
        workout.rest?.id == id
      else {
        return
      }
      if let expectedTime {
        let persistedTime = action == .resume ? rest.remainingMS : rest.deadline
        guard persistedTime == expectedTime else { return }
      }
      switch action {
      case .pause:
        guard rest.status == .running, rest.remaining(at: now) > 0 else { return }
        try database.execute(
          "UPDATE workout_rests SET status='paused',remaining_ms=?,deadline=NULL WHERE id=?",
          [.integer(rest.remaining(at: now)), .text(id)])
      case .resume:
        guard rest.status == .paused, let remaining = rest.remainingMS else { return }
        let deadline = try WorkoutClock.adding(remaining, to: now)
        try database.execute(
          "UPDATE workout_rests SET status='running',remaining_ms=NULL,deadline=? WHERE id=?",
          [.integer(deadline), .text(id)])
      case .skip:
        try database.execute(
          "UPDATE workout_rests SET status='skipped',remaining_ms=NULL,deadline=NULL WHERE id=?",
          [.text(id)])
      }
    }
  }

  public func cancelWorkout(id: String, now: Int) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      let workout = try readWorkout(id: id)
      guard workout.status == .active else { return }
      try validateChronology(workout, now: now)
      try cancelWorkoutSkills(id: id, now: now)
      try database.execute(
        "UPDATE workout_rests SET status='cancelled',deadline=NULL,remaining_ms=NULL WHERE workout_id=? AND status IN ('running','paused')",
        [.text(id)])
      try database.execute(
        "UPDATE workouts SET status='cancelled',ended_at=? WHERE id=?", [.integer(now), .text(id)])
    }
  }

  public func previousPerformance(exerciseID: String, excludingWorkoutID: String) throws
    -> WorkoutExercise?
  {
    try database.transaction {
      guard
        let row = try database.query(
          """
          SELECT e.* FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id
          WHERE e.catalogue_id=? AND w.status='completed' AND e.feeling_tenths IS NOT NULL AND w.id!=?
          ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC LIMIT 1
          """, [.text(exerciseID), .text(excludingWorkoutID)]
        ).first
      else { return nil }
      return try readExercise(row)
    }
  }

  private var staleAction: TrainingError {
    .invalid("The workout has changed. Return to the current set.")
  }
  private var invalidClock: TrainingError {
    .invalid("The device clock moved backward. Check the time settings and try again.")
  }

  func validateChronology(_ workout: WorkoutSession, now: Int) throws {
    // Countdown starts are deliberately in the future, and must remain cancellable.
    // Completed sets and stopped timed sets are actual events, not planned deadlines.
    let lastSet = workout.exercises.flatMap(\.sets).map(\.completedAt).max() ?? workout.startedAt
    let lastStop = workout.exercises.compactMap(\.setEndedAt).max() ?? workout.startedAt
    let lastSupport = workout.support?.steps.compactMap(\.completedAt).max() ?? workout.startedAt
    let lastSkill = workout.skills?.blocks.map(\.lastEventAt).max() ?? workout.startedAt
    guard now >= max(lastSkill, max(lastSupport, max(workout.startedAt, max(lastSet, lastStop))))
    else {
      throw invalidClock
    }
  }

  private func expectedExercise(_ workout: WorkoutSession, _ exerciseID: String) throws
    -> WorkoutExercise
  {
    guard workout.status == .active, workout.currentSkill == nil,
      let exercise = workout.currentExercise,
      exercise.id == exerciseID
    else { throw staleAction }
    return exercise
  }

  private func activeWorkoutID() throws -> String? {
    try database.query("SELECT id FROM workouts WHERE status='active'").first?.text("id")
  }

  func readWorkout(id: String) throws -> WorkoutSession {
    guard let row = try database.query("SELECT * FROM workouts WHERE id=?", [.text(id)]).first,
      let status = WorkoutStatus(rawValue: try row.text("status"))
    else { throw TrainingError.storage }
    let exercises = try database.query(
      "SELECT * FROM workout_exercises WHERE workout_id=? ORDER BY position", [.text(id)]
    ).map(readExercise)
    let rest = try database.query(
      "SELECT * FROM workout_rests WHERE workout_id=? AND status IN ('running','paused')",
      [.text(id)]
    ).first.map(readRest)
    return WorkoutSession(
      id: id, scheduleID: try row.text("schedule_id"), name: try row.text("name"),
      dayKey: try row.text("day_key"), startedAt: try row.integer("started_at"),
      endedAt: try row.optionalInteger("ended_at"), status: status,
      restSeconds: try row.integer("rest_seconds"), exercises: exercises, rest: rest,
      support: try readSupport(workoutID: id), skills: try readWorkoutSkills(id: id))
  }

  func readExercise(_ row: SQLRow) throws -> WorkoutExercise {
    try WorkoutExercise.read(row, database: database)
  }

  private func readRest(_ row: SQLRow) throws -> WorkoutRest {
    guard let status = RestStatus(rawValue: try row.text("status")) else {
      throw TrainingError.storage
    }
    return WorkoutRest(
      id: try row.text("id"), exerciseID: try row.text("exercise_id"),
      afterSet: try row.integer("after_set"), status: status,
      deadline: try row.optionalInteger("deadline"),
      remainingMS: try row.optionalInteger("remaining_ms"))
  }
}

extension Optional where Wrapped == Int {
  fileprivate var sql: SQLValue { self.map(SQLValue.integer) ?? .null }
}
