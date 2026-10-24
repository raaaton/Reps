import Foundation
import XCTest

@testable import RepsCore

final class PlanningEditingTests: XCTestCase, @unchecked Sendable {
  private func path() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
  }

  private func newSchedule(id: String = "new-session", day: Int = 1) -> TrainingSchedule {
    TrainingSchedule(
      id: id, name: "Mobilité", weekday: day, isEnabled: true,
      reminderMinutes: nil, exerciseIDs: ["l-sit", "push-ups"])
  }

  func testNewSchedulePersistsWithItsOrderAndCanBeEdited() async throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    try await repository.saveSchedule(newSchedule(), creating: true)
    let reopened = try RepsRepository(path: path)
    let first = try await reopened.snapshot()
    XCTAssertEqual(first.schedules.count, 4)
    XCTAssertEqual(first.schedules.first?.exerciseIDs, ["l-sit", "push-ups"])
    XCTAssertNil(first.schedules.first?.reminderMinutes)
    var schedule = try XCTUnwrap(first.schedules.first)
    schedule.name = "Mobilité du lundi"
    try await reopened.saveSchedule(schedule)
    let edited = try await reopened.snapshot()
    XCTAssertEqual(edited.schedules.first?.name, "Mobilité du lundi")
  }

  func testCreationCannotOverwriteExistingIDOrOccupyAnExistingDay() async throws {
    let repository = try RepsRepository(path: ":memory:")
    for day in [1, 3, 4, 5] {
      try await repository.saveSchedule(newSchedule(id: "day-\(day)", day: day), creating: true)
    }
    let initial = try await repository.snapshot()
    XCTAssertEqual(initial.schedules.count, 7)
    for schedule in [newSchedule(day: 6), newSchedule(id: "legs", day: 2)] {
      do {
        try await repository.saveSchedule(schedule, creating: true)
        XCTFail("Creation overwrote an existing session or occupied day")
      } catch {}
    }
    let after = try await repository.snapshot()
    XCTAssertEqual(after, initial)
  }

  func testDeletingScheduleFreesDayPreservesExercisesAndDoesNotReseed() async throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    try await repository.deleteSchedule(id: "push")
    try await repository.saveSchedule(newSchedule(day: 6), creating: true)
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertFalse(snapshot.schedules.contains { $0.id == "push" })
    XCTAssertEqual(snapshot.schedules.first { $0.weekday == 6 }?.id, "new-session")
    XCTAssertEqual(snapshot.exercises.count, 5)
    XCTAssertEqual(snapshot.restSeconds, 180)
    let inspection = try SQLiteDatabase(path: path)
    XCTAssertTrue(
      try inspection.query("SELECT * FROM schedule_exercises WHERE schedule_id='push'").isEmpty)
  }

  func testDeletingExerciseRemovesAssignmentsAndDisablesOnlyEmptiedSessions() async throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    try await repository.deleteExercise(id: "push-ups")
    let partial = try await repository.snapshot()
    XCTAssertEqual(partial.schedules.first { $0.id == "push" }?.exerciseIDs, ["pike-push-ups"])
    XCTAssertEqual(partial.schedules.first { $0.id == "push" }?.isEnabled, true)
    try await repository.deleteExercise(id: "bulgarians")
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.exercises.count, 3)
    XCTAssertEqual(snapshot.schedules.first { $0.id == "legs" }?.exerciseIDs, [])
    XCTAssertEqual(snapshot.schedules.first { $0.id == "legs" }?.isEnabled, false)
    XCTAssertEqual(
      snapshot.schedules.first { $0.id == "pull-abs" }?.exerciseIDs, ["chin-ups", "l-sit"])
    XCTAssertEqual(snapshot.schedules.first { $0.id == "pull-abs" }?.isEnabled, true)
  }

  func testExerciseDeletionFailureRollsBackAssignmentsAndActivation() async throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    let injection = try SQLiteDatabase(path: path)
    try injection.execute(
      """
      CREATE TRIGGER refuse_delete BEFORE DELETE ON exercises
      BEGIN SELECT RAISE(ABORT,'injected failure'); END
      """)
    do {
      try await repository.deleteExercise(id: "bulgarians")
      XCTFail("Accepted an injected deletion failure")
    } catch {}
    let after = try await repository.snapshot()
    XCTAssertEqual(after, initial)
  }

  func testDeletingAllConfigurationDoesNotRestoreDefaultsOnReopen() async throws {
    let path = path()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let initial = try await repository.snapshot()
    for schedule in initial.schedules { try await repository.deleteSchedule(id: schedule.id) }
    for exercise in initial.exercises { try await repository.deleteExercise(id: exercise.id) }
    let reopened = try RepsRepository(path: path)
    let empty = try await reopened.snapshot()
    XCTAssertTrue(empty.schedules.isEmpty)
    XCTAssertTrue(empty.exercises.isEmpty)
    XCTAssertEqual(empty.restSeconds, 180)
    let exercise = initial.exercises[0]
    try await reopened.saveExercise(exercise)
    var schedule = newSchedule()
    schedule.exerciseIDs = ["bulgarians"]
    try await reopened.saveSchedule(schedule, creating: true)
    let recreated = try await reopened.snapshot()
    XCTAssertEqual(recreated.exercises.map(\.id), ["bulgarians"])
    XCTAssertEqual(recreated.schedules.map(\.id), ["new-session"])
  }
}
