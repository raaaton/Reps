import Foundation

extension SkillDefinition {
  public func assignment(for stepID: String) throws -> SkillAssignment {
    guard !isArchived, let step = steps.first(where: { $0.id == stepID }) else {
      throw TrainingError.invalid("Choose an available skill and step.")
    }
    return SkillAssignment(
      skillID: id, stepID: step.id,
      configuration: SkillConfiguration(format: step.suggestedFormat))
  }
}

extension SkillProgress {
  public func mainGoalCompleted(in skill: SkillDefinition) -> Bool {
    let main = skill.steps.filter { !$0.isExtension }
    return skillID == skill.id && !main.isEmpty
      && main.allSatisfy { achievements[$0.id] == .consistent }
  }
  public func completed(in skill: SkillDefinition) -> Bool {
    mainGoalCompleted(in: skill) && skill.steps.allSatisfy { achievements[$0.id] == .consistent }
  }
  public func settingCurrent(_ stepID: String, in skill: SkillDefinition) throws -> Self {
    try reconciling(stepID, in: skill, value: nil)
  }
  public func settingAchievement(
    _ value: SkillAchievement, stepID: String,
    in skill: SkillDefinition
  ) throws -> Self {
    guard skillID == skill.id, !skill.isArchived,
      skill.steps.contains(where: { $0.id == stepID })
    else {
      throw TrainingError.invalid("Choose an available skill and step.")
    }
    var copy = self
    copy.achievements[stepID] = value == .unrecorded ? nil : value
    return copy
  }
  private func reconciling(
    _ stepID: String, in skill: SkillDefinition,
    value: SkillAchievement?
  ) throws -> Self {
    guard skillID == skill.id, !skill.isArchived,
      let index = skill.steps.firstIndex(where: { $0.id == stepID })
    else {
      throw TrainingError.invalid("Choose an available skill and step.")
    }
    var copy = self
    copy.currentStepID = stepID
    for (position, step) in skill.steps.enumerated() {
      if position < index {
        copy.achievements[step.id] = .consistent
      } else if position > index, copy.achievements[step.id] == .consistent {
        // Keep evidence of a previous success, without claiming continued consistency.
        copy.achievements[step.id] = .firstSuccess
      }
    }
    if let value {
      copy.achievements[stepID] = value == .unrecorded ? nil : value
    } else if copy.achievements[stepID] == .consistent {
      copy.achievements[stepID] = .firstSuccess
    }
    return copy
  }
}
