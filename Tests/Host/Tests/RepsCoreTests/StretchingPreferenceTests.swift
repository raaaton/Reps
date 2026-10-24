import Foundation
import XCTest

@testable import RepsCore

extension WorkoutSupportTests {
  func testStretchingPreferencePersistsAndOnlyChangesNewWorkoutSnapshots() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let initial = try await r.snapshot()
    XCTAssertTrue(initial.stretchingEnabled)
    let original = try await guided(r)
    try await r.saveStretching(enabled: false)
    let reopened = try RepsRepository(path: path)
    let saved = try await reopened.snapshot()
    XCTAssertFalse(saved.stretchingEnabled)
    let unchanged = try await reopened.workout(id: original.id)
    XCTAssertEqual(unchanged, original)
    try await reopened.cancelWorkout(id: original.id, now: now + 1000)
    let disabled = try await guided(reopened)
    XCTAssertEqual(disabled.support?.steps.map(\.kind), [.warmUp, .warmUp])
    try await reopened.saveStretching(enabled: true)
    let stillDisabled = try await reopened.workout(id: disabled.id)
    XCTAssertEqual(stillDisabled, disabled)
    try await reopened.cancelWorkout(id: disabled.id, now: now + 1000)
    let enabled = try await guided(reopened)
    XCTAssertEqual(enabled.support?.steps.map(\.kind), [.warmUp, .warmUp, .stretch])
  }

  func testStretchingPreferenceAppliesToEverySchedule() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await r.saveStretching(enabled: false)
    let dates = [("legs", now + 2 * 86_400_000), ("push", now + 6 * 86_400_000), ("pull-abs", now)]
    for (id, date) in dates {
      let w = try await r.startWorkout(
        scheduleID: id, now: date, calendar: calendar, includeSupport: true)
      XCTAssertFalse(try XCTUnwrap(w.support).steps.contains { $0.kind == .stretch })
      XCTAssertEqual(w.currentSupport?.kind, .warmUp)
      try await r.cancelWorkout(id: w.id, now: date + 1000)
    }
  }

  func testStretchingSettingRestoresFromJSONAndCSVPreservesIt() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await r.saveStretching(enabled: false)
    let archive = try await r.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let destination = try RepsRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: now)
    try await destination.applyTrainingImport(preview, now: now)
    let saved = try await destination.snapshot()
    XCTAssertFalse(saved.stretchingEnabled)
    let csvPreview = try await destination.previewCSVImport([], now: now)
    try await destination.applyTrainingImport(csvPreview, now: now)
    let afterCSV = try await destination.snapshot()
    XCTAssertFalse(afterCSV.stretchingEnabled)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    object["version"] = 4
    var contents = try XCTUnwrap(object["contents"] as? [String: Any])
    var configuration = try XCTUnwrap(contents["configuration"] as? [String: Any])
    configuration.removeValue(forKey: "stretchingEnabled")
    contents["configuration"] = configuration
    object["contents"] = contents
    let legacy = try TrainingArchive.decode(
      JSONSerialization.data(withJSONObject: removingNewTrainingFields(object)))
    XCTAssertTrue(legacy.contents.configuration.stretchingEnabled)
  }

  func testStretchingMigrationPreservesConfigurationAndExistingSupport() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await r.saveRest(seconds: 137)
    let w = try await guided(r)
    let before = try await r.snapshot()
    let db = try SQLiteDatabase(path: path)
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=15")
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.snapshot()
    XCTAssertEqual(after, before)
    let active = try await reopened.workout(id: w.id)
    XCTAssertEqual(active, w)
  }

  // Removing stretches must not let the final warm-up finish the entire workout.
  func testWarmupOnlyWorkoutRequiresWorkingSetsThenFinishesAtFeeling() async throws {
    let r = try RepsRepository(path: ":memory:")
    let original = try await guided(r)
    var support = try XCTUnwrap(original.support)
    support.steps.removeAll { $0.kind == .stretch }
    try await r.writeSupport(support, workoutID: original.id)
    let (w, time) = try await warm(r, original)
    XCTAssertEqual(w.status, .active)
    let e = try XCTUnwrap(w.currentExercise)
    try await r.beginSet(workoutID: w.id, exerciseID: e.id, number: 1, now: time)
    try await r.recordSet(
      workoutID: w.id, exerciseID: e.id, number: 1, repetitions: 10,
      weightGrams: 0, now: time + 1000)
    try await r.saveFeeling(workoutID: w.id, exerciseID: e.id, tenths: 70, now: time + 2000)
    let finished = try await r.workout(id: w.id)
    XCTAssertEqual(finished.status, .completed)
    XCTAssertEqual(finished.endedAt, time + 2000)
    XCTAssertNil(finished.currentSupport)
    XCTAssertEqual(finished.support?.steps.count, 2)
    let archive = try await r.exportTraining(now: time + 3000)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.contents.workouts.first, finished)
    let csv = try TrainingCSV.decode(TrainingCSV.encode([finished]))
    XCTAssertEqual(csv.first, finished)
  }

  func testWarmupOnlySupportValidatesWithOneOrTwoSetsButRejectsMissingWarmup() async throws {
    let r = try RepsRepository(path: ":memory:")
    var w = try await guided(r)
    var support = try XCTUnwrap(w.support)
    support.steps.removeAll { $0.kind == .stretch }
    w.support = support
    XCTAssertNoThrow(try support.validate(workout: w))
    support.steps = [
      WorkoutSupportStep(
        id: "weighted-warmup", kind: .warmUp, name: "Chin-ups", instructions: "Bodyweight",
        number: 1, count: 1, tracking: .repetitions, targetRepetitions: 8,
        targetDurationMS: nil, restAfterMS: 180_000)
    ]
    XCTAssertNoThrow(try support.validate(workout: w))
    support.steps = []
    XCTAssertThrowsError(try support.validate(workout: w))
  }
}
