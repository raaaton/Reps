import Foundation

extension SportRepository {
  func readSkills() throws -> [SkillDefinition] {
    try database.query("SELECT payload FROM skill_definitions ORDER BY rowid").map {
      try SkillCoding.decode(SkillDefinition.self, $0.text("payload"))
    }
  }
  func readSkillProgress() throws -> [SkillProgress] {
    try database.query("SELECT payload FROM skill_progress ORDER BY rowid").map {
      try SkillCoding.decode(SkillProgress.self, $0.text("payload"))
    }
  }
  func readScheduleSkills(id: String) throws -> ScheduleSkills {
    guard
      let row = try database.query(
        "SELECT payload FROM schedule_skills WHERE schedule_id=?", [.text(id)]
      ).first
    else { return ScheduleSkills(placement: .beforeForce, blocks: []) }
    return try SkillCoding.decode(ScheduleSkills.self, row.text("payload"))
  }
  func writeScheduleSkills(_ schedule: TrainingSchedule) throws {
    let definitions = try readSkills()
    guard schedule.skills.count <= 1000,
      Set(schedule.skills.map(\.id)).count == schedule.skills.count
    else {
      throw TrainingError.invalid("Choose distinct skill blocks, up to 1000 per workout.")
    }
    for block in schedule.skills {
      try TrainingText.validate(name: block.skillID, id: block.id)
      _ = try block.configuration.validated()
      guard let definition = definitions.first(where: { $0.id == block.skillID && !$0.isArchived }),
        definition.steps.contains(where: { $0.id == block.stepID })
      else { throw TrainingError.invalid("Choose an available skill and step.") }
    }
    try database.execute(
      "INSERT OR REPLACE INTO schedule_skills VALUES(?,?)",
      [
        .text(schedule.id),
        try SkillCoding.encode(
          ScheduleSkills(placement: schedule.skillPlacement, blocks: schedule.skills)),
      ])
  }
  public func saveSkill(_ proposed: SkillDefinition, original: SkillDefinition?) throws {
    let value = try proposed.validated()
    try database.transaction {
      let definitions = try readSkills()
      let previous = definitions.first { $0.id == value.id }
      guard previous == original, previous?.isPreset != true, !value.isPreset,
        !SkillCatalogue.definitions.contains(where: { $0.id == value.id }),
        previous != nil || definitions.count < 1000
      else { throw TrainingError.invalid("This skill has changed. Reopen it before saving.") }
      try database.execute(
        "INSERT INTO skill_definitions VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
        [.text(value.id), try SkillCoding.encode(value)])
      let allowed = Set(value.steps.map(\.id))
      for var schedule in try readSnapshot().schedules {
        let old = schedule.skills
        schedule.skills.removeAll { $0.skillID == value.id && !allowed.contains($0.stepID) }
        if old != schedule.skills { try writeScheduleSkills(schedule) }
      }
      if var progress = try readSkillProgress().first(where: { $0.skillID == value.id }) {
        progress.achievements = progress.achievements.filter { allowed.contains($0.key) }
        if !allowed.contains(progress.currentStepID) { progress.currentStepID = value.steps[0].id }
        if previous?.steps.map(\.id) != value.steps.map(\.id), !value.isArchived {
          progress = try progress.settingAchievement(
            progress.achievements[progress.currentStepID] ?? .unrecorded,
            stepID: progress.currentStepID, in: value)
        }
        try writeSkillProgress(progress)
      }
    }
  }
  public func archiveSkill(id: String) throws {
    try database.transaction {
      guard var value = try readSkills().first(where: { $0.id == id }) else {
        throw TrainingError.invalid("This skill no longer exists.")
      }
      value.isArchived = true
      try database.execute(
        "UPDATE skill_definitions SET payload=? WHERE id=?",
        [try SkillCoding.encode(value), .text(id)])
      for var schedule in try readSnapshot().schedules {
        schedule.skills.removeAll { $0.skillID == id }
        try writeScheduleSkills(schedule)
      }
    }
  }
  func writeSkillProgress(_ value: SkillProgress) throws {
    try database.execute(
      "INSERT OR REPLACE INTO skill_progress VALUES(?,?)",
      [.text(value.skillID), try SkillCoding.encode(value)])
  }
  public func saveSkillProgress(_ proposed: SkillProgress, adoptingIn scheduleIDs: [String]) throws
  {
    try database.transaction {
      let snapshot = try readSnapshot()
      guard
        let definition = snapshot.skills.first(where: {
          $0.id == proposed.skillID && !$0.isArchived
        }),
        definition.steps.contains(where: { $0.id == proposed.currentStepID }),
        proposed.achievements.keys.allSatisfy({ id in definition.steps.contains { $0.id == id } }),
        scheduleIDs.allSatisfy({ id in snapshot.schedules.contains { $0.id == id } })
      else { throw TrainingError.invalid("This skill or workout has changed. Choose it again.") }
      try writeSkillProgress(proposed)
      for var schedule in snapshot.schedules where scheduleIDs.contains(schedule.id) {
        for index in schedule.skills.indices
        where schedule.skills[index].skillID == proposed.skillID {
          schedule.skills[index].stepID = proposed.currentStepID
        }
        try writeScheduleSkills(schedule)
      }
    }
  }
}
