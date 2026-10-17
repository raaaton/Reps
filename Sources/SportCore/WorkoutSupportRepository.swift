import Foundation

extension SportRepository {
  func readSupport(workoutID: String) throws -> WorkoutSupport? {
    guard
      let row = try database.query(
        "SELECT payload FROM workout_support WHERE workout_id=?", [.text(workoutID)]
      ).first
    else { return nil }
    do {
      return try JSONDecoder().decode(WorkoutSupport.self, from: Data(try row.text("payload").utf8))
    } catch { throw TrainingError.storage }
  }
  func writeSupport(_ value: WorkoutSupport, workoutID: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let payload = String(decoding: try encoder.encode(value), as: UTF8.self)
    try database.execute(
      "INSERT OR REPLACE INTO workout_support VALUES(?,?)", [.text(workoutID), .text(payload)])
  }
  public func beginSupport(workoutID: String, stepID: String, now: Int) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      let w = try readWorkout(id: workoutID)
      guard w.status == .active, w.phase(at: now) == .support,
        let current = w.currentSupport, current.id == stepID, var support = w.support
      else { throw TrainingError.invalid("Return to the current warm-up or stretch.") }
      guard current.startedAt == nil else { return }
      guard now >= w.startedAt,
        now >= (support.steps.compactMap(\.completedAt).max() ?? w.startedAt),
        now >= (w.exercises.flatMap(\.sets).map(\.completedAt).max() ?? w.startedAt)
      else { throw TrainingError.invalid("Check the device clock.") }
      let index = support.steps.firstIndex { $0.id == stepID }!
      support.steps[index].startedAt =
        current.tracking == .duration ? try WorkoutClock.adding(3000, to: now) : now
      try writeSupport(support, workoutID: workoutID)
    }
  }
  public func cancelSupportCountdown(
    workoutID: String, stepID: String, expectedStart: Int, now: Int
  ) throws {
    try WorkoutClock.validate(now)
    try database.transaction {
      let w = try readWorkout(id: workoutID)
      guard w.status == .active, let step = w.currentSupport, step.id == stepID,
        step.startedAt == expectedStart, step.countdown(at: now) > 0, var support = w.support
      else { return }
      let index = support.steps.firstIndex { $0.id == stepID }!
      support.steps[index].startedAt = nil
      try writeSupport(support, workoutID: workoutID)
    }
  }
  public func finishSupport(workoutID: String, stepID: String, repetitions: Int? = nil, now: Int)
    throws
  {
    try WorkoutClock.validate(now)
    try database.transaction {
      try finishSupportInTransaction(
        workoutID: workoutID, stepID: stepID, repetitions: repetitions, now: now)
    }
  }
  func finishSupportInTransaction(workoutID: String, stepID: String, repetitions: Int?, now: Int)
    throws
  {
    let w = try readWorkout(id: workoutID)
    // Repeated delivery cannot advance another step or restart its rest.
    if w.support?.steps.first(where: { $0.id == stepID })?.completedAt != nil { return }
    guard w.status == .active, w.phase(at: now) == .support, let step = w.currentSupport,
      step.id == stepID, let start = step.startedAt, now > start, var support = w.support
    else {
      throw TrainingError.invalid("Start the current warm-up or stretch first.")
    }
    let completedAt = min(now, step.automaticDeadline ?? now)
    let index = support.steps.firstIndex { $0.id == stepID }!
    if step.tracking == .repetitions {
      guard let repetitions, (1...10000).contains(repetitions) else {
        throw TrainingError.invalid("Enter a valid repetition count.")
      }
      support.steps[index].repetitions = repetitions
    } else {
      support.steps[index].durationMS = completedAt - start
    }
    support.steps[index].completedAt = completedAt
    if step.restAfterMS > 0 {
      guard let anchor = w.exercises.first else { throw TrainingError.storage }
      let restID = UUID().uuidString
      let deadline = try WorkoutClock.adding(step.restAfterMS, to: completedAt)
      // Negative slots cannot collide with any working-set rest.
      try database.execute(
        "INSERT INTO workout_rests VALUES(?,?,?,?,'running',?,NULL)",
        [
          .text(restID), .text(workoutID), .text(anchor.id), .integer(-step.number),
          .integer(deadline),
        ])
      support.restID = restID
      support.restAnchorID = anchor.id
    }
    try writeSupport(support, workoutID: workoutID)
    if support.steps.allSatisfy({ $0.completedAt != nil }) {
      try database.execute(
        "UPDATE workouts SET status='completed',ended_at=? WHERE id=?",
        [.integer(completedAt), .text(workoutID)])
      try matchGoalsToCompletedWorkout(id: workoutID)
    }
  }
}
