import Foundation
import XCTest

@testable import RepsCore

final class SkillTransferTests: XCTestCase {
  let now = 1_791_720_000_000
  func testActivePracticeArchiveRoundTrip() async throws {
    let r = try RepsRepository(path: ":memory:")
    let a = SkillAssignment(skillID: "handstand", stepID: "handstand.supported")
    var p = try await r.startSkillPractice(assignment: a, now: now)
    p = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .acknowledgePreparation),
      now: now)
    p = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .begin), now: now)
    p = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .pause), now: now + 1000)
    let archive = try await r.exportTraining(now: now + 2000)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.version, 8)
    XCTAssertEqual(decoded.contents, archive.contents)
    let destination = try RepsRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: now + 2000)
    try await destination.applyTrainingImport(preview, now: now + 2000)
    let active = try await destination.activeSkillPractice()
    XCTAssertEqual(active, p)
    let recovery = try await destination.recoveryArchive()
    XCTAssertNotNil(recovery)
  }
  func testCSVPreservesMixedPractice() async throws {
    let r = try RepsRepository(path: ":memory:")
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    let snapshot = try await r.snapshot()
    var s = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    s.skills = [SkillAssignment(skillID: "handstand", stepID: "handstand.supported")]
    try await r.saveSchedule(s)
    let w = try await r.startWorkout(scheduleID: s.id, now: now, calendar: c)
    let p = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 1000)
    try await r.cancelWorkout(id: w.id, now: now + 2000)
    let preview = try await r.previewCSVImport([], now: now + 3000)
    try await r.applyTrainingImport(preview, now: now + 3000)
    var saved = try await r.skillPractices()
    XCTAssertEqual(saved.count, 1)
    XCTAssertEqual(saved.first?.id, p.id)
    XCTAssertEqual(saved.first?.origin.workoutID, w.id)
    XCTAssertTrue(saved.first?.origin.isDetached == true)
    let again = try await r.previewCSVImport([], now: now + 4000)
    try await r.applyTrainingImport(again, now: now + 4000)
    saved = try await r.skillPractices()
    XCTAssertEqual(saved.count, 1)
  }
  func testActiveMixedWorkoutArchiveRoundTrip() async throws {
    let r = try RepsRepository(path: ":memory:")
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: c)
    let data = try await r.exportTraining(now: now + 1000)
    let decoded = try TrainingArchive.decode(data.encoded())
    let destination = try RepsRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: now + 1000)
    try await destination.applyTrainingImport(preview, now: now + 1000)
    let restored = try await destination.workout(id: w.id)
    XCTAssertEqual(restored, w)
  }
}

extension SkillTransferTests {
  func testNestedUnknownFieldAndInconsistentActiveStateAreRejected() async throws {
    let r = try RepsRepository(path: ":memory:")
    let a = SkillAssignment(skillID: "handstand", stepID: "handstand.supported")
    _ = try await r.startSkillPractice(assignment: a, now: now)
    let archive = try await r.exportTraining(now: now)
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var sessions = try XCTUnwrap(contents["skillSessions"] as? [[String: Any]])
    sessions[0]["privatePhotos"] = "unrecognized"
    contents["skillSessions"] = sessions
    root["contents"] = contents
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
    sessions[0].removeValue(forKey: "privatePhotos")
    sessions[0]["state"] = "practicing"
    contents["skillSessions"] = sessions
    root["contents"] = contents
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
  }
  func testCountdownAndPausedRestSurviveArchiveRestore() async throws {
    for format in [SkillFormat.timedHolds, .repetitions] {
      let r = try RepsRepository(path: ":memory:")
      let a = SkillAssignment(
        skillID: "handstand", stepID: "handstand.supported",
        configuration: SkillConfiguration(format: format))
      var p = try await r.startSkillPractice(assignment: a, now: now)
      p = try await r.applySkillCommand(
        SkillCommand(
          practiceID: p.id, expectedRevision: p.revision, action: .acknowledgePreparation), now: now
      )
      p = try await r.applySkillCommand(
        SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .beginAttempt),
        now: now)
      var time = now + 1000
      if format == .repetitions {
        p = try await r.applySkillCommand(
          SkillCommand(
            practiceID: p.id, expectedRevision: p.revision, action: .recordAttempt(repetitions: 2)),
          now: time)
        time += 1000
        p = try await r.applySkillCommand(
          SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .pause), now: time)
      }
      let archive = try await r.exportTraining(now: time)
      let decoded = try TrainingArchive.decode(archive.encoded())
      let target = try RepsRepository(path: ":memory:")
      let preview = try await target.previewArchiveImport(decoded, now: time)
      try await target.applyTrainingImport(preview, now: time)
      let restored = try await target.activeSkillPractice()
      XCTAssertEqual(restored, p)
    }
  }
  func testInvalidArchiveCannotPartiallyReplaceSkillData() async throws {
    let r = try RepsRepository(path: ":memory:")
    let before = try await r.snapshot()
    var archive = try await r.exportTraining(now: now)
    archive.contents.configuration.skills[0].steps = []
    do {
      _ = try await r.previewArchiveImport(archive, now: now)
      XCTFail("Empty steps imported")
    } catch {}
    let after = try await r.snapshot()
    XCTAssertEqual(after, before)
  }
}

extension SkillTransferTests {
  func testImportedCountdownRequiresAStartedRunningSegment() async throws {
    let r = try RepsRepository(path: ":memory:")
    let assignment = SkillAssignment(
      skillID: "handstand", stepID: "handstand.supported",
      configuration: SkillConfiguration(format: .timedHolds))
    var p = try await r.startSkillPractice(assignment: assignment, now: now)
    p = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .acknowledgePreparation),
      now: now)
    p = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .beginAttempt), now: now)
    var archive = try await r.exportTraining(now: now + 1000)
    archive.contents.skillSessions[0].startedAt = nil
    archive.contents.skillSessions[0].segmentStartedAt = nil
    XCTAssertThrowsError(try archive.encoded())
    XCTAssertThrowsError(try TrainingArchive.decode(JSONEncoder().encode(archive)))
  }
  func testImportedPausedStateMustMatchItsTrackingFormat() async throws {
    let r = try RepsRepository(path: ":memory:")
    let assignment = SkillAssignment(
      skillID: "handstand", stepID: "handstand.supported",
      configuration: SkillConfiguration(format: .repetitions))
    _ = try await r.startSkillPractice(assignment: assignment, now: now)
    var archive = try await r.exportTraining(now: now + 1000)
    archive.contents.skillSessions[0].state = .paused
    archive.contents.skillSessions[0].pausedFrom = .practicing
    archive.contents.skillSessions[0].startedAt = now
    XCTAssertThrowsError(try archive.encoded())
  }
  func testImportedAttemptCannotOverlapPreviousAttemptOrExceedCapacity() async throws {
    let r = try RepsRepository(path: ":memory:")
    let assignment = SkillAssignment(
      skillID: "handstand", stepID: "handstand.supported",
      configuration: SkillConfiguration(format: .timedHolds))
    var p = try await r.startSkillPractice(assignment: assignment, now: now)
    for (action, time) in [
      (SkillAction.acknowledgePreparation, now), (.beginAttempt, now),
      (.recordAttempt(repetitions: nil), now + 5000), (.changeRest(.skip), now + 6000),
      (.beginAttempt, now + 6000),
    ] {
      p = try await r.applySkillCommand(
        SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: action), now: time)
    }
    var archive = try await r.exportTraining(now: now + 7000)
    archive.contents.skillSessions[0].attemptStartedAt = now + 1000
    XCTAssertThrowsError(try archive.encoded())
    archive.contents.skillSessions[0] = p
    archive.contents.skillSessions[0].assignment.configuration.attemptCount = 1
    XCTAssertThrowsError(try archive.encoded())
  }
}
