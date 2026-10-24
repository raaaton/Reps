import Foundation

extension RepsRepository {
  public func resetSkill(id: String) throws {
    try database.transaction {
      guard let skill = try readSkills().first(where: { $0.id == id }) else {
        throw TrainingError.invalid("This skill no longer exists.")
      }
      try requireNoActivePractice(skillID: id)
      try database.execute("DELETE FROM skill_progress WHERE skill_id=?", [.text(id)])
      for var schedule in try readSnapshot().schedules {
        var changed = false
        for index in schedule.skills.indices where schedule.skills[index].skillID == id {
          schedule.skills[index].stepID = skill.steps[0].id
          changed = true
        }
        if changed { try writeScheduleSkills(schedule) }
      }
    }
  }
  public func deleteArchivedSkill(id: String) throws {
    try database.transaction {
      guard let skill = try readSkills().first(where: { $0.id == id }), skill.isArchived else {
        throw TrainingError.invalid("Archive this skill before deleting it permanently.")
      }
      try requireNoActivePractice(skillID: id)
      for var schedule in try readSnapshot().schedules {
        let before = schedule.skills
        schedule.skills.removeAll { $0.skillID == id }
        if before != schedule.skills { try writeScheduleSkills(schedule) }
      }
      try database.execute("DELETE FROM skill_definitions WHERE id=?", [.text(id)])
    }
  }
  private func requireNoActivePractice(skillID: String) throws {
    if try activeSkillPracticeInTransaction()?.definition.id == skillID {
      throw TrainingError.invalid("Finish or cancel this skill's active practice first.")
    }
    for row in try database.query(
      "SELECT s.payload FROM workout_skills s JOIN workouts w ON w.id=s.workout_id WHERE w.status='active'"
    ) {
      let skills = try SkillCoding.decode(WorkoutSkills.self, row.text("payload"))
      if skills.blocks.contains(where: { $0.definition.id == skillID }) {
        throw TrainingError.invalid("Finish or cancel the workout using this skill first.")
      }
    }
  }
  public func deleteSkillPractice(id: String) throws {
    try database.transaction {
      if let row = try database.query("SELECT payload FROM skill_sessions WHERE id=?", [.text(id)])
        .first
      {
        let p = try SkillCoding.decode(SkillPractice.self, row.text("payload"))
        guard p.state.isTerminal else {
          throw TrainingError.invalid("Finish or cancel this practice first.")
        }
        try database.execute("DELETE FROM skill_sessions WHERE id=?", [.text(id)])
        return
      }
      for row in try database.query(
        "SELECT s.workout_id,s.payload,w.status FROM workout_skills s JOIN workouts w ON w.id=s.workout_id"
      ) {
        var skills = try SkillCoding.decode(WorkoutSkills.self, row.text("payload"))
        guard let p = skills.blocks.first(where: { $0.id == id }) else { continue }
        guard p.state.isTerminal, try row.text("status") != "active" else {
          throw TrainingError.invalid("Finish or cancel the workout before deleting this practice.")
        }
        skills.blocks.removeAll { $0.id == id }
        try writeWorkoutSkills(skills, id: row.text("workout_id"))
        return
      }
      throw TrainingError.invalid("This practice no longer exists.")
    }
  }
}
