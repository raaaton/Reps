import Foundation
import XCTest

@testable import SportCore

final class WorkoutSkillTests: XCTestCase {
  let now = 1_791_720_000_000
  var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  func configure(_ r: SportRepository, placement: SkillPlacement) async throws {
    let s = try await r.snapshot()
    var schedule = try XCTUnwrap(s.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["chin-ups"]
    schedule.setCounts = ["chin-ups": 1]
    schedule.skills = [SkillAssignment(skillID: "handstand", stepID: "handstand.supported")]
    schedule.skillPlacement = placement
    try await r.saveSchedule(schedule)
  }
  func completeStrength(_ r: SportRepository, _ w: WorkoutSession, at time: Int) async throws {
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: time)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1, repetitions: 8, weightGrams: 0, now: time + 1000
    )
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 70, now: time + 2000)
  }
  func testAfterForceWithoutStretchWaitsForSkills() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .afterForce)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    try await completeStrength(r, w, at: now)
    var current = try await r.workout(id: w.id)
    XCTAssertEqual(current.status, .active)
    XCTAssertEqual(current.phase, .skills)
    let p = try XCTUnwrap(current.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 3000)
    current = try await r.workout(id: w.id)
    XCTAssertEqual(current.status, .completed)
    XCTAssertEqual(current.skills?.blocks.first?.state, .skipped)
  }
  func testBeforeForceBlocksStrengthAndKeepsSnapshotAfterArchive() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .beforeForce)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    XCTAssertEqual(w.phase, .skills)
    let e = try XCTUnwrap(w.currentExercise)
    do {
      try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now)
      XCTFail("Bypassed skills")
    } catch {}
    try await r.archiveSkill(id: "handstand")
    let unchanged = try await r.workout(id: w.id)
    XCTAssertEqual(unchanged, w)
    let p = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 1000)
    let next = try await r.workout(id: w.id)
    XCTAssertEqual(next.phase, .readySet)
  }
  func testStandaloneAndWorkoutCannotStartTogether() async throws {
    let r = try SportRepository(path: ":memory:")
    let assignment = SkillAssignment(skillID: "handstand", stepID: "handstand.supported")
    let p = try await r.startSkillPractice(assignment: assignment, now: now)
    do {
      _ = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
      XCTFail("Concurrent activity")
    } catch {}
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .cancel), now: now + 1000
    )
    _ = try await r.startWorkout(scheduleID: "pull-abs", now: now + 2000, calendar: calendar)
    do {
      _ = try await r.startSkillPractice(assignment: assignment, now: now + 3000)
      XCTFail("Concurrent practice")
    } catch {}
  }
}

extension WorkoutSkillTests {
  func testCancellationCannotPrecedeAnAlreadyRecordedSkillEvent() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .beforeForce)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    let p = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 5000)
    do {
      try await r.cancelWorkout(id: w.id, now: now + 1000)
      XCTFail("Cancellation predates skill event")
    } catch {}
    let saved = try await r.workout(id: w.id)
    XCTAssertEqual(saved.status, .active)
  }
}

extension WorkoutSkillTests {
  func testSkillCommandCannotPredatePreviousBlockAndBackupRemainsUsable() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .beforeForce)
    var snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.skills.append(SkillAssignment(skillID: "l-sit", stepID: "l-sit.tuck"))
    try await r.saveSchedule(schedule)
    let w = try await r.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
    let first = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: first.id, expectedRevision: first.revision, action: .skip),
      now: now + 100_000)
    let updated = try await r.workout(id: w.id)
    let second = try XCTUnwrap(updated.currentSkill)
    do {
      _ = try await r.applySkillCommand(
        SkillCommand(practiceID: second.id, expectedRevision: second.revision, action: .skip),
        now: now + 50_000)
      XCTFail("Accepted command before previous block")
    } catch {}
    let unchanged = try await r.workout(id: w.id)
    XCTAssertEqual(unchanged, updated)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: second.id, expectedRevision: second.revision, action: .skip),
      now: now + 110_000)
    try await r.cancelWorkout(id: w.id, now: now + 120_000)
    let archive = try await r.exportTraining(now: now + 120_000)
    XCTAssertNoThrow(try archive.encoded())
    snapshot = try await r.snapshot()
    XCTAssertEqual(snapshot.schedules.count, 3)
  }
  func testAfterForceSkillCannotPredateFinalFeeling() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .afterForce)
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    try await completeStrength(r, w, at: now + 10_000)
    let updated = try await r.workout(id: w.id)
    let p = try XCTUnwrap(updated.currentSkill)
    do {
      _ = try await r.applySkillCommand(
        SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip),
        now: now + 11_500)
      XCTFail("Accepted skill action before final Feeling")
    } catch {}
    let unchanged = try await r.workout(id: w.id)
    XCTAssertEqual(unchanged, updated)
  }
}

extension WorkoutSkillTests {
  func testWarmupAfterSkillsCannotStartBeforeTheLastSkillEvent() async throws {
    let r = try SportRepository(path: ":memory:")
    try await configure(r, placement: .beforeForce)
    let w = try await r.startWorkout(
      scheduleID: "pull-abs", now: now, calendar: calendar, includeSupport: true)
    let p = try XCTUnwrap(w.currentSkill)
    _ = try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: .skip), now: now + 5000)
    let current = try await r.workout(id: w.id)
    let warmup = try XCTUnwrap(current.currentSupport)
    do {
      try await r.beginSupport(workoutID: w.id, stepID: warmup.id, now: now + 1000)
      XCTFail("Warmup predates skill event")
    } catch {}
    let unchanged = try await r.workout(id: w.id)
    XCTAssertEqual(unchanged, current)
  }
}
