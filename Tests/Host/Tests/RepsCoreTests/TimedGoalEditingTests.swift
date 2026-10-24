import Foundation
import XCTest

@testable import RepsCore

final class TimedGoalEditingTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  func makeGoal(_ r: RepsRepository, seconds: Int?) async throws -> (
    TrainingExercise, ExerciseGoal
  ) {
    let snapshot = try await r.snapshot()
    let exercise = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    var changed = exercise
    changed.durationSeconds = seconds
    return (exercise, ExerciseGoal(definition: changed, load: .bodyweight, repetitions: nil))
  }
  func testDurationAndUntimedPersistTogetherWithGoalWithoutChangingActiveSnapshot() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let (original, goal) = try await makeGoal(r, seconds: 25)
    let active = try await r.startWorkout(scheduleID: "pull-abs", now: now)
    try await r.saveTimedGoal(goal, original: nil, originalExercise: original)
    let reopened = try RepsRepository(path: path)
    let first = try await reopened.snapshot()
    XCTAssertEqual(first.exercises.first { $0.id == "l-sit" }?.durationSeconds, 25)
    XCTAssertEqual(first.schedules.first { $0.id == "pull-abs" }?.goals["l-sit"], goal)
    let unchanged = try await reopened.workout(id: active.id)
    XCTAssertEqual(unchanged, active)
    var freeDefinition = goal.definition
    freeDefinition.durationSeconds = nil
    let freeGoal = ExerciseGoal(definition: freeDefinition, load: .bodyweight, repetitions: nil)
    try await reopened.saveTimedGoal(freeGoal, original: goal, originalExercise: goal.definition)
    let final = try await reopened.snapshot()
    XCTAssertNil(final.exercises.first { $0.id == "l-sit" }?.durationSeconds)
    XCTAssertEqual(final.schedules.first { $0.id == "pull-abs" }?.goals["l-sit"], freeGoal)
  }
  func testStaleExerciseAndInvalidDurationNeverOverwriteCurrentConfiguration() async throws {
    let r = try RepsRepository(path: ":memory:")
    let (original, goal) = try await makeGoal(r, seconds: 25)
    var renamed = original
    renamed.name = "Renamed"
    try await r.saveExercise(renamed)
    do {
      try await r.saveTimedGoal(goal, original: nil, originalExercise: original)
      XCTFail("Stale catalogue saved")
    } catch {}
    let current = try await r.snapshot()
    XCTAssertEqual(current.exercises.first { $0.id == "l-sit" }, renamed)
    XCTAssertTrue(current.goals.isEmpty)
    var invalid = renamed
    invalid.durationSeconds = 0
    do {
      try await r.saveTimedGoal(
        ExerciseGoal(definition: invalid, load: .bodyweight, repetitions: nil), original: nil,
        originalExercise: renamed)
      XCTFail("Zero duration saved")
    } catch {}
    var otherChange = renamed
    otherChange.durationSeconds = 25
    otherChange.setCount += 1
    do {
      try await r.saveTimedGoal(
        ExerciseGoal(definition: otherChange, load: .bodyweight, repetitions: nil), original: nil,
        originalExercise: renamed)
      XCTFail("Unexpected set change saved")
    } catch {}
  }
  func testStaleGoalRollsBackDurationUpdate() async throws {
    let r = try RepsRepository(path: ":memory:")
    let (original, goal) = try await makeGoal(r, seconds: 25)
    let current = ExerciseGoal(definition: original, load: .bodyweight, repetitions: nil)
    try await r.saveGoal(current, original: nil)
    do {
      try await r.saveTimedGoal(goal, original: nil, originalExercise: original)
      XCTFail("Stale goal saved")
    } catch {}
    let saved = try await r.snapshot()
    XCTAssertEqual(saved.exercises.first { $0.id == "l-sit" }, original)
    XCTAssertEqual(saved.schedules.first { $0.id == "pull-abs" }?.goals["l-sit"], current)
  }
  func testSQLFailureRollsBackCatalogueAndGoal() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let (original, goal) = try await makeGoal(r, seconds: 25)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER fail_timed_goal BEFORE UPDATE OF goal_payload ON schedule_exercises BEGIN SELECT RAISE(ABORT,'test failure'); END"
    )
    do {
      try await r.saveTimedGoal(goal, original: nil, originalExercise: original)
      XCTFail("SQL error ignored")
    } catch {}
    let saved = try await r.snapshot()
    XCTAssertEqual(saved.exercises.first { $0.id == "l-sit" }, original)
    XCTAssertTrue(saved.goals.isEmpty)
  }
}
