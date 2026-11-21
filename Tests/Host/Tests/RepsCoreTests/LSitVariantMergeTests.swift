import Foundation
import XCTest

@testable import RepsCore

final class LSitVariantMergeTests: XCTestCase, @unchecked Sendable {
  let now = 1_794_096_000_000
  func fixture(path: String = ":memory:", bothAssigned: Bool = false) async throws -> RepsRepository
  {
    let repository = try RepsRepository(path: path)
    let v = TrainingExercise(
      id: "actual-v-uuid", name: "V-sit", tracking: .duration,
      setCount: 4, minimumReps: nil, maximumReps: nil, durationSeconds: 30, isEnabled: true)
    try await repository.saveExercise(v)
    try await repository.addHistoricalWorkout(
      ManualWorkout(
        id: "both", name: "Both", performedAt: now,
        exercises: ["l-sit", v.id].map {
          ManualWorkoutExercise(
            catalogueID: $0, tracking: .duration,
            sets: [ManualWorkoutSet(durationMS: $0 == v.id ? 15000 : 30000, weightGrams: 0)],
            feelingTenths: 60)
        }), now: now)
    if !bothAssigned { try await repository.archiveExercise(id: "l-sit") }
    let configuration = try await repository.snapshot()
    var schedule = try XCTUnwrap(configuration.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = bothAssigned ? ["l-sit", v.id] : [v.id]
    schedule.setCounts = bothAssigned ? ["l-sit": 3, v.id: 5] : [v.id: 5]
    try await repository.saveSchedule(schedule)
    return repository
  }
  func testArchivedParentDualHistoryAndProgramsSurviveMergeAndSecondExecution() async throws {
    let repository = try await fixture()
    let before = try await repository.workout(id: "both")
    let recovery = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .path
    defer { try? FileManager.default.removeItem(atPath: recovery) }
    let manifest = LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid")
    let merged = try await repository.mergeLSitAndVSit(manifest, recoveryPath: recovery)
    XCTAssertTrue(merged)
    XCTAssertTrue(FileManager.default.fileExists(atPath: recovery))
    let after = try await repository.workout(id: "both")
    XCTAssertEqual(after.id, before.id)
    XCTAssertEqual(after.exercises.map(\.id), before.exercises.map(\.id))
    XCTAssertEqual(
      after.exercises.flatMap(\.sets).map(\.id), before.exercises.flatMap(\.sets).map(\.id))
    XCTAssertEqual(
      after.exercises.map { $0.definition.name }, before.exercises.map { $0.definition.name })
    let snapshot = try await repository.snapshot()
    XCTAssertTrue(snapshot.exercises.contains { $0.id == "l-sit" && $0.isEnabled })
    XCTAssertFalse(snapshot.exercises.contains { $0.id == "actual-v-uuid" })
    let program = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    XCTAssertEqual(snapshot.exercises(for: program).first?.variantID, "actual-v-uuid:base")
    XCTAssertEqual(snapshot.exercises(for: program).first?.setCount, 5)
    let l = try await repository.exerciseHistory(exerciseID: "l-sit", variantID: "l-sit:base")
    let v = try await repository.exerciseHistory(
      exerciseID: "l-sit", variantID: "actual-v-uuid:base")
    XCTAssertEqual(l.count, 1)
    XCTAssertEqual(v.count, 1)
    XCTAssertEqual(v.first?.exercise.sets.first?.durationMS, 15000)
    let repeated = try await repository.mergeLSitAndVSit(manifest, recoveryPath: recovery)
    XCTAssertFalse(repeated)
    let final = try await repository.snapshot()
    XCTAssertEqual(final, snapshot)
    let archive = try await repository.exportTraining(now: now)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(
      TrainingArchive.decode(archive.encoded()), now: now)
    try await target.applyTrainingImport(preview, now: now)
    let restoredRepeated = try await target.mergeLSitAndVSit(manifest, recoveryPath: recovery)
    XCTAssertFalse(restoredRepeated)
  }
  func testActiveWorkoutDefersAndIncorrectIDsNeverMerge() async throws {
    let repository = try await fixture()
    let active = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    let before = try await repository.snapshot()
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let deferred = try await repository.mergeLSitAndVSit(
      LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid"), recoveryPath: path)
    XCTAssertFalse(deferred)
    let after = try await repository.snapshot()
    XCTAssertEqual(before, after)
    let retained = try await repository.workout(id: active.id)
    XCTAssertEqual(retained, active)
    do {
      _ = try await repository.mergeLSitAndVSit(
        LSitMergeManifest(lSitID: "unknown", vSitID: "actual-v-uuid"), recoveryPath: path)
      XCTFail("An unknown explicit identity must be rejected")
    } catch {}
  }
  func testBothProgramAssignmentsAreRetained() async throws {
    let repository = try await fixture(bothAssigned: true)
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    _ = try await repository.mergeLSitAndVSit(
      LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid"), recoveryPath: path)
    let snapshot = try await repository.snapshot()
    let program = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    let entries = snapshot.exercises(for: program)
    XCTAssertEqual(entries.map(\.variantID), ["l-sit:base", "actual-v-uuid:base"])
    XCTAssertEqual(entries.map(\.setCount), [3, 5])
    try await repository.saveSchedule(program)
  }
}

extension LSitVariantMergeTests {
  func testTransactionFailureKeepsAllOriginalDataAndRecoveryFile() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    let recovery = path + ".recovery"
    defer {
      try? FileManager.default.removeItem(atPath: path)
      try? FileManager.default.removeItem(atPath: recovery)
    }
    let repository = try await fixture(path: path)
    let before = try await repository.exportTraining(now: now)
    let database = try SQLiteDatabase(path: path)
    try database.execute(
      "CREATE TRIGGER refuse_merge BEFORE INSERT ON targeted_exercise_merges BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      _ = try await repository.mergeLSitAndVSit(
        LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid"), recoveryPath: recovery)
      XCTFail("An incomplete merge must roll back")
    } catch {}
    let after = try await repository.exportTraining(now: now)
    XCTAssertEqual(after.contents, before.contents)
    let reopened = try RepsRepository(path: recovery)
    let recovered = try await reopened.exportTraining(now: now)
    XCTAssertEqual(recovered.contents, before.contents)
  }
}

extension LSitVariantMergeTests {
  func testDualProgramGoalsStartAndActiveParentCannotBePurgedThroughLegacyIdentity() async throws {
    let repository = try await fixture(bothAssigned: true)
    for identity in ["l-sit", "actual-v-uuid"] {
      let context = try await repository.goalContext(exerciseID: identity, scheduleID: "pull-abs")
      let goal = ExerciseGoal(
        definition: context.exercise, load: .bodyweight, repetitions: nil,
        durationsMS: Array(
          repeating: identity == "l-sit" ? 15000 : 5000, count: context.exercise.setCount))
      try await repository.saveGoal(goal, original: context.adopted, scheduleID: "pull-abs")
    }
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    _ = try await repository.mergeLSitAndVSit(
      LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid"), recoveryPath: path)
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    XCTAssertEqual(workout.exercises.count, 2)
    XCTAssertEqual(workout.exercises[1].goal?.durationsMS, [5000, 5000, 5000, 5000, 5000])
    try await repository.selectWorkoutVariant(
      workoutID: workout.id, exerciseID: workout.exercises[1].id, variantID: "actual-v-uuid:base")
    let archive = try await repository.exportTraining(now: now)
    _ = try TrainingArchive.decode(archive.encoded())
    do {
      try await repository.deleteArchivedExercise(id: "actual-v-uuid")
      XCTFail("An active progression cannot be purged as an orphan")
    } catch {}
    let history = try await repository.historyExercises()
    XCTAssertEqual(history.filter { $0.id == "l-sit" }.count, 1)
    XCTAssertFalse(history.contains { $0.id == "actual-v-uuid" })
  }
}

extension LSitVariantMergeTests {
  func testProgressPickerChangesOnlyItsSlotAndRetainsBothVariantsGoals() async throws {
    let repository = try await fixture(bothAssigned: true)
    for identity in ["l-sit", "actual-v-uuid"] {
      let context = try await repository.goalContext(exerciseID: identity, scheduleID: "pull-abs")
      let goal = ExerciseGoal(
        definition: context.exercise, load: .bodyweight, repetitions: nil,
        durationsMS: Array(
          repeating: identity == "l-sit" ? 15000 : 5000, count: context.exercise.setCount))
      try await repository.saveGoal(goal, original: context.adopted, scheduleID: "pull-abs")
    }
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    _ = try await repository.mergeLSitAndVSit(
      LSitMergeManifest(lSitID: "l-sit", vSitID: "actual-v-uuid"), recoveryPath: path)
    let before = try await repository.snapshot()
    let parent = try XCTUnwrap(before.exercises.first { $0.id == "l-sit" })
    try await repository.setScheduleVariant(
      scheduleID: "pull-abs", exerciseID: "actual-v-uuid", variantID: "l-sit:base")
    let changed = try await repository.snapshot()
    let targets = changed.workoutTargets(for: parent)
    XCTAssertEqual(targets.count, 2)
    XCTAssertEqual(targets.map { $0.exercise.variantID }, ["l-sit:base", "l-sit:base"])
    XCTAssertEqual(targets.map { $0.exercise.setCount }, [3, 5])
    XCTAssertEqual(targets.last?.goal?.durationsMS, [15000, 15000, 15000, 15000, 15000])
    XCTAssertEqual(changed.variantGoals, before.variantGoals)
    let context = try await repository.goalContext(
      exerciseID: "actual-v-uuid", scheduleID: "pull-abs", variantID: "l-sit:base")
    XCTAssertEqual(context.exercise.setCount, 5)
    XCTAssertEqual(context.adopted?.durationsMS, [15000, 15000, 15000, 15000, 15000])
    try await repository.setScheduleVariant(
      scheduleID: "pull-abs", exerciseID: "l-sit", variantID: "actual-v-uuid:base")
    try await repository.setScheduleVariant(
      scheduleID: "pull-abs", exerciseID: "actual-v-uuid", variantID: "actual-v-uuid:base")
    let final = try await repository.snapshot()
    XCTAssertEqual(
      final.workoutTargets(for: parent).map { $0.exercise.variantID },
      ["actual-v-uuid:base", "actual-v-uuid:base"])
    XCTAssertEqual(final.variantGoals, before.variantGoals)
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    XCTAssertEqual(workout.exercises.map { $0.goal?.durationsMS?.count }, [3, 5])
  }
}
