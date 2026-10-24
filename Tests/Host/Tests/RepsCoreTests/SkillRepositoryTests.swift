import Foundation
import XCTest

@testable import RepsCore

final class SkillRepositoryTests: XCTestCase {
  func testCataloguePersistsAndIsUnique() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let initial = try await r.snapshot()
    XCTAssertEqual(initial.skills.count, 4)
    XCTAssertEqual(Set(initial.skills.map(\.id)).count, 4)
    XCTAssertTrue(initial.skills.allSatisfy { !$0.steps.isEmpty })
    try await r.archiveSkill(id: "handstand")
    let reopened = try RepsRepository(path: path)
    let saved = try await reopened.snapshot()
    XCTAssertEqual(saved.skills.count, 4)
    XCTAssertTrue(try XCTUnwrap(saved.skills.first { $0.id == "handstand" }).isArchived)
  }

  func testPersonalSkillValidationAndDuplication() async throws {
    let r = try RepsRepository(path: ":memory:")
    let skill = SkillDefinition(name: "My balance", steps: [SkillStep(name: "Start")])
    try await r.saveSkill(skill, original: nil)
    let copy = skill.duplicated()
    XCTAssertNotEqual(copy.id, skill.id)
    XCTAssertNotEqual(copy.steps.first?.id, skill.steps.first?.id)
    try await r.saveSkill(copy, original: nil)
    var invalid = skill
    invalid.steps = []
    do {
      try await r.saveSkill(invalid, original: skill)
      XCTFail("Empty roadmap accepted")
    } catch {}
    invalid = skill
    invalid.steps[0].sourceURL = "file:///private/file"
    do {
      try await r.saveSkill(invalid, original: skill)
      XCTFail("Unsafe link accepted")
    } catch {}
    let snapshot = try await r.snapshot()
    XCTAssertEqual(snapshot.skills.count, 6)
  }

  func testAssignmentsKeepIndependentVolumesAndExplicitAdoption() async throws {
    let r = try RepsRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    let skill = try XCTUnwrap(snapshot.skills.first { $0.id == "handstand" })
    var first = snapshot.schedules[0]
    var second = snapshot.schedules[1]
    first.skills = [SkillAssignment(skillID: skill.id, stepID: skill.steps[0].id)]
    second.skills = [SkillAssignment(skillID: skill.id, stepID: skill.steps[0].id)]
    first.skills[0].configuration.attemptCount = 2
    second.skills[0].configuration.attemptCount = 4
    try await r.saveSchedule(first)
    try await r.saveSchedule(second)
    var progress = SkillProgress(skillID: skill.id, currentStepID: skill.steps[1].id)
    progress.achievements[skill.steps[1].id] = .firstSuccess
    try await r.saveSkillProgress(progress, adoptingIn: [first.id])
    let updated = try await r.snapshot()
    let a = try XCTUnwrap(updated.schedules.first { $0.id == first.id })
    let b = try XCTUnwrap(updated.schedules.first { $0.id == second.id })
    XCTAssertEqual(a.skills[0].stepID, skill.steps[1].id)
    XCTAssertEqual(b.skills[0].stepID, skill.steps[0].id)
    XCTAssertEqual(a.skills[0].configuration.attemptCount, 2)
    XCTAssertEqual(b.skills[0].configuration.attemptCount, 4)
    XCTAssertNil(updated.skillProgress.first?.achievements[skill.steps[0].id])
  }

  func testDeletingPersonalStepRemovesAssignmentsAndResetsCurrentStep() async throws {
    let r = try RepsRepository(path: ":memory:")
    let skill = SkillDefinition(
      name: "Custom", steps: [SkillStep(name: "A"), SkillStep(name: "B")])
    try await r.saveSkill(skill, original: nil)
    var schedule = try await r.snapshot().schedules[0]
    schedule.skills = [SkillAssignment(skillID: skill.id, stepID: skill.steps[1].id)]
    try await r.saveSchedule(schedule)
    try await r.saveSkillProgress(
      SkillProgress(skillID: skill.id, currentStepID: skill.steps[1].id), adoptingIn: [])
    var edited = skill
    edited.steps.removeLast()
    try await r.saveSkill(edited, original: skill)
    let saved = try await r.snapshot()
    XCTAssertTrue(try XCTUnwrap(saved.schedules.first { $0.id == schedule.id }).skills.isEmpty)
    XCTAssertEqual(saved.skillProgress.first?.currentStepID, edited.steps[0].id)
  }
}

extension SkillRepositoryTests {
  func testRealSchema16UpgradePreservesActiveWorkoutAndSettings() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await r.saveStretching(enabled: false)
    try await r.saveRest(seconds: 137)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let workout = try await r.startWorkout(
      scheduleID: "pull-abs", now: 1_791_720_000_000, calendar: calendar)
    let before = try await r.snapshot()
    let db = try SQLiteDatabase(path: path)
    for table in [
      "skill_progress", "schedule_skills", "workout_skills", "skill_sessions", "skill_definitions",
    ] {
      try db.execute("DROP TABLE \(table)")
    }
    try db.execute("PRAGMA user_version=16")
    let upgraded = try RepsRepository(path: path)
    let after = try await upgraded.snapshot()
    let saved = try await upgraded.workout(id: workout.id)
    XCTAssertEqual(after.restSeconds, 137)
    XCTAssertFalse(after.stretchingEnabled)
    XCTAssertEqual(after.skills.count, 4)
    XCTAssertEqual(after.exercises, before.exercises)
    XCTAssertEqual(after.schedules, before.schedules)
    XCTAssertEqual(saved, workout)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 17)
  }
}

extension SkillRepositoryTests {
  func testExtensionsExplainDifferentMovementsAndSuggestDynamicTracking() {
    let extensions = SkillCatalogue.definitions.flatMap(\.steps).filter(\.isExtension)
    XCTAssertEqual(Set(extensions.map(\.instructions)).count, extensions.count)
    let press = extensions.first { $0.name == "Press to Handstand" }
    XCTAssertEqual(press?.suggestedFormat, .repetitions)
  }
}
