import Foundation
import XCTest

@testable import RepsCore

final class HistoricalVariantEditingTests: XCTestCase, @unchecked Sendable {
  let now = 1_794_096_000_000
  func setup() async throws -> (RepsRepository, TrainingExercise, ExerciseVariant, WorkoutSession) {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "v"
    variant.name = "V-sit"
    variant.measure = "15"
    variant.unit = "cm"
    variant.durationSeconds = 3
    try await repository.saveVariant(variant)
    try await repository.addHistoricalWorkout(
      ManualWorkout(
        id: "old", name: "Old", performedAt: now,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: parent.id, tracking: .duration,
            sets: [ManualWorkoutSet(durationMS: 15500, weightGrams: 900)], feelingTenths: 65)
        ]), now: now)
    let original = try await repository.workout(id: "old")
    return (repository, parent, variant, original)
  }
  func draft(_ original: WorkoutSession, variantID: String?) -> ManualWorkout {
    ManualWorkout(
      id: original.id, name: original.name, performedAt: original.startedAt,
      exercises: original.exercises.map { exercise in
        ManualWorkoutExercise(
          catalogueID: exercise.definition.id, tracking: exercise.definition.tracking,
          sets: exercise.sets.map {
            ManualWorkoutSet(
              repetitions: $0.repetitions, durationMS: $0.durationMS, weightGrams: $0.weightGrams,
              sourceID: $0.id)
          },
          feelingTenths: exercise.feelingTenths, variantID: variantID)
      })
  }
  func testChangingHistoricalVariantPreservesResultsAndIDsAndMovesOnlyItsHistory() async throws {
    let (repository, parent, variant, original) = try await setup()
    let before = try await repository.snapshot()
    try await repository.updateHistoricalWorkout(
      draft(original, variantID: variant.id), original: original, now: now)
    let changed = try await repository.workout(id: original.id)
    XCTAssertEqual(changed.id, original.id)
    XCTAssertEqual(changed.exercises.first?.id, original.exercises.first?.id)
    XCTAssertEqual(changed.exercises.first?.sets, original.exercises.first?.sets)
    XCTAssertEqual(changed.exercises.first?.feelingTenths, 65)
    XCTAssertEqual(changed.exercises.first?.definition.variantID, variant.id)
    XCTAssertEqual(changed.exercises.first?.definition.variant?.measure, "15")
    XCTAssertEqual(changed.startedAt, original.startedAt)
    XCTAssertEqual(changed.endedAt, original.endedAt)
    let base = try await repository.exerciseHistory(
      exerciseID: parent.id, variantID: parent.variantID)
    let selected = try await repository.exerciseHistory(
      exerciseID: parent.id, variantID: variant.id)
    XCTAssertTrue(base.isEmpty)
    XCTAssertEqual(selected.count, 1)
    let after = try await repository.snapshot()
    XCTAssertEqual(before, after)
    let archive = try await repository.exportTraining(now: now)
    XCTAssertEqual(
      try TrainingCSV.decode(TrainingCSV.encode(archive.contents.workouts)),
      archive.contents.workouts)
    _ = try TrainingArchive.decode(archive.encoded())
  }
  func testArchivedVariantCanBeAssignedAndUnchangedSnapshotDoesNotRename() async throws {
    let (repository, _, variant, original) = try await setup()
    try await repository.archiveVariant(id: variant.id)
    try await repository.updateHistoricalWorkout(
      draft(original, variantID: variant.id), original: original, now: now)
    let changed = try await repository.workout(id: original.id)
    XCTAssertEqual(changed.exercises.first?.definition.variantID, variant.id)
    let current = try XCTUnwrap(changed.exercises.first?.definition)
    let frozen = try await repository.snapshot().historicalDefinition(
      current, selecting: current.variantID)
    XCTAssertEqual(frozen, current)
  }
  func testCrossMetricSelectionRequiresNewValidResultsAndRetainsSetIdentity() async throws {
    let (repository, _, initial, original) = try await setup()
    var variant = initial
    variant.id = "reps"
    variant.name = "Repetitions"
    variant.tracking = .repetitions
    variant.minimumReps = 5
    variant.maximumReps = 8
    variant.durationSeconds = nil
    try await repository.saveVariant(variant)
    var edited = draft(original, variantID: variant.id)
    do {
      try await repository.updateHistoricalWorkout(edited, original: original, now: now)
      XCTFail("Duration values cannot be silently reinterpreted as repetitions")
    } catch {}
    edited.exercises[0].tracking = .repetitions
    edited.exercises[0].sets[0].durationMS = nil
    edited.exercises[0].sets[0].repetitions = 7
    try await repository.updateHistoricalWorkout(edited, original: original, now: now)
    let changed = try await repository.workout(id: original.id)
    XCTAssertEqual(changed.exercises.first?.definition.tracking, .repetitions)
    XCTAssertEqual(
      changed.exercises.first?.sets.first?.id, original.exercises.first?.sets.first?.id)
    XCTAssertEqual(changed.exercises.first?.sets.first?.repetitions, 7)
    XCTAssertNil(changed.exercises.first?.sets.first?.durationMS)
  }
  func testUnknownAndCrossExerciseVariantsAreRejectedAtomically() async throws {
    let (repository, _, _, original) = try await setup()
    for id in ["missing", "chin-ups:base"] {
      do {
        try await repository.updateHistoricalWorkout(
          draft(original, variantID: id), original: original, now: now)
        XCTFail("Only this exercise's progressions are accepted")
      } catch {}
      let after = try await repository.workout(id: original.id)
      XCTAssertEqual(after, original)
    }
  }
}

extension HistoricalVariantEditingTests {
  func testKeepingSameIdentityPreservesFrozenNameAndMeasureAfterCatalogueChanges() async throws {
    let (repository, _, variant, original) = try await setup()
    try await repository.updateHistoricalWorkout(
      draft(original, variantID: variant.id), original: original, now: now)
    let frozen = try await repository.workout(id: original.id)
    var renamed = variant
    renamed.name = "Renamed"
    renamed.measure = "20"
    try await repository.saveVariant(renamed)
    try await repository.archiveVariant(id: variant.id)
    var edit = draft(frozen, variantID: variant.id)
    edit.name = "Name correction only"
    try await repository.updateHistoricalWorkout(edit, original: frozen, now: now)
    let saved = try await repository.workout(id: original.id)
    XCTAssertEqual(saved.exercises.first?.definition, frozen.exercises.first?.definition)
    let snapshot = try await repository.snapshot()
    let choices = snapshot.historicalDefinitions(
      for: try XCTUnwrap(frozen.exercises.first?.definition))
    XCTAssertEqual(choices.first { $0.variantID == variant.id }?.variant?.name, "V-sit")
    XCTAssertEqual(choices.first { $0.variantID == variant.id }?.variant?.measure, "15")
  }
}

extension HistoricalVariantEditingTests {
  func testRetagPreservesOtherExercisesInterruptedSetAndAllRecordedRests() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "alternate"
    variant.name = "Alternate"
    try await repository.saveVariant(variant)
    var second = parent
    second.id = "second"
    second.name = "Second"
    try await repository.saveExercise(second)
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = [parent.id, second.id]
    schedule.setCounts = [parent.id: 1, second.id: 2]
    try await repository.saveSchedule(schedule)
    let active = try await repository.startWorkout(scheduleID: schedule.id, now: now)
    let first = active.exercises[0]
    let other = active.exercises[1]
    try await repository.beginSet(
      workoutID: active.id, exerciseID: first.id, number: 1, weightGrams: 0, now: now)
    try await repository.finishTimedSet(
      workoutID: active.id, exerciseID: first.id, number: 1, now: now + 4000)
    try await repository.saveFeeling(
      workoutID: active.id, exerciseID: first.id, tenths: 60, now: now + 4000)
    let resting = try await repository.workout(id: active.id)
    try await repository.changeRest(id: XCTUnwrap(resting.rest).id, action: .skip, now: now + 4500)
    try await repository.beginSet(
      workoutID: active.id, exerciseID: other.id, number: 1, weightGrams: 900, now: now + 5000)
    try await repository.cancelWorkout(id: active.id, now: now + 9000)
    let original = try await repository.workout(id: active.id)
    let database = try SQLiteDatabase(path: path)
    func rests() throws -> [String] {
      try database.query("SELECT * FROM workout_rests ORDER BY id").map { row in
        row.values.keys.sorted().map { "\($0)=\(String(describing: row.values[$0]!))" }.joined(
          separator: "|")
      }
    }
    let before = try rests()
    XCTAssertEqual(before.count, 1)
    var edit = draft(original, variantID: nil)
    edit.exercises[0].variantID = variant.id
    try await repository.updateHistoricalWorkout(edit, original: original, now: now + 10000)
    let changed = try await repository.workout(id: original.id)
    XCTAssertEqual(changed.exercises[1], original.exercises[1])
    XCTAssertEqual(try rests(), before)
  }
}
