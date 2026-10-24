import Foundation
import XCTest

@testable import RepsCore

final class SkillPracticeTests: XCTestCase {
  let now = 1_792_000_000_000
  func assignment(_ format: SkillFormat = .freePractice) -> SkillAssignment {
    SkillAssignment(
      skillID: "handstand", stepID: "handstand.supported",
      configuration: SkillConfiguration(format: format))
  }
  func action(_ r: RepsRepository, _ p: SkillPractice, _ action: SkillAction, at time: Int)
    async throws -> SkillPractice
  {
    try await r.applySkillCommand(
      SkillCommand(practiceID: p.id, expectedRevision: p.revision, action: action), now: time)
  }
  func testPausedFreePracticeSurvivesReopen() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    var p = try await r.startSkillPractice(assignment: assignment(), now: now)
    p = try await action(r, p, .acknowledgePreparation, at: now)
    p = try await action(r, p, .begin, at: now)
    p = try await action(r, p, .pause, at: now + 1000)
    let reopened = try RepsRepository(path: path)
    let loaded = try await reopened.activeSkillPractice()
    XCTAssertEqual(loaded, p)
    p = try await action(reopened, p, .resume, at: now + 3000)
    p = try await action(reopened, p, .finish(note: "", bestHoldMS: nil), at: now + 4000)
    XCTAssertEqual(p.elapsedMS(at: now + 4000), 2000)
    XCTAssertTrue(p.attempts.isEmpty)
    XCTAssertEqual(p.state, .completed)
  }
  func testReferenceDoesNotAutomaticallyFinishAndActivityIsExclusive() async throws {
    let r = try RepsRepository(path: ":memory:")
    var p = try await r.startSkillPractice(assignment: assignment(), now: now)
    p = try await action(r, p, .acknowledgePreparation, at: now)
    p = try await action(r, p, .begin, at: now)
    XCTAssertEqual(p.elapsedMS(at: now + 400_000), 400_000)
    XCTAssertNil(p.endedAt)
    do {
      _ = try await r.startSkillPractice(assignment: assignment(), now: now)
      XCTFail("Duplicate activity")
    } catch {}
    do {
      _ = try await action(r, p, .pause, at: now - 1)
      XCTFail("Backward clock accepted")
    } catch {}
  }
  func testRepeatedCommandDoesNotDuplicateAttemptAndOldRevisionCannotAdvance() async throws {
    let r = try RepsRepository(path: ":memory:")
    var p = try await r.startSkillPractice(assignment: assignment(.timedHolds), now: now)
    p = try await action(r, p, .acknowledgePreparation, at: now)
    p = try await action(r, p, .beginAttempt, at: now)
    let command = SkillCommand(
      practiceID: p.id, expectedRevision: p.revision, action: .recordAttempt(repetitions: nil))
    p = try await r.applySkillCommand(command, now: now + 6000)
    let again = try await r.applySkillCommand(command, now: now + 7000)
    XCTAssertEqual(again, p)
    XCTAssertEqual(p.attempts.count, 1)
    XCTAssertEqual(p.attempts[0].durationMS, 3000)
    p = try await action(r, p, .changeRest(.skip), at: now + 7000)
    do {
      _ = try await r.applySkillCommand(command, now: now + 8000)
      XCTFail("Stale command accepted")
    } catch {}
    XCTAssertEqual(p.state, .ready)
  }
  func testCancelCountdownRecordsNothingAndRepetitionsUseActualResult() async throws {
    let r = try RepsRepository(path: ":memory:")
    var p = try await r.startSkillPractice(assignment: assignment(.timedHolds), now: now)
    p = try await action(r, p, .acknowledgePreparation, at: now)
    p = try await action(r, p, .beginAttempt, at: now)
    p = try await action(r, p, .cancelCountdown, at: now + 1000)
    XCTAssertTrue(p.attempts.isEmpty)
    XCTAssertEqual(p.state, .ready)
    p = try await action(r, p, .cancel, at: now + 2000)
    p = try await r.startSkillPractice(assignment: assignment(.repetitions), now: now + 3000)
    p = try await action(r, p, .acknowledgePreparation, at: now + 3000)
    p = try await action(r, p, .beginAttempt, at: now + 3000)
    p = try await action(r, p, .recordAttempt(repetitions: 7), at: now + 4000)
    XCTAssertEqual(p.attempts.first?.repetitions, 7)
    XCTAssertNil(p.attempts.first?.durationMS)
  }
}

extension SkillPracticeTests {
  func testSkipDeliveredAtExpiredRestStillContinues() async throws {
    let r = try RepsRepository(path: ":memory:")
    var p = try await r.startSkillPractice(assignment: assignment(.repetitions), now: now)
    p = try await action(r, p, .acknowledgePreparation, at: now)
    p = try await action(r, p, .beginAttempt, at: now)
    p = try await action(r, p, .recordAttempt(repetitions: 3), at: now + 1000)
    p = try await action(r, p, .changeRest(.skip), at: now + 61_000)
    XCTAssertEqual(p.state, .ready)
    XCTAssertEqual(p.attempts.count, 1)
  }
  func testTwoRepositoryConnectionsCannotBothStartAnActivity() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let a = try RepsRepository(path: path)
    let b = try RepsRepository(path: path)
    let block = assignment()
    let time = now
    let count = await withTaskGroup(of: Bool.self) { group in
      for r in [a, b] {
        group.addTask {
          do {
            _ = try await r.startSkillPractice(assignment: block, now: time)
            return true
          } catch { return false }
        }
      }
      var successes = 0
      for await success in group { if success { successes += 1 } }
      return successes
    }
    XCTAssertEqual(count, 1)
  }
}
