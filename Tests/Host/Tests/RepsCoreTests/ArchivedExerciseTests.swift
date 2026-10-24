import Foundation
import XCTest

@testable import RepsCore

final class ArchivedExerciseTests: XCTestCase, @unchecked Sendable {
  private let now = 1_791_720_000_000
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }
  private func draft(_ id: String, ids: [String]) -> ManualWorkout {
    ManualWorkout(
      id: id, name: "Séance", performedAt: now - 86_400_000,
      exercises: ids.map {
        ManualWorkoutExercise(
          catalogueID: $0, tracking: .repetitions,
          sets: [ManualWorkoutSet(repetitions: 10, weightGrams: 6000)], feelingTenths: 70)
      })
  }
  func testPurgeRemovesOnlyArchivedPerformanceAndEmptyWorkouts() async throws {
    let repo = try RepsRepository(path: ":memory:")
    try await repo.addHistoricalWorkout(
      draft("mixed", ids: ["chin-ups", "push-ups"]), now: now, calendar: calendar)
    try await repo.addHistoricalWorkout(
      draft("only", ids: ["chin-ups"]), now: now, calendar: calendar)
    let before = try await repo.workout(id: "mixed")
    try await repo.deleteExercise(id: "chin-ups")
    let configuration = try await repo.snapshot()
    try await repo.deleteArchivedExercise(id: "chin-ups")
    let kept = try await repo.workout(id: "mixed")
    XCTAssertEqual(kept.exercises, [before.exercises[1]])
    XCTAssertEqual(kept.startedAt, before.startedAt)
    XCTAssertEqual(kept.endedAt, before.endedAt)
    let overview = try await repo.workoutOverview(now: now)
    XCTAssertEqual(overview.history.map(\.id), ["mixed"])
    let archives = try await repo.historyExercises()
    XCTAssertFalse(archives.contains { $0.id == "chin-ups" })
    let history = try await repo.exerciseHistory(exerciseID: "chin-ups")
    XCTAssertTrue(history.isEmpty)
    let after = try await repo.snapshot()
    XCTAssertEqual(configuration, after)
    let archive = try await repo.exportTraining(now: now)
    try archive.validate()
    let csv = try TrainingCSV.decode(TrainingCSV.encode(archive.contents.workouts))
    XCTAssertEqual(csv, archive.contents.workouts)
  }
  func testCatalogueAndLiveWorkoutPurgeAreRefused() async throws {
    let repo = try RepsRepository(path: ":memory:")
    do {
      try await repo.deleteArchivedExercise(id: "chin-ups")
      XCTFail("Catalogue is not an archive")
    } catch {}
    let active = try await repo.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    try await repo.deleteExercise(id: "chin-ups")
    do {
      try await repo.deleteArchivedExercise(id: "chin-ups")
      XCTFail("Active snapshots must be preserved")
    } catch {}
    let retained = try await repo.workout(id: active.id)
    XCTAssertEqual(retained, active)
  }
  func testPurgeFailureRollsBackOtherRows() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    try await repo.addHistoricalWorkout(
      draft("only", ids: ["chin-ups"]), now: now, calendar: calendar)
    try await repo.deleteExercise(id: "chin-ups")
    let original = try await repo.workout(id: "only")
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER refuse_empty_workout BEFORE DELETE ON workouts BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.deleteArchivedExercise(id: "chin-ups")
      XCTFail("Failed transaction must throw")
    } catch {}
    let retained = try await repo.workout(id: "only")
    XCTAssertEqual(retained, original)
  }
  func testPurgeCleansHistoricalRestAndGoalReferences() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    try await repo.addHistoricalWorkout(
      draft("mixed", ids: ["chin-ups", "push-ups"]), now: now, calendar: calendar)
    let original = try await repo.workout(id: "mixed")
    let removed = original.exercises[0]
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "INSERT INTO workout_rests VALUES('old-rest','mixed',?,1,'finished',NULL,NULL)",
      [.text(removed.id)])
    let goal = ExerciseGoal(definition: removed.definition, load: .bodyweight, repetitions: [10])
    try db.execute(
      "INSERT INTO workout_goals VALUES(?,?)", [.text(removed.id), try ExerciseGoal.encode(goal)])
    try await repo.deleteExercise(id: "chin-ups")
    try await repo.deleteArchivedExercise(id: "chin-ups")
    let kept = try await repo.workout(id: "mixed")
    XCTAssertEqual(kept.exercises, [original.exercises[1]])
    XCTAssertEqual(try db.query("SELECT COUNT(*) AS n FROM workout_rests").first?.integer("n"), 0)
    XCTAssertEqual(try db.query("SELECT COUNT(*) AS n FROM workout_goals").first?.integer("n"), 0)
  }
}
