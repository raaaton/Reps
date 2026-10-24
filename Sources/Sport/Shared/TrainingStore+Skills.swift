import Foundation
import SportCore

extension TrainingStore {
  func saveSkill(_ skill: SkillDefinition, original: SkillDefinition?) async throws {
    try await commit { try await $0.saveSkill(skill, original: original) }
  }
  func archiveSkill(id: String) async throws {
    try await commit { try await $0.archiveSkill(id: id) }
  }
  func saveSkillProgress(_ progress: SkillProgress, adoptingIn scheduleIDs: [String] = [])
    async throws
  {
    try await commit { try await $0.saveSkillProgress(progress, adoptingIn: scheduleIDs) }
  }
  func startSkillPractice(_ assignment: SkillAssignment) async throws -> String {
    var id = ""
    try await commit {
      id = try await $0.startSkillPractice(assignment: assignment, now: WorkoutClock.now).id
    }
    return id
  }
  func applySkillAction(_ action: SkillAction, practice: SkillPractice) async throws {
    let command = SkillCommand(
      practiceID: practice.id, expectedRevision: practice.revision, action: action)
    try await commit { _ = try await $0.applySkillCommand(command, now: WorkoutClock.now) }
  }
}

extension TrainingStore {
  func resetSkill(id: String) async throws {
    try await commit { try await $0.resetSkill(id: id) }
  }
  func deleteArchivedSkill(id: String) async throws {
    try await commit { try await $0.deleteArchivedSkill(id: id) }
  }
  func deleteSkillPractice(id: String) async throws {
    try await commit { try await $0.deleteSkillPractice(id: id) }
  }
}
