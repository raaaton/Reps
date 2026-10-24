import XCTest

@testable import SportCore

final class SkillLifecycleTests: XCTestCase {
  func testCurrentStepReconcilesForwardAndBackwardWithoutLosingFirstSuccess() throws {
    let skill = SkillCatalogue.definitions[0]
    var progress = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    progress = try progress.settingCurrent(skill.steps[3].id, in: skill)
    XCTAssertTrue(skill.steps.prefix(3).allSatisfy { progress.achievements[$0.id] == .consistent })
    progress = try progress.settingCurrent(skill.steps[1].id, in: skill)
    XCTAssertEqual(progress.achievements[skill.steps[0].id], .consistent)
    XCTAssertEqual(progress.achievements[skill.steps[2].id], .firstSuccess)
    XCTAssertNotEqual(progress.achievements[skill.steps[1].id], .consistent)
  }
  func testAchievementsAreIndependentFromCurrentAndOtherSteps() throws {
    let skill = SkillCatalogue.definitions[0]
    var p = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    p.achievements[skill.steps[5].id] = .consistent
    p = try p.settingAchievement(.consistent, stepID: skill.steps[3].id, in: skill)
    XCTAssertEqual(p.currentStepID, skill.steps[0].id)
    XCTAssertNil(p.achievements[skill.steps[1].id])
    XCTAssertEqual(p.achievements[skill.steps[5].id], .consistent)
    XCTAssertFalse(p.mainGoalCompleted(in: skill))
    for step in skill.steps {
      p = try p.settingAchievement(.consistent, stepID: step.id, in: skill)
    }
    XCTAssertTrue(p.completed(in: skill))
    p = try p.settingAchievement(.unrecorded, stepID: skill.steps[1].id, in: skill)
    XCTAssertEqual(p.currentStepID, skill.steps[0].id)
    XCTAssertNil(p.achievements[skill.steps[1].id])
    XCTAssertEqual(p.achievements[skill.steps[5].id], .consistent)
    XCTAssertFalse(p.completed(in: skill))
  }
  func testArchiveDeleteAndResetAreDistinctAndPersist() async throws {
    let r = try SportRepository(path: ":memory:")
    let skill = SkillCatalogue.definitions[0].duplicated()
    try await r.saveSkill(skill, original: nil)
    var p = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    p.achievements[skill.steps[0].id] = .consistent
    try await r.saveSkillProgress(p, adoptingIn: [])
    try await r.resetSkill(id: skill.id)
    let reset = try await r.snapshot()
    XCTAssertFalse(reset.skillProgress.contains { $0.skillID == skill.id })
    XCTAssertTrue(reset.skills.contains { $0.id == skill.id })
    do {
      try await r.deleteArchivedSkill(id: skill.id)
      XCTFail("Deleted an unarchived skill")
    } catch {}
    try await r.archiveSkill(id: skill.id)
    try await r.deleteArchivedSkill(id: skill.id)
    let deleted = try await r.snapshot()
    XCTAssertFalse(deleted.skills.contains { $0.id == skill.id })
  }
  func testAssignmentCreationValidatesIDsAndSurvivesScheduleReopen() async throws {
    let r = try SportRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    let skill = snapshot.skills[0]
    let block = try skill.assignment(for: skill.steps[1].id)
    XCTAssertThrowsError(try skill.assignment(for: ""))
    var schedule = snapshot.schedules[0]
    schedule.skills.append(block)
    try await r.saveSchedule(schedule)
    let reopened = try await r.snapshot()
    XCTAssertEqual(reopened.schedules.first { $0.id == schedule.id }?.skills, [block])
  }
}

extension SkillLifecycleTests {
  func testTerminalHistoryDeletionAndActiveGuards() async throws {
    let r = try SportRepository(path: ":memory:")
    let skill = SkillCatalogue.definitions[0]
    let p = try await r.startSkillPractice(
      assignment: skill.assignment(for: skill.steps[0].id), now: 1000)
    do {
      try await r.deleteSkillPractice(id: p.id)
      XCTFail("Active practice deleted")
    } catch {}
    do {
      try await r.resetSkill(id: skill.id)
      XCTFail("Active skill reset")
    } catch {}
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .cancel), now: 2000)
    try await r.deleteSkillPractice(id: p.id)
    let practices = try await r.skillPractices()
    XCTAssertTrue(practices.isEmpty)
  }
  func testPresetPermanentDeletionSurvivesReopen() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    try await r.archiveSkill(id: "handstand")
    try await r.deleteArchivedSkill(id: "handstand")
    let reopened = try SportRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertFalse(snapshot.skills.contains { $0.id == "handstand" })
  }
}

extension SkillLifecycleTests {
  func testMixedPracticeDeletionPreservesStrengthAndArchiveRoundTrip() async throws {
    let r = try SportRepository(path: ":memory:")
    let now = 1_791_720_000_000
    let snapshot = try await r.snapshot()
    var schedule = snapshot.schedules.first { $0.id == "pull-abs" }!
    schedule.skills = [try snapshot.skills[0].assignment(for: snapshot.skills[0].steps[0].id)]
    try await r.saveSchedule(schedule)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let w = try await r.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
    let p = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 1000)
    do {
      try await r.deleteSkillPractice(id: p.id)
      XCTFail("Deleted child during active workout")
    } catch {}
    try await r.cancelWorkout(id: w.id, now: now + 2000)
    let before = try await r.workout(id: w.id)
    try await r.deleteSkillPractice(id: p.id)
    let after = try await r.workout(id: w.id)
    XCTAssertEqual(after.exercises, before.exercises)
    XCTAssertEqual(after.status, before.status)
    XCTAssertTrue(after.skills?.blocks.isEmpty == true)
    let archive = try await r.exportTraining(now: now + 3000)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.contents, archive.contents)
  }
  func testBothWorkoutAdditionDraftsPersistWithExactStepAndSettings() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try SportRepository(path: path)
    let original = try await r.snapshot()
    var fromDetail = original.schedules[0]
    let handstand = original.skills.first { $0.id == "handstand" }!
    let selected = try handstand.assignment(for: handstand.steps[2].id)
    fromDetail.skills.append(selected)
    try await r.saveSchedule(fromDetail)
    var settingsDraft = original.schedules[1]
    let planche = original.skills.first { $0.id == "planche" }!
    var editedBlock = try planche.assignment(for: planche.steps[1].id)
    editedBlock.configuration.attemptCount = 7
    settingsDraft.skills.append(editedBlock)
    try await r.saveSchedule(settingsDraft)
    let reopened = try SportRepository(path: path)
    let saved = try await reopened.snapshot()
    XCTAssertEqual(saved.schedules.first { $0.id == fromDetail.id }?.skills, [selected])
    XCTAssertEqual(saved.schedules.first { $0.id == settingsDraft.id }?.skills, [editedBlock])
  }
}

extension SkillLifecycleTests {
  func testResetRewindsFutureBlocksButKeepsVolume() async throws {
    let r = try SportRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    let skill = snapshot.skills[0]
    var schedule = snapshot.schedules[0]
    var block = try skill.assignment(for: skill.steps[2].id)
    block.configuration.attemptCount = 8
    schedule.skills = [block]
    try await r.saveSchedule(schedule)
    try await r.resetSkill(id: skill.id)
    let saved = try await r.snapshot()
    let resetBlock = try XCTUnwrap(saved.schedules.first { $0.id == schedule.id }?.skills.first)
    XCTAssertEqual(resetBlock.stepID, skill.steps[0].id)
    XCTAssertEqual(resetBlock.configuration, block.configuration)
  }
}
