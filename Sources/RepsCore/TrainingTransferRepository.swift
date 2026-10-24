import Foundation

extension RepsRepository {
  private func readTransferData() throws -> TrainingDataSet {
    return TrainingDataSet(
      configuration: try readSnapshot(), notifications: try readNotificationPreferences(),
      workouts: try database.query("SELECT id FROM workouts ORDER BY rowid").map {
        try readWorkout(id: $0.text("id"))
      }, bodyWeights: try bodyWeightMeasurements(),
      skillSessions: try readIndependentSkillSessions())
  }
  public func exportTraining(now: Int) throws -> TrainingArchive {
    try database.transaction {
      let archive = TrainingArchive(createdAt: now, contents: try readTransferData())
      try archive.validate()
      return archive
    }
  }
  public func recoveryArchive() throws -> TrainingArchive? {
    try database.query("SELECT payload FROM import_recovery WHERE id=1").first.map {
      try TrainingArchive.decode(Data($0.text("payload").utf8))
    }
  }
  public func previewCSVImport(_ records: [WorkoutSession], now: Int) throws
    -> TrainingImportPreview
  {
    try database.transaction {
      try requireNoActiveImport()
      try TrainingTransfer.workouts(records, now: now)
      let current = try readTransferData()
      let existing = Dictionary(uniqueKeysWithValues: current.workouts.map { ($0.id, $0) })
      let identical = records.filter { existing[$0.id] == $0 }.count
      let incoming = TrainingDataSet(
        configuration: current.configuration, notifications: current.notifications,
        workouts: records, bodyWeights: current.bodyWeights,
        skillSessions: try detachedSkillsForCSV(current: current, incoming: records))
      _ = try TrainingArchive(createdAt: now, contents: incoming).encoded()
      return TrainingImportPreview(
        isRestoration: false, identicalCount: identical,
        incoming: incoming, expected: current)
    }
  }
  public func previewArchiveImport(_ archive: TrainingArchive, now: Int) throws
    -> TrainingImportPreview
  {
    try database.transaction {
      try requireNoActiveImport()
      try archive.validate()
      _ = try archive.encoded()
      try TrainingTransfer.workouts(archive.contents.workouts, now: now, allowActive: true)
      let current = try readTransferData()
      var incoming = archive.contents
      incoming.configuration = try incoming.configuration.reconcilingGoals()
      if archive.preservesBodyWeight {
        incoming.bodyWeights = current.bodyWeights
        incoming.notifications.weightEnabled = current.notifications.weightEnabled
        incoming.notifications.weightWeekday = current.notifications.weightWeekday
        incoming.notifications.weightMinutes = current.notifications.weightMinutes
      }
      for measurement in incoming.bodyWeights { _ = try measurement.validated(now: now) }
      return TrainingImportPreview(
        isRestoration: true, preservesBodyWeight: archive.preservesBodyWeight, identicalCount: 0,
        incoming: incoming, expected: current)
    }
  }
  public func applyTrainingImport(_ preview: TrainingImportPreview, now: Int) throws {
    try database.transaction {
      try requireNoActiveImport()
      let current = try readTransferData()
      guard current == preview.expected else {
        throw TrainingError.invalid(
          "Data have changed since the preview. Select the file again before importing."
        )
      }
      try TrainingTransfer.validate(preview.incoming)
      try TrainingTransfer.workouts(preview.incoming.workouts, now: now, allowActive: true)
      let final = preview.incoming
      _ = try TrainingArchive(createdAt: now, contents: final).encoded()
      if preview.isUnchanged { return }
      let recovery = TrainingArchive(createdAt: now, contents: current)
      let payload = String(decoding: try recovery.encoded(), as: UTF8.self)
      try database.execute(
        "INSERT INTO import_recovery VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
        [.text(payload)])
      try database.execute("DELETE FROM skill_sessions")
      for table in ["workout_rests", "workouts"] {
        try database.execute("DELETE FROM \(table)")
      }
      if preview.isRestoration {
        for table in [
          "schedules", "exercises", "weight_items", "skill_progress", "skill_definitions",
        ] {
          try database.execute("DELETE FROM \(table)")
        }
        try insertConfiguration(preview.incoming.configuration)
        try writeNotificationPreferences(preview.incoming.notifications)
        try database.execute("DELETE FROM body_weight_measurements")
        for weight in final.bodyWeights {
          try database.execute(
            "INSERT INTO body_weight_measurements VALUES(?,?,?)",
            [.text(weight.id), .text(weight.dayKey), .integer(weight.grams)])
        }
      }
      for workout in preview.incoming.workouts { try insertTransferredWorkout(workout) }
      for practice in final.skillSessions { try writeSkillSession(practice) }
    }
  }
  private func insertConfiguration(_ c: TrainingSnapshot) throws {
    for definition in c.skills {
      try database.execute(
        "INSERT INTO skill_definitions VALUES(?,?)",
        [.text(definition.id), try SkillCoding.encode(definition)])
    }
    for progress in c.skillProgress { try writeSkillProgress(progress) }
    for (position, exercise) in c.exercises.enumerated() {
      try database.execute(
        "INSERT INTO exercises VALUES(?,?,?,?,?,?,?,?,?)",
        [
          .text(exercise.id), .text(exercise.name), .text(exercise.tracking.rawValue),
          .integer(exercise.setCount), exercise.minimumReps.map(SQLValue.integer) ?? .null,
          exercise.maximumReps.map(SQLValue.integer) ?? .null,
          exercise.durationSeconds.map(SQLValue.integer) ?? .null,
          .integer(exercise.isEnabled ? 1 : 0), .integer(position),
        ])
    }
    for schedule in c.schedules {
      try database.execute(
        "INSERT INTO schedules VALUES(?,?,?,?,?)",
        [
          .text(schedule.id), .text(schedule.name), .integer(schedule.weekday),
          .integer(schedule.isEnabled ? 1 : 0),
          schedule.reminderMinutes.map(SQLValue.integer) ?? .null,
        ])
      for (index, id) in schedule.exerciseIDs.enumerated() {
        try database.execute(
          "INSERT INTO schedule_exercises(schedule_id,exercise_id,position,set_count,goal_payload) VALUES(?,?,?,?,?)",
          [
            .text(schedule.id), .text(id), .integer(index), .integer(schedule.setCounts[id] ?? 4),
            try schedule.goals[id].map(ExerciseGoal.encode) ?? .null,
          ])
      }
    }
    for schedule in c.schedules { try writeScheduleSkills(schedule) }
    for item in c.weightItems {
      try database.execute(
        "INSERT INTO weight_items(id,name,grams,enabled,quantity) VALUES(?,?,?,?,?)",
        [
          .text(item.id), .text(item.name), .integer(item.grams), .integer(item.isEnabled ? 1 : 0),
          .integer(item.quantity),
        ])
    }
    for goal in c.goals {
      try database.execute(
        "INSERT INTO exercise_goals VALUES(?,?)",
        [.text(goal.definition.id), try ExerciseGoal.encode(goal)])
    }
    try database.execute(
      "UPDATE preferences SET rest_seconds=?,stretching_enabled=?,maximum_weight_objects=? WHERE id=1",
      [
        .integer(c.restSeconds), .integer(c.stretchingEnabled ? 1 : 0),
        .integer(c.maximumWeightObjects),
      ])
  }
  private func insertTransferredWorkout(_ w: WorkoutSession) throws {
    try database.execute(
      "INSERT INTO workouts VALUES(?,?,?,?,?,?,?,?)",
      [
        .text(w.id), .text(w.scheduleID), .text(w.name), .text(w.dayKey), .integer(w.startedAt),
        w.endedAt.map(SQLValue.integer) ?? .null, .text(w.status.rawValue), .integer(w.restSeconds),
      ])
    if let support = w.support { try writeSupport(support, workoutID: w.id) }
    if let skills = w.skills { try writeWorkoutSkills(skills, id: w.id) }
    for (position, e) in w.exercises.enumerated() {
      let d = e.definition
      try database.execute(
        "INSERT INTO workout_exercises VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [
          .text(e.id), .text(w.id), .text(d.id), .text(d.name), .text(d.tracking.rawValue),
          .integer(d.setCount), d.minimumReps.map(SQLValue.integer) ?? .null,
          d.maximumReps.map(SQLValue.integer) ?? .null,
          d.durationSeconds.map(SQLValue.integer) ?? .null, .integer(position),
          e.feelingTenths.map(SQLValue.integer) ?? .null,
          e.setStartedAt.map(SQLValue.integer) ?? .null,
          e.setWeightGrams.map(SQLValue.integer) ?? .null,
          e.setEndedAt.map(SQLValue.integer) ?? .null, try WeightInventory.encode(e.setComponents),
        ])
      if let goal = e.goal { try writeWorkoutGoal(goal, exerciseID: e.id) }
      for set in e.sets {
        try database.execute(
          "INSERT INTO workout_sets VALUES(?,?,?,?,?,?,?,?)",
          [
            .text(set.id), .text(e.id), .integer(set.number),
            set.repetitions.map(SQLValue.integer) ?? .null,
            set.durationMS.map(SQLValue.integer) ?? .null, .integer(set.weightGrams),
            .integer(set.completedAt), try WeightInventory.encode(set.components),
          ])
      }
    }
    if let rest = w.rest {
      try database.execute(
        "INSERT INTO workout_rests VALUES(?,?,?,?,?,?,?)",
        [
          .text(rest.id), .text(w.id), .text(rest.exerciseID), .integer(rest.afterSet),
          .text(rest.status.rawValue), rest.deadline.map(SQLValue.integer) ?? .null,
          rest.remainingMS.map(SQLValue.integer) ?? .null,
        ])
    }
  }
}
