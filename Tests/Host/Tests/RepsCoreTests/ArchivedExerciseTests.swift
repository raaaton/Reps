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
  func testExplicitArchiveWithoutHistorySurvivesRestartAndTransfer() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    let before = try await repo.snapshot()
    let exercise = try XCTUnwrap(before.exercises.first { $0.id == "chin-ups" })
    try await repo.archiveExercise(id: exercise.id)
    let reopened = try RepsRepository(path: path)
    let saved = try await reopened.snapshot()
    XCTAssertEqual(saved.archivedExercises, [exercise])
    XCTAssertFalse(saved.exercises.contains { $0.id == exercise.id })
    XCTAssertFalse(saved.schedules.contains { $0.exerciseIDs.contains(exercise.id) })
    let archive = try await reopened.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now)
    try await target.applyTrainingImport(preview, now: now)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored, saved)
    let csvPreview = try await target.previewCSVImport([], now: now)
    try await target.applyTrainingImport(csvPreview, now: now)
    let afterCSV = try await target.snapshot()
    XCTAssertEqual(afterCSV.archivedExercises, [exercise])
    try await target.deleteArchivedExercise(id: exercise.id)
    let purged = try await target.snapshot()
    XCTAssertTrue(purged.archivedExercises.isEmpty)
  }

  func testArchivePreservesActiveAndHistoricalSnapshotsAndDisablesEmptySchedule() async throws {
    let repo = try RepsRepository(path: ":memory:")
    let before = try await repo.snapshot()
    var schedule = try XCTUnwrap(before.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["chin-ups"]
    try await repo.saveSchedule(schedule)
    try await repo.addHistoricalWorkout(
      draft("past", ids: ["chin-ups"]), now: now, calendar: calendar)
    let past = try await repo.workout(id: "past")
    let active = try await repo.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
    try await repo.archiveExercise(id: "chin-ups")
    let saved = try await repo.snapshot()
    XCTAssertFalse(try XCTUnwrap(saved.schedules.first { $0.id == schedule.id }).isEnabled)
    let retainedActive = try await repo.workout(id: active.id)
    let retainedPast = try await repo.workout(id: past.id)
    XCTAssertEqual(retainedActive, active)
    XCTAssertEqual(retainedPast, past)
    do {
      try await repo.deleteArchivedExercise(id: "chin-ups")
      XCTFail("Active workout must prevent permanent deletion")
    } catch {}
    let history = try await repo.exerciseHistory(exerciseID: "chin-ups")
    XCTAssertEqual(history.map(\.workoutID), [past.id])
    _ = try await repo.exportTraining(now: now)
  }

  func testArchiveFailureRollsBackConfigurationAndArchive() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    let before = try await repo.snapshot()
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER refuse_archive BEFORE DELETE ON exercises BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.archiveExercise(id: "chin-ups")
      XCTFail("Failed transaction must throw")
    } catch {}
    let after = try await repo.snapshot()
    XCTAssertEqual(after, before)
  }

  func testDisabledExerciseIsSeparateFromExplicitArchivesAndStaleSaveIsRefused() async throws {
    let repo = try RepsRepository(path: ":memory:")
    let exercise = TrainingExercise(
      id: "unused", name: "Unused", tracking: .repetitions, setCount: 2,
      minimumReps: 8, maximumReps: 12, durationSeconds: nil, isEnabled: false)
    try await repo.saveExercise(exercise)
    let disabled = try await repo.snapshot()
    XCTAssertTrue(disabled.exercises.contains(exercise))
    XCTAssertTrue(disabled.archivedExercises.isEmpty)
    try await repo.archiveExercise(id: exercise.id)
    do {
      try await repo.saveExercise(exercise)
      XCTFail("A stale editor must not resurrect an archived exercise")
    } catch {}
    let saved = try await repo.snapshot()
    XCTAssertEqual(saved.archivedExercises, [exercise])
    XCTAssertFalse(saved.exercises.contains { $0.id == exercise.id })
  }

  func testSchemaTwentyMigrationAndVersionNineBackupKeepExistingData() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    try await repo.addHistoricalWorkout(
      draft("past", ids: ["chin-ups"]), now: now, calendar: calendar)
    let original = try await repo.exportTraining(now: now)
    var raw = try XCTUnwrap(
      JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any])
    raw["version"] = 9
    let legacy = try TrainingArchive.decode(
      JSONSerialization.data(withJSONObject: removingNewTrainingFields(raw)))
    XCTAssertEqual(legacy.contents, original.contents)
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TABLE archived_exercises")
    try db.execute("PRAGMA user_version=20")
    let migrated = try RepsRepository(path: path)
    let preserved = try await migrated.exportTraining(now: now)
    XCTAssertEqual(preserved.contents, original.contents)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 21)
  }

  func testTransferRejectsDuplicateOverlappingAndMalformedArchives() async throws {
    let repo = try RepsRepository(path: ":memory:")
    try await repo.archiveExercise(id: "chin-ups")
    let original = try await repo.exportTraining(now: now)
    let exercise = try XCTUnwrap(original.contents.configuration.archivedExercises.first)
    var duplicate = original
    duplicate.contents.configuration.archivedExercises.append(exercise)
    XCTAssertThrowsError(try duplicate.encoded())
    var overlap = original
    overlap.contents.configuration.exercises.append(exercise)
    XCTAssertThrowsError(try overlap.encoded())
    var invalid = original
    invalid.contents.configuration.archivedExercises[0].setCount = 0
    XCTAssertThrowsError(try invalid.encoded())
  }

  func testArchiveLimitRefusesBeforeMakingBackupUnexportable() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try RepsRepository(path: path)
    let before = try await repo.snapshot()
    let exercise = try XCTUnwrap(before.exercises.first)
    let db = try SQLiteDatabase(path: path)
    try db.transaction {
      for index in 0..<1000 {
        var archived = exercise
        archived.id = "archived-\(index)"
        try db.execute(
          "INSERT INTO archived_exercises VALUES(?,?)",
          [
            .text(archived.id),
            .text(String(decoding: try JSONEncoder().encode(archived), as: UTF8.self)),
          ])
      }
    }
    do {
      try await repo.archiveExercise(id: exercise.id)
      XCTFail("Archive limit must preserve an exportable configuration")
    } catch {}
    let after = try await repo.snapshot()
    XCTAssertEqual(after.archivedExercises.count, 1000)
    XCTAssertTrue(after.exercises.contains(exercise))
    _ = try await repo.exportTraining(now: now)
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
    try await repo.archiveExercise(id: "chin-ups")
    let original = try await repo.workout(id: "only")
    let originalConfiguration = try await repo.snapshot()
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
    let retainedConfiguration = try await repo.snapshot()
    XCTAssertEqual(retainedConfiguration, originalConfiguration)
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
