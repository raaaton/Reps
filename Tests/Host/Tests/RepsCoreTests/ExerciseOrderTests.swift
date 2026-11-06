import Foundation
import XCTest

@testable import RepsCore

final class ExerciseOrderTests: XCTestCase, @unchecked Sendable {
  func testOrderSurvivesRestartAndJSONRestoreWithoutChangingWorkouts() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let now = 1_794_096_000_000
    let active = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    let before = try await repository.snapshot()
    let ids = before.exercises.map(\.id).reversed().map { $0 }
    try await repository.reorderExercises(ids: ids)
    let reopened = try RepsRepository(path: path)
    let saved = try await reopened.snapshot()
    XCTAssertEqual(saved.exercises.map(\.id), ids)
    XCTAssertEqual(saved.schedules, before.schedules)
    XCTAssertEqual(saved.goals, before.goals)
    XCTAssertEqual(saved.archivedExercises, before.archivedExercises)
    let retained = try await reopened.workout(id: active.id)
    XCTAssertEqual(retained, active)

    try await reopened.cancelWorkout(id: active.id, now: now + 1000)
    let archive = try await reopened.exportTraining(now: now + 2000)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now + 2000)
    try await target.applyTrainingImport(preview, now: now + 2000)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored.exercises, saved.exercises)
  }

  func testIncompleteDuplicateUnknownAndStaleOrdersAreRejectedAtomically() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let before = try await repository.snapshot()
    let ids = before.exercises.map(\.id)
    for invalid in [Array(ids.dropLast()), ids + [ids[0]], ["missing"] + Array(ids.dropFirst())] {
      do {
        try await repository.reorderExercises(ids: invalid)
        XCTFail("An invalid order must not remove, duplicate or replace exercises")
      } catch {}
      let after = try await repository.snapshot()
      XCTAssertEqual(after, before)
    }
    try await repository.archiveExercise(id: ids[0])
    let archived = try await repository.snapshot()
    do {
      try await repository.reorderExercises(ids: ids)
      XCTFail("A stale screen must not restore an archived exercise")
    } catch {}
    let after = try await repository.snapshot()
    XCTAssertEqual(after, archived)
  }

  func testStorageFailureRollsBackEveryPosition() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let before = try await repository.snapshot()
    let database = try SQLiteDatabase(path: path)
    try database.execute(
      "CREATE TRIGGER reject_order BEFORE UPDATE OF position ON exercises WHEN OLD.id='push-ups' AND NEW.position>=0 BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repository.reorderExercises(ids: before.exercises.map(\.id).reversed())
      XCTFail("A partially written order must roll back")
    } catch {}
    let after = try await repository.snapshot()
    XCTAssertEqual(after, before)
  }
}
