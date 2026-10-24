import Foundation

public struct WorkoutSkills: Codable, Equatable, Sendable {
  public var placement: SkillPlacement
  public var blocks: [SkillPractice]
  public var isFinished: Bool { blocks.allSatisfy { $0.state.isTerminal } }
}
extension RepsRepository {
  func readWorkoutSkills(id: String) throws -> WorkoutSkills? {
    try database.query("SELECT payload FROM workout_skills WHERE workout_id=?", [.text(id)]).first
      .map {
        try SkillCoding.decode(WorkoutSkills.self, $0.text("payload"))
      }
  }
  func writeWorkoutSkills(_ value: WorkoutSkills, id: String) throws {
    try database.execute(
      "INSERT OR REPLACE INTO workout_skills VALUES(?,?)",
      [.text(id), try SkillCoding.encode(value)])
  }
  func freezeWorkoutSkills(schedule: TrainingSchedule, workoutID: String, now: Int) throws {
    guard !schedule.skills.isEmpty else { return }
    let definitions = try readSkills()
    let blocks = try schedule.skills.map { assignment in
      guard
        let definition = definitions.first(where: { $0.id == assignment.skillID && !$0.isArchived }
        ),
        definition.steps.contains(where: { $0.id == assignment.stepID })
      else {
        throw TrainingError.invalid("A skill has changed. Review the workout before starting.")
      }
      return SkillPractice(
        definition: definition, assignment: assignment,
        origin: SkillOrigin(
          workoutID: workoutID, workoutName: schedule.name, workoutDay: WorkoutClock.dayKey(now)),
        now: now)
    }
    try writeWorkoutSkills(
      WorkoutSkills(placement: schedule.skillPlacement, blocks: blocks), id: workoutID)
  }
  func applyWorkoutSkillCommand(_ command: SkillCommand, now: Int) throws -> SkillPractice {
    // The active row is normally the only candidate. Include historical rows for a repeated final command.
    for row in try database.query(
      "SELECT workout_id,payload FROM workout_skills WHERE instr(payload,?)>0 ORDER BY rowid DESC",
      [.text(command.practiceID)])
    {
      let id = try row.text("workout_id")
      var skills = try SkillCoding.decode(WorkoutSkills.self, row.text("payload"))
      guard let index = skills.blocks.firstIndex(where: { $0.id == command.practiceID }) else {
        continue
      }
      let original = skills.blocks[index]
      if original.lastCommandID == command.commandID { return original }
      let workout = try readWorkout(id: id)
      guard workout.status == .active, workout.currentSkill?.id == original.id else {
        throw TrainingError.invalid("Return to the current skill block.")
      }
      try WorkoutClock.validate(now)
      try validateChronology(workout, now: now)
      let value = try original.applying(command, now: now)
      skills.blocks[index] = value
      try writeWorkoutSkills(skills, id: id)
      try completeWorkoutIfReady(id: id, now: now)
      return value
    }
    throw TrainingError.invalid("This skill practice no longer exists.")
  }
  func markSkillAvailability(workoutID: String, now: Int) throws {
    let workout = try readWorkout(id: workoutID)
    guard workout.status == .active, workout.workFinished, var skills = workout.skills,
      skills.placement == .afterForce,
      let index = skills.blocks.firstIndex(where: { !$0.state.isTerminal }),
      skills.blocks[index].startedAt == nil
    else { return }
    // Persist the time this block became available, including the final Feeling event.
    skills.blocks[index].lastEventAt = max(skills.blocks[index].lastEventAt, now)
    try writeWorkoutSkills(skills, id: workoutID)
  }
  func completeWorkoutIfReady(id: String, now: Int) throws {
    let workout = try readWorkout(id: id)
    guard workout.status == .active, workout.workFinished,
      workout.support?.steps.allSatisfy({ $0.completedAt != nil }) ?? true,
      workout.skills?.isFinished ?? true
    else { return }
    try database.execute(
      "UPDATE workouts SET status='completed',ended_at=? WHERE id=?", [.integer(now), .text(id)])
    try matchGoalsToCompletedWorkout(id: id)
  }
  func cancelWorkoutSkills(id: String, now: Int) throws {
    guard var skills = try readWorkoutSkills(id: id) else { return }
    for index in skills.blocks.indices where !skills.blocks[index].state.isTerminal {
      let p = skills.blocks[index]
      skills.blocks[index] = try p.applying(
        SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .cancel), now: now)
    }
    try writeWorkoutSkills(skills, id: id)
  }
}
