import Foundation
import XCTest

@testable import RepsCore

final class BodyWeightTransferTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_892_800_000
  func weight(_ id: String = "weight") -> BodyWeightMeasurement {
    BodyWeightMeasurement(id: id, dayKey: "2026-10-12", grams: 72_450)
  }
  func setup(_ r: RepsRepository) async throws {
    try await r.saveBodyWeight(weight(), original: nil, now: now)
    var prefs = try await r.reminderContext().preferences
    prefs.weightEnabled = true
    prefs.weightWeekday = 2
    prefs.weightMinutes = 8 * 60 + 15
    try await r.saveNotificationPreferences(prefs)
  }
  func legacyData(_ archive: TrainingArchive, version: Int) throws -> Data {
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
    root["version"] = version
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    contents.removeValue(forKey: "bodyWeights")
    var prefs = try XCTUnwrap(contents["notifications"] as? [String: Any])
    for key in ["weightEnabled", "weightWeekday", "weightMinutes"] {
      prefs.removeValue(forKey: key)
    }
    contents["notifications"] = prefs
    if version == 1 {
      var config = try XCTUnwrap(contents["configuration"] as? [String: Any])
      var schedules = try XCTUnwrap(config["schedules"] as? [[String: Any]])
      for i in schedules.indices {
        schedules[i].removeValue(forKey: "setCounts")
        schedules[i].removeValue(forKey: "goals")
      }
      config["schedules"] = schedules
      contents["configuration"] = config
    }
    root["contents"] = contents
    return try JSONSerialization.data(withJSONObject: removingNewTrainingFields(root))
  }
  func testVersionThreeRoundTripRestoresWeightsAndReminder() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await setup(r)
    let archive = try await r.exportTraining(now: now)
    XCTAssertEqual(archive.version, 9)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let destination = try RepsRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: now)
    try await destination.applyTrainingImport(preview, now: now)
    let weights = try await destination.bodyWeightMeasurements()
    let prefs = try await destination.reminderContext().preferences
    XCTAssertEqual(weights, [weight()])
    XCTAssertTrue(prefs.weightEnabled)
    XCTAssertEqual(prefs.weightWeekday, 2)
    XCTAssertEqual(prefs.weightMinutes, 495)
  }
  func testOldArchivesPreserveWeightDataAndReminder() async throws {
    for version in [1, 2] {
      let destination = try RepsRepository(path: ":memory:")
      try await setup(destination)
      let source = try RepsRepository(path: ":memory:")
      try await source.saveRest(seconds: 60)
      let old = try await source.exportTraining(now: now)
      let decoded = try TrainingArchive.decode(legacyData(old, version: version))
      let preview = try await destination.previewArchiveImport(decoded, now: now)
      XCTAssertTrue(preview.preservesBodyWeight)
      try await destination.applyTrainingImport(preview, now: now)
      let weights = try await destination.bodyWeightMeasurements()
      let prefs = try await destination.reminderContext().preferences
      let config = try await destination.snapshot()
      XCTAssertEqual(weights, [weight()])
      XCTAssertTrue(prefs.weightEnabled)
      XCTAssertEqual(prefs.weightMinutes, 495)
      XCTAssertEqual(config.restSeconds, 60)
    }
  }
  func testCSVReplacementKeepsBodyWeightsAndReminder() async throws {
    let r = try RepsRepository(path: ":memory:")
    try await setup(r)
    let manual = ManualWorkout(
      id: "past", name: "Past", performedAt: now - 86_400_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: "chin-ups", tracking: .repetitions,
          sets: [ManualWorkoutSet(repetitions: 8, weightGrams: 0)], feelingTenths: 80)
      ])
    try await r.addHistoricalWorkout(manual, now: now)
    let preview = try await r.previewCSVImport([], now: now)
    XCTAssertFalse(preview.isUnchanged)
    try await r.applyTrainingImport(preview, now: now)
    let records = try await r.bodyWeightMeasurements()
    let prefs = try await r.reminderContext().preferences
    let overview = try await r.workoutOverview(now: now)
    XCTAssertEqual(records, [weight()])
    XCTAssertTrue(prefs.weightEnabled)
    XCTAssertTrue(overview.history.isEmpty)
  }
  func testCorruptArchiveAndSQLFailureCannotPartiallyReplaceWeights() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await setup(r)
    let original = try await r.exportTraining(now: now)
    var corrupt = original
    corrupt.contents.bodyWeights += [weight("duplicate")]
    XCTAssertThrowsError(try corrupt.encoded())
    let source = try RepsRepository(path: ":memory:")
    try await source.saveBodyWeight(
      BodyWeightMeasurement(id: "incoming", dayKey: "2026-10-12", grams: 71000), original: nil,
      now: now)
    let incoming = try await source.exportTraining(now: now)
    let preview = try await r.previewArchiveImport(incoming, now: now)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER fail_weight BEFORE INSERT ON body_weight_measurements BEGIN SELECT RAISE(ABORT,'test'); END"
    )
    do {
      try await r.applyTrainingImport(preview, now: now)
      XCTFail("Partial restore accepted")
    } catch {}
    let after = try await r.exportTraining(now: now)
    XCTAssertEqual(after.contents, original.contents)
    let recovery = try await r.recoveryArchive()
    XCTAssertNil(recovery)
  }
  func testMigrationElevenPreservesConfigurationAndActiveWorkout() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    try await r.saveRest(seconds: 97)
    let before = try await r.snapshot()
    let active = try await r.startWorkout(scheduleID: "legs", now: now)
    let db = try SQLiteDatabase(path: path)
    try db.execute("DROP TABLE body_weight_measurements")
    for column in ["weight_enabled", "weight_weekday", "weight_minutes"] {
      try db.execute("ALTER TABLE notification_preferences DROP COLUMN \(column)")
    }
    try db.execute("ALTER TABLE preferences DROP COLUMN stretching_enabled")
    try db.execute("PRAGMA user_version=11")
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.snapshot()
    let restored = try await reopened.workout(id: active.id)
    let prefs = try await reopened.reminderContext().preferences
    let weights = try await reopened.bodyWeightMeasurements()
    XCTAssertEqual(after, before)
    XCTAssertEqual(restored, active)
    XCTAssertFalse(prefs.weightEnabled)
    XCTAssertNil(prefs.weightWeekday)
    XCTAssertNil(prefs.weightMinutes)
    XCTAssertTrue(weights.isEmpty)
  }
}
