import Foundation
import XCTest

@testable import RepsCore

final class DurationPrecisionTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  func add(_ r: RepsRepository, values: [Int]) async throws {
    try await r.addHistoricalWorkout(
      ManualWorkout(
        id: "precision", name: "Holds", performedAt: now - 100_000,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: "l-sit", tracking: .duration,
            sets: values.map { ManualWorkoutSet(durationMS: $0, weightGrams: 0) }, feelingTenths: 80
          )
        ]),
      now: now)
  }
  func testStoredSetsRoundNearestTenthAndNeverBecomeZero() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await add(r, values: [12344, 12356, 9999, 1, 50])
    let saved = try await r.workout(id: "precision")
    XCTAssertEqual(
      saved.exercises[0].sets.compactMap(\.durationMS), [12300, 12400, 10000, 100, 100])
    let csv = try TrainingCSV.encode(await r.exportTraining(now: now).contents.workouts)
    let decoded = try TrainingCSV.decode(csv)
    XCTAssertEqual(
      decoded[0].exercises[0].sets.compactMap(\.durationMS), [12300, 12400, 10000, 100, 100])
  }
  func testLegacyCSVImportRoundsResultsBeforeExport() async throws {
    let source = try RepsRepository(path: ":memory:")
    try await add(source, values: [12300])
    let csv = try TrainingCSV.encode(await source.exportTraining(now: now).contents.workouts)
    let legacy = String(decoding: csv, as: UTF8.self).replacingOccurrences(
      of: "\"12.300\"", with: "\"12.356\"")
    let records = try TrainingCSV.decode(Data(legacy.utf8))
    XCTAssertEqual(records[0].exercises[0].sets[0].durationMS, 12356)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewCSVImport(records, now: now)
    try await target.applyTrainingImport(preview, now: now)
    let saved = try await target.exportTraining(now: now)
    XCTAssertEqual(saved.contents.workouts[0].exercises[0].sets[0].durationMS, 12400)
    XCTAssertEqual(saved.contents.workouts[0].endedAt, records[0].endedAt)
  }
  func testMigrationRoundsExistingRowsAndUpdatesButKeepsTimestamps() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await add(r, values: [12300])
    let before = try await r.workout(id: "precision")
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TRIGGER round_duration_insert")
    try db.execute("DROP TRIGGER round_duration_update")
    try db.execute("UPDATE workout_sets SET duration_ms=12356")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=9")
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.workout(id: "precision")
    XCTAssertEqual(after.exercises[0].sets[0].durationMS, 12400)
    XCTAssertEqual(after.exercises[0].sets[0].completedAt, before.exercises[0].sets[0].completedAt)
    XCTAssertEqual(after.startedAt, before.startedAt)
    XCTAssertEqual(after.endedAt, before.endedAt)
    try db.execute("UPDATE workout_sets SET duration_ms=12344")
    XCTAssertEqual(
      try db.query("SELECT duration_ms FROM workout_sets")[0].integer("duration_ms"), 12300)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 19)
    _ = try RepsRepository(path: path)
    XCTAssertEqual(
      try db.query("SELECT duration_ms FROM workout_sets")[0].integer("duration_ms"), 12300)
  }
  func testMigrationFailureRollsBackRowsAndVersion() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await add(r, values: [12300])
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TRIGGER round_duration_insert")
    try db.execute("DROP TRIGGER round_duration_update")
    try db.execute("UPDATE workout_sets SET duration_ms=12344")
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=9")
    try db.execute(
      "CREATE TRIGGER reject_rounding BEFORE UPDATE ON workout_sets BEGIN SELECT RAISE(ABORT,'test'); END"
    )
    XCTAssertThrowsError(try RepsRepository(path: path))
    XCTAssertEqual(
      try db.query("SELECT duration_ms FROM workout_sets")[0].integer("duration_ms"), 12344)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 9)
  }
}
