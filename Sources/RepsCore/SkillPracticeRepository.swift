import Foundation

extension RepsRepository {
  public func startSkillPractice(assignment: SkillAssignment, now: Int) throws -> SkillPractice {
    try WorkoutClock.validate(now)
    return try database.transaction {
      guard try database.query("SELECT id FROM workouts WHERE status='active'").isEmpty,
        try activeSkillPracticeInTransaction() == nil
      else {
        throw TrainingError.invalid("Resume or finish the active workout or practice first.")
      }
      _ = try assignment.configuration.validated()
      guard
        let definition = try readSkills().first(where: {
          $0.id == assignment.skillID && !$0.isArchived
        }),
        definition.steps.contains(where: { $0.id == assignment.stepID })
      else {
        throw TrainingError.invalid("Choose an available skill and step.")
      }
      let value = SkillPractice(definition: definition, assignment: assignment, now: now)
      try writeSkillSession(value)
      return value
    }
  }
  func writeSkillSession(_ value: SkillPractice) throws {
    try database.execute(
      "INSERT INTO skill_sessions VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,payload=excluded.payload",
      [.text(value.id), .text(value.storageStatus), try SkillCoding.encode(value)])
  }
  func activeSkillPracticeInTransaction() throws -> SkillPractice? {
    try database.query("SELECT payload FROM skill_sessions WHERE status='active'").first.map {
      try SkillCoding.decode(SkillPractice.self, $0.text("payload"))
    }
  }
  public func activeSkillPractice() throws -> SkillPractice? {
    try database.transaction { try activeSkillPracticeInTransaction() }
  }
  public func skillPractices(skillID: String? = nil) throws -> [SkillPractice] {
    try database.transaction {
      var values = try database.query("SELECT payload FROM skill_sessions ORDER BY rowid DESC").map
      {
        try SkillCoding.decode(SkillPractice.self, $0.text("payload"))
      }
      for row in try database.query("SELECT payload FROM workout_skills") {
        values += try SkillCoding.decode(WorkoutSkills.self, row.text("payload")).blocks
      }
      return values.filter { skillID == nil || $0.definition.id == skillID }
        .sorted { $0.createdAt > $1.createdAt }
    }
  }
  public func applySkillCommand(_ command: SkillCommand, now: Int) throws -> SkillPractice {
    try database.transaction {
      guard
        let row = try database.query(
          "SELECT payload FROM skill_sessions WHERE id=?", [.text(command.practiceID)]
        ).first
      else {
        return try applyWorkoutSkillCommand(command, now: now)
      }
      let original = try SkillCoding.decode(SkillPractice.self, row.text("payload"))
      let value = try original.applying(command, now: now)
      try writeSkillSession(value)
      return value
    }
  }
}
