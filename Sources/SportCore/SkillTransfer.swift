import Foundation

enum SkillTransfer {
  static func validate(_ data: TrainingDataSet, now: Int) throws {
    let c = data.configuration
    guard c.skills.count <= 1000, c.skillProgress.count <= 1000, data.skillSessions.count <= 10000
    else { throw TrainingTransfer.invalid }
    try TrainingTransfer.unique(c.skills.map(\.id))
    try TrainingTransfer.unique(c.skillProgress.map(\.skillID))
    for definition in c.skills { _ = try definition.validated() }
    for progress in c.skillProgress {
      guard let d = c.skills.first(where: { $0.id == progress.skillID }),
        d.steps.contains(where: { $0.id == progress.currentStepID }),
        progress.achievements.keys.allSatisfy({ id in d.steps.contains { $0.id == id } })
      else { throw TrainingTransfer.invalid }
    }
    for schedule in c.schedules {
      guard schedule.skills.count <= 1000 else { throw TrainingTransfer.invalid }
      try TrainingTransfer.unique(schedule.skills.map(\.id))
      for assignment in schedule.skills {
        try TrainingText.validate(name: assignment.skillID, id: assignment.id)
        _ = try assignment.configuration.validated()
        guard let d = c.skills.first(where: { $0.id == assignment.skillID && !$0.isArchived }),
          d.steps.contains(where: { $0.id == assignment.stepID })
        else { throw TrainingTransfer.invalid }
      }
    }
    var all = data.skillSessions
    for workout in data.workouts {
      guard let skills = workout.skills else { continue }
      guard skills.blocks.count <= 1000 else { throw TrainingTransfer.invalid }
      for practice in skills.blocks {
        guard practice.origin.workoutID == workout.id, !practice.origin.isDetached,
          practice.createdAt >= workout.startedAt,
          workout.status == .active || practice.state.isTerminal,
          practice.lastEventAt <= (workout.endedAt ?? now)
        else { throw TrainingTransfer.invalid }
      }
      // Earlier blocks must finish before a later one can start.
      var pending = false
      for practice in skills.blocks {
        if pending, practice.startedAt != nil { throw TrainingTransfer.invalid }
        if !practice.state.isTerminal { pending = true }
      }
      all += skills.blocks
    }
    try TrainingTransfer.unique(all.map(\.id))
    try TrainingTransfer.unique(all.flatMap(\.attempts).map(\.id))
    guard all.count <= 10000, all.flatMap(\.attempts).count <= 100000,
      data.workouts.filter({ $0.status == .active }).count
        + data.skillSessions.filter({ !$0.state.isTerminal }).count <= 1
    else { throw TrainingTransfer.invalid }
    for p in data.skillSessions {
      guard p.origin.workoutID == nil || p.origin.isDetached else { throw TrainingTransfer.invalid }
      if p.origin.isDetached, !p.state.isTerminal { throw TrainingTransfer.invalid }
    }
    for practice in all { try validatePractice(practice, now: now) }
  }
  static func validatePractice(_ p: SkillPractice, now: Int) throws {
    _ = try p.definition.validated()
    _ = try p.configuration.validated()
    try TrainingText.validate(name: p.definition.name, id: p.id)
    try SkillValidation.optionalText(p.note)
    guard p.definition.id == p.assignment.skillID, p.step != nil,
      p.createdAt >= 0, p.lastEventAt >= p.createdAt, p.lastEventAt <= now,
      p.revision >= 0, p.revision < Int.max, p.elapsedBeforeMS >= 0,
      p.elapsedBeforeMS <= p.lastEventAt - p.createdAt,
      p.attempts.count <= p.configuration.attemptCount,
      p.bestHoldMS.map({ (1...86_400_000).contains($0) }) ?? true,
      p.startedAt.map({ $0 >= p.createdAt && $0 <= p.lastEventAt }) ?? true,
      p.segmentStartedAt.map({ $0 >= (p.startedAt ?? p.createdAt) && $0 <= p.lastEventAt }) ?? true,
      p.state.isTerminal
        ? (p.endedAt == p.lastEventAt && p.segmentStartedAt == nil) : p.endedAt == nil
    else { throw TrainingTransfer.invalid }
    if p.state == .preparation {
      guard p.startedAt == nil, p.segmentStartedAt == nil, p.elapsedBeforeMS == 0,
        p.attempts.isEmpty
      else { throw TrainingTransfer.invalid }
    }
    if p.state == .completed, p.startedAt == nil { throw TrainingTransfer.invalid }
    if !p.attempts.isEmpty, p.startedAt == nil { throw TrainingTransfer.invalid }
    if p.state == .preparation || p.state == .ready {
      guard p.attemptStartedAt == nil, p.restDeadline == nil, p.pausedFrom == nil else {
        throw TrainingTransfer.invalid
      }
    }
    if p.state == .practicing {
      guard p.configuration.format == .freePractice, p.startedAt != nil, p.segmentStartedAt != nil
      else { throw TrainingTransfer.invalid }
    }
    if p.state == .paused {
      guard p.segmentStartedAt == nil, [.ready, .practicing, .resting].contains(p.pausedFrom),
        p.restDeadline == nil
      else { throw TrainingTransfer.invalid }
      if p.pausedFrom == .practicing {
        guard p.configuration.format == .freePractice, p.startedAt != nil else {
          throw TrainingTransfer.invalid
        }
      }
      if p.pausedFrom == .resting {
        guard p.configuration.format != .freePractice, p.startedAt != nil,
          p.restRemainingMS != nil, !p.attempts.isEmpty,
          p.attempts.count < p.configuration.attemptCount
        else { throw TrainingTransfer.invalid }
      }
    } else if p.pausedFrom != nil {
      throw TrainingTransfer.invalid
    }
    if p.state == .countdown || p.state == .attempt {
      guard let start = p.attemptStartedAt, let started = p.startedAt,
        let segment = p.segmentStartedAt, start >= started, start >= segment,
        start >= (p.attempts.last?.completedAt ?? p.createdAt),
        p.attempts.count < p.configuration.attemptCount,
        start <= p.lastEventAt + 3000, p.configuration.format != .freePractice,
        p.state == .countdown
          ? p.configuration.format == .timedHolds : p.configuration.format == .repetitions
      else { throw TrainingTransfer.invalid }
    } else if p.attemptStartedAt != nil {
      throw TrainingTransfer.invalid
    }
    if p.state == .resting {
      guard let deadline = p.restDeadline, deadline > p.lastEventAt,
        p.startedAt != nil, p.segmentStartedAt != nil, !p.attempts.isEmpty,
        p.configuration.format != .freePractice, p.attempts.count < p.configuration.attemptCount,
        deadline - p.lastEventAt <= 86_400_000, p.restRemainingMS == nil
      else { throw TrainingTransfer.invalid }
    } else if p.restDeadline != nil {
      throw TrainingTransfer.invalid
    }
    if let remaining = p.restRemainingMS {
      guard p.state == .paused, p.pausedFrom == .resting, (1...86_400_000).contains(remaining)
      else { throw TrainingTransfer.invalid }
    }
    if p.state.isTerminal, p.restRemainingMS != nil || p.attemptStartedAt != nil {
      throw TrainingTransfer.invalid
    }
    var end = p.startedAt ?? p.createdAt
    for (index, attempt) in p.attempts.enumerated() {
      guard attempt.number == index + 1, attempt.startedAt >= end,
        attempt.completedAt > attempt.startedAt, attempt.completedAt <= p.lastEventAt
      else { throw TrainingTransfer.invalid }
      if p.configuration.format == .timedHolds {
        guard attempt.repetitions == nil,
          attempt.durationMS == attempt.completedAt - attempt.startedAt
        else { throw TrainingTransfer.invalid }
      } else {
        guard p.configuration.format == .repetitions, attempt.durationMS == nil,
          (1...10000).contains(attempt.repetitions ?? 0)
        else { throw TrainingTransfer.invalid }
      }
      end = attempt.completedAt
    }
    if p.configuration.format == .freePractice, !p.attempts.isEmpty {
      throw TrainingTransfer.invalid
    }
  }

  static func checkShape(definition raw: Any) throws {
    let d = try object(
      raw, ["id", "name", "summary", "preparation", "steps", "isPreset", "isArchived"])
    for step in try array(d["steps"]) {
      _ = try object(
        step,
        [
          "id", "name", "instructions", "cues", "suggestedPractice", "equipment", "sourceURL",
          "isExtension", "suggestedFormat",
        ])
    }
  }
  static func checkShape(progress raw: Any) throws {
    _ = try object(raw, ["skillID", "currentStepID", "achievements"])
  }
  static func checkShape(assignment raw: Any) throws {
    let a = try object(raw, ["id", "skillID", "stepID", "configuration"])
    _ = try object(
      a["configuration"] ?? NSNull(),
      [
        "format", "referenceSeconds", "attemptCount", "restSeconds", "targetSeconds",
        "targetRepetitions", "assistance",
      ])
  }
  static func checkShape(practice raw: Any) throws {
    let p = try object(
      raw,
      [
        "id", "definition", "assignment", "origin", "state", "revision", "lastCommandID",
        "createdAt", "lastEventAt", "startedAt", "endedAt", "elapsedBeforeMS", "segmentStartedAt",
        "attemptStartedAt", "restDeadline", "restRemainingMS", "pausedFrom", "attempts", "note",
        "bestHoldMS",
      ])
    try checkShape(definition: p["definition"] ?? NSNull())
    try checkShape(assignment: p["assignment"] ?? NSNull())
    _ = try object(
      p["origin"] ?? NSNull(), ["workoutID", "workoutName", "workoutDay", "isDetached"])
    for a in try array(p["attempts"]) {
      _ = try object(a, ["id", "number", "startedAt", "completedAt", "durationMS", "repetitions"])
    }
  }
  static func checkShape(workout raw: Any) throws {
    let value = try object(raw, ["placement", "blocks"])
    for p in try array(value["blocks"]) { try checkShape(practice: p) }
  }
  static func object(_ raw: Any, _ allowed: [String]) throws -> [String: Any] {
    guard let value = raw as? [String: Any], Set(value.keys).isSubset(of: Set(allowed)) else {
      throw TrainingTransfer.invalid
    }
    return value
  }
  static func array(_ raw: Any?) throws -> [Any] {
    guard let values = raw as? [Any] else { throw TrainingTransfer.invalid }
    return values
  }
}

extension SportRepository {
  func readIndependentSkillSessions() throws -> [SkillPractice] {
    try database.query("SELECT payload FROM skill_sessions ORDER BY rowid").map {
      try SkillCoding.decode(SkillPractice.self, $0.text("payload"))
    }
  }
  func requireNoActiveImport() throws {
    guard try database.query("SELECT id FROM workouts WHERE status='active'").isEmpty,
      try activeSkillPracticeInTransaction() == nil
    else {
      throw TrainingError.invalid(
        "Finish or cancel the active workout or practice before importing. Recorded results will be kept."
      )
    }
  }
  func detachedSkillsForCSV(current: TrainingDataSet, incoming: [WorkoutSession]) throws
    -> [SkillPractice]
  {
    let incomingIDs = Set(incoming.flatMap { $0.skills?.blocks.map(\.id) ?? [] })
    var values = current.skillSessions
    let known = Set(values.map(\.id))
    for workout in current.workouts {
      for var practice in workout.skills?.blocks ?? []
      where !known.contains(practice.id) && !incomingIDs.contains(practice.id) {
        practice.origin.isDetached = true
        values.append(practice)
      }
    }
    return values
  }
}
