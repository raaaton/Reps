import Foundation
import XCTest

@testable import SportCore

final class TrainingTransferTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000
  func history(_ r: SportRepository, id: String = "fixture") async throws {
    try await r.addHistoricalWorkout(
      ManualWorkout(
        id: id, name: "=Séance, \"été\"\nDeuxième ligne", performedAt: now - 86_400_000,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: "chin-ups", tracking: .repetitions,
            sets: [ManualWorkoutSet(repetitions: 12, weightGrams: 2375)], feelingTenths: 73)
        ]), now: now)
  }
  func testJSONAndCSVRoundTripPreserveSnapshotsAndExactHistoricalDecimals() async throws {
    let r = try SportRepository(path: ":memory:")
    try await history(r)
    let archive = try await r.exportTraining(now: now)
    let encoded = try archive.encoded()
    let restored = try TrainingArchive.decode(encoded)
    XCTAssertEqual(restored, archive)
    let csv = try TrainingCSV.encode(archive.contents.workouts)
    XCTAssertTrue(String(decoding: csv, as: UTF8.self).contains("'=Séance"))
    let workouts = try TrainingCSV.decode(csv)
    XCTAssertEqual(workouts, archive.contents.workouts)
    XCTAssertEqual(workouts.first?.exercises.first?.feelingTenths, 73)
    XCTAssertEqual(workouts.first?.exercises.first?.sets.first?.weightGrams, 2375)
    XCTAssertFalse(String(decoding: csv, as: UTF8.self).contains("photos"))
  }
  func testCSVImportReplacesOnlyHistoryAndSecondImportIsIdempotent() async throws {
    let source = try SportRepository(path: ":memory:")
    try await history(source)
    let records = try await source.exportTraining(now: now).contents.workouts
    let target = try SportRepository(path: ":memory:")
    let baseline = try await target.snapshot()
    let preview = try await target.previewCSVImport(records, now: now)
    XCTAssertEqual(preview.workoutCount, 1)
    try await target.applyTrainingImport(preview, now: now)
    let after = try await target.snapshot()
    XCTAssertEqual(after, baseline)
    let again = try await target.previewCSVImport(records, now: now)
    XCTAssertEqual(again.workoutCount, 1)
    XCTAssertEqual(again.replacedCount, 1)
    XCTAssertTrue(again.isUnchanged)
    XCTAssertEqual(again.identicalCount, 1)
    try await target.applyTrainingImport(again, now: now)
    let overview = try await target.workoutOverview(now: now)
    XCTAssertEqual(overview.history.count, 1)
    let recovery = try await target.recoveryArchive()
    XCTAssertEqual(recovery?.contents.workouts.count, 0)
  }
  func testRestoreKeepsRecoveryAndRejectsStalePreviewWithoutChangingData() async throws {
    let r = try SportRepository(path: ":memory:")
    let original = try await r.exportTraining(now: now)
    try await history(r)
    try await r.saveRest(seconds: 90)
    let before = try await r.exportTraining(now: now)
    let preview = try await r.previewArchiveImport(original, now: now)
    try await r.saveRest(seconds: 60)
    do {
      try await r.applyTrainingImport(preview, now: now)
      XCTFail("Stale restore accepted")
    } catch {}
    let current = try await r.snapshot()
    XCTAssertEqual(current.restSeconds, 60)
    let ready = try await r.previewArchiveImport(original, now: now)
    try await r.applyTrainingImport(ready, now: now)
    let result = try await r.exportTraining(now: now)
    XCTAssertEqual(result.contents, original.contents)
    let storedRecovery = try await r.recoveryArchive()
    let recovery = try XCTUnwrap(storedRecovery)
    XCTAssertEqual(recovery.contents.workouts, before.contents.workouts)
    XCTAssertEqual(recovery.contents.configuration.restSeconds, 60)
  }
  func testCSVReplacesOldConflictingIDsButRejectsDuplicatesWithinFile() async throws {
    let r = try SportRepository(path: ":memory:")
    try await history(r)
    let archive = try await r.exportTraining(now: now)
    var changed = archive.contents.workouts[0]
    changed = WorkoutSession(
      id: changed.id, scheduleID: changed.scheduleID, name: "different", dayKey: changed.dayKey,
      startedAt: changed.startedAt, endedAt: changed.endedAt, status: changed.status,
      restSeconds: changed.restSeconds, exercises: changed.exercises, rest: nil)
    let preview = try await r.previewCSVImport([changed], now: now)
    try await r.applyTrainingImport(preview, now: now)
    let after = try await r.exportTraining(now: now)
    XCTAssertEqual(after.contents.workouts, [changed])
    let recovery = try await r.recoveryArchive()
    XCTAssertEqual(recovery?.contents, archive.contents)
    do {
      _ = try await r.previewCSVImport([changed, changed], now: now)
      XCTFail("Duplicate IDs within the file accepted")
    } catch {}
    let unchanged = try await r.exportTraining(now: now)
    XCTAssertEqual(unchanged.contents, after.contents)
    let csv = try TrainingCSV.encode(archive.contents.workouts)
    let truncated = csv.dropLast(5)
    XCTAssertThrowsError(try TrainingCSV.decode(Data(truncated)))
    XCTAssertThrowsError(try TrainingCSV.decode(Data("wrong,headers\n1,2".utf8)))
  }
  func testActiveWorkoutAndPrivatePhotoManifestAreRefused() async throws {
    let r = try SportRepository(path: ":memory:")
    let empty = try await r.exportTraining(now: now)
    let csvPreview = try await r.previewCSVImport([], now: now)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    _ = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    do {
      _ = try await r.exportTraining(now: now)
      XCTFail("Active export truncated")
    } catch {}
    do {
      _ = try await r.previewArchiveImport(empty, now: now)
      XCTFail("Active restore accepted")
    } catch {}
    do {
      _ = try await r.previewCSVImport([], now: now)
      XCTFail("Active CSV replacement accepted")
    } catch {}
    do {
      try await r.applyTrainingImport(csvPreview, now: now)
      XCTFail("CSV preview bypassed active workout guard")
    } catch {}
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: empty.encoded()) as? [String: Any])
    object["includesPrivatePhotos"] = true
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: object)))
    object["includesPrivatePhotos"] = false
    object["version"] = 999
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: object)))
  }
  func testEmptyCSVIsReadableAndUnknownPrivatePayloadIsRejected() async throws {
    XCTAssertEqual(try TrainingCSV.decode(TrainingCSV.encode([])), [])
    let r = try SportRepository(path: ":memory:")
    let archive = try await r.exportTraining(now: now)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    object["privatePhotos"] = ["not-training-data"]
    XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: object)))
  }
  func testCancelledTimedPreparationAndGoalsSurviveBothFormatsAndRestore() async throws {
    let r = try SportRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await r.saveSchedule(schedule)
    let context = try await r.goalContext(exerciseID: "l-sit")
    var goal = try XCTUnwrap(context.suggestion?.goal)
    goal.load = try XCTUnwrap(
      WeightInventory.loads(items: snapshot.weightItems).first { $0.grams == 3900 })
    try await r.saveGoal(goal, original: nil)
    try await r.saveNotificationPreferences(
      NotificationPreferences(workoutsEnabled: true, photosEnabled: true, photoMinutes: 377))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let workout = try await r.startWorkout(scheduleID: schedule.id, now: now, calendar: calendar)
    let ex = try XCTUnwrap(workout.currentExercise)
    try await r.beginSet(
      workoutID: workout.id, exerciseID: ex.id, number: 1, weightGrams: goal.load.grams,
      load: goal.load, now: now)
    try await r.cancelWorkout(id: workout.id, now: now + 1000)
    let archive = try await r.exportTraining(now: now + 1000)
    XCTAssertEqual(
      try TrainingCSV.decode(TrainingCSV.encode(archive.contents.workouts)),
      archive.contents.workouts)
    let target = try SportRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(
      TrainingArchive.decode(archive.encoded()), now: now + 2000)
    try await target.applyTrainingImport(preview, now: now + 2000)
    let after = try await target.exportTraining(now: now + 2000)
    XCTAssertEqual(after.contents, archive.contents)
    let restored = try await target.workout(id: workout.id)
    XCTAssertEqual(restored.phase(at: now + 5000), .cancelled)
    XCTAssertNil(restored.rest)
  }

  func testNoncanonicalCalendarKeyAndOverwideCSVAreRejected() async throws {
    let r = try SportRepository(path: ":memory:")
    try await history(r)
    let archive = try await r.exportTraining(now: now)
    let old = archive.contents.workouts[0]
    let invalid = WorkoutSession(
      id: "new-date", scheduleID: old.scheduleID, name: old.name, dayKey: "2026-1-001",
      startedAt: old.startedAt, endedAt: old.endedAt, status: old.status,
      restSeconds: old.restSeconds, exercises: old.exercises, rest: nil)
    do {
      _ = try await r.previewCSVImport([invalid], now: now)
      XCTFail("Noncanonical date accepted")
    } catch {}
    let wide = Data(
      (TrainingCSV.columns.joined(separator: ",") + "\n" + String(repeating: ",", count: 1_000_000))
        .utf8)
    XCTAssertThrowsError(try TrainingCSV.decode(wide))
  }
  func testReplacementArchiveLimitRefusesImportAndPreservesExistingRecovery() async throws {
    let r = try SportRepository(path: ":memory:")
    func large(_ id: String) -> WorkoutSession {
      let def = TrainingExercise(
        id: "chin-ups", name: "Chin-ups", tracking: .repetitions, setCount: 1000, minimumReps: 8,
        maximumReps: 12, durationSeconds: nil, isEnabled: true)
      let component = LoadComponent(
        id: "unknown-old", name: String(repeating: "a", count: 3500), grams: 2375)
      let sets = (1...1000).map {
        WorkoutSet(
          id: "\(id)-set-\($0)", number: $0, repetitions: 10, durationMS: nil, weightGrams: 2375,
          completedAt: now, components: [component])
      }
      let exercise = WorkoutExercise(
        id: "\(id)-ex", definition: def, sets: sets, feelingTenths: 75, setStartedAt: nil,
        setWeightGrams: nil, setEndedAt: nil)
      return WorkoutSession(
        id: id, scheduleID: "manual", name: id, dayKey: "2026-10-11", startedAt: now, endedAt: now,
        status: .completed, restSeconds: 180, exercises: [exercise], rest: nil)
    }
    let first = try await r.previewCSVImport([large("one"), large("two")], now: now)
    try await r.applyTrainingImport(first, now: now)
    let before = try await r.exportTraining(now: now)
    let previousRecovery = try await r.recoveryArchive()
    do {
      _ = try await r.previewCSVImport([large("three"), large("four"), large("five")], now: now)
      XCTFail("Import makes archive unrecoverable")
    } catch {}
    let after = try await r.exportTraining(now: now)
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertNoThrow(try after.encoded())
    let recovery = try await r.recoveryArchive()
    XCTAssertEqual(recovery, previousRecovery)
  }
  func testForcedSQLFailureRollsBackNewRowsAndRecoverySnapshot() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let source = try SportRepository(path: ":memory:")
    try await history(source, id: "first")
    let target = try SportRepository(path: path)
    let first = try await source.exportTraining(now: now)
    let initial = try await target.previewCSVImport(first.contents.workouts, now: now)
    try await target.applyTrainingImport(initial, now: now)
    let before = try await target.exportTraining(now: now)
    let oldRecovery = try await target.recoveryArchive()
    try await history(source, id: "second")
    let next = try await source.exportTraining(now: now)
    let preview = try await target.previewCSVImport(next.contents.workouts, now: now)
    let fixture = try SQLiteDatabase(path: path)
    try fixture.execute(
      "CREATE TRIGGER reject_transfer BEFORE INSERT ON workout_sets BEGIN SELECT RAISE(ABORT,'fixture'); END"
    )
    do {
      try await target.applyTrainingImport(preview, now: now)
      XCTFail("Injected failure ignored")
    } catch {}
    let after = try await target.exportTraining(now: now)
    let recovery = try await target.recoveryArchive()
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertEqual(recovery, oldRecovery)
  }
  func testBundledFixtureImportsAllRowsAndExercisesAndCanBeExportedAgain() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    let file = root.appendingPathComponent("docs/fixtures/Sport-demo-2026.csv")
    let csv = try Data(contentsOf: file)
    let records = try TrainingCSV.decode(csv)
    XCTAssertEqual(records.count, 117)
    XCTAssertEqual(records.flatMap(\.exercises).flatMap(\.sets).count, 752)
    let r = try SportRepository(path: ":memory:")
    let preview = try await r.previewCSVImport(records, now: now + 86_400_000)
    try await r.applyTrainingImport(preview, now: now + 86_400_000)
    let archive = try await r.exportTraining(now: now + 86_400_000)
    XCTAssertEqual(
      try TrainingCSV.decode(TrainingCSV.encode(archive.contents.workouts)),
      archive.contents.workouts)
    let overview = try await r.workoutOverview(now: now + 86_400_000)
    let days = TrainingAnalytics.attendance(
      history: overview.history,
      ending: WorkoutClock.date(now + 86_400_000))
    XCTAssertTrue(days.contains { $0.state == .completed })
    XCTAssertTrue(days.contains { $0.state == .partial })
  }

  func testCSVReplacementLeavesOnlyImportedHistoryAndRetainsAllSettingsAndRecovery() async throws {
    let source = try SportRepository(path: ":memory:")
    try await history(source, id: "incoming")
    let incoming = try await source.exportTraining(now: now).contents.workouts
    let target = try SportRepository(path: ":memory:")
    try await history(target, id: "old-one")
    try await history(target, id: "old-two")
    try await target.saveRest(seconds: 90)
    try await target.saveNotificationPreferences(
      NotificationPreferences(workoutsEnabled: true, photosEnabled: false, photoMinutes: 377))
    let goalContext = try await target.goalContext(exerciseID: "chin-ups")
    let goal = try XCTUnwrap(goalContext.suggestion?.goal)
    try await target.saveGoal(goal, original: nil)
    let before = try await target.exportTraining(now: now)
    let preview = try await target.previewCSVImport(incoming, now: now)
    XCTAssertEqual(preview.replacedCount, 2)
    XCTAssertEqual(preview.workoutCount, 1)
    XCTAssertFalse(preview.isUnchanged)
    // Preview and cancellation must leave everything intact.
    let afterPreview = try await target.exportTraining(now: now)
    XCTAssertEqual(afterPreview.contents, before.contents)
    try await target.applyTrainingImport(preview, now: now)
    let after = try await target.exportTraining(now: now)
    XCTAssertEqual(after.contents.workouts, incoming)
    XCTAssertEqual(after.contents.configuration, before.contents.configuration)
    XCTAssertEqual(after.contents.notifications, before.contents.notifications)
    let recovery = try await target.recoveryArchive()
    XCTAssertEqual(recovery?.contents, before.contents)
    let restore = try await target.previewArchiveImport(XCTUnwrap(recovery), now: now)
    try await target.applyTrainingImport(restore, now: now)
    let restored = try await target.exportTraining(now: now)
    XCTAssertEqual(restored.contents, before.contents)
  }
  func testCSVEmptyReplacementAndStalePreviewRemainSafe() async throws {
    let r = try SportRepository(path: ":memory:")
    try await history(r)
    let before = try await r.exportTraining(now: now)
    let stale = try await r.previewCSVImport([], now: now)
    try await r.saveRest(seconds: 60)
    do {
      try await r.applyTrainingImport(stale, now: now)
      XCTFail("Stale CSV replacement accepted")
    } catch {}
    let unchanged = try await r.exportTraining(now: now)
    XCTAssertEqual(unchanged.contents.workouts, before.contents.workouts)
    let preview = try await r.previewCSVImport([], now: now)
    try await r.applyTrainingImport(preview, now: now)
    let empty = try await r.exportTraining(now: now)
    XCTAssertTrue(empty.contents.workouts.isEmpty)
    XCTAssertEqual(empty.contents.configuration.restSeconds, 60)
    let backup = try await r.recoveryArchive()
    XCTAssertEqual(backup?.contents, unchanged.contents)
  }

  func testReorderedIdenticalCSVDoesNotReplaceExistingRecovery() async throws {
    let source = try SportRepository(path: ":memory:")
    try await history(source, id: "a")
    try await history(source, id: "b")
    let incoming = try await source.exportTraining(now: now).contents.workouts
    let target = try SportRepository(path: ":memory:")
    try await history(target, id: "previous-data")
    let initial = try await target.previewCSVImport(incoming, now: now)
    try await target.applyTrainingImport(initial, now: now)
    let before = try await target.exportTraining(now: now)
    let recoveryBefore = try await target.recoveryArchive()
    XCTAssertEqual(recoveryBefore?.contents.workouts.map(\.id), ["previous-data"])
    let reordered = try await target.previewCSVImport(Array(incoming.reversed()), now: now)
    XCTAssertTrue(reordered.isUnchanged)
    try await target.applyTrainingImport(reordered, now: now + 1000)
    let after = try await target.exportTraining(now: now)
    let recoveryAfter = try await target.recoveryArchive()
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertEqual(recoveryAfter, recoveryBefore)
  }

}
