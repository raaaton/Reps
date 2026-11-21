import Foundation
import XCTest

@testable import RepsCore

final class VariantTransferTests: XCTestCase, @unchecked Sendable {
  func testArchiveAndCSVPreserveVariantsSettingsGoalsAndFrozenNames() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let exercise = try XCTUnwrap(snapshot.exercises.first { $0.id == "push-ups" })
    var variant = ExerciseVariant.base(for: exercise)
    variant.id = "elevated"
    variant.name = "Hands elevated"
    variant.measure = "15.5"
    variant.unit = "cm"
    try await repository.saveVariant(variant)
    let goal = ExerciseGoal(
      definition: variant.applying(to: exercise), load: .bodyweight, repetitions: [8, 9, 10, 11])
    try await repository.saveGoal(goal, original: nil, scheduleID: "push")
    let now = 1_794_096_000_000
    try await repository.addHistoricalWorkout(
      ManualWorkout(
        id: "record", name: "Test", performedAt: now,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: exercise.id, tracking: .repetitions,
            sets: [ManualWorkoutSet(repetitions: 10, weightGrams: 0)], feelingTenths: 50,
            variantID: variant.id)
        ]), now: now)
    variant.name = "Renamed"
    try await repository.saveVariant(variant)
    let archive = try await repository.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now)
    try await target.applyTrainingImport(preview, now: now)
    let restored = try await target.snapshot()
    XCTAssertEqual(restored.variants, archive.contents.configuration.variants)
    let restoredGoal = try await target.goalContext(
      exerciseID: exercise.id, scheduleID: "push", variantID: variant.id)
    XCTAssertEqual(restoredGoal.adopted?.repetitions, goal.repetitions)
    let csv = try TrainingCSV.decode(TrainingCSV.encode(archive.contents.workouts))
    XCTAssertEqual(csv, archive.contents.workouts)
    XCTAssertEqual(csv.first?.exercises.first?.definition.variant?.name, "Hands elevated")
    XCTAssertEqual(csv.first?.exercises.first?.definition.variant?.measure, "15.5")
  }
}

extension VariantTransferTests {
  func testBaseGoalRemainsIndependentWhenProgramSelectsAnotherVariantAndAfterRestore() async throws
  {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let exercise = try XCTUnwrap(snapshot.exercises.first { $0.id == "push-ups" })
    let baseGoal = ExerciseGoal(
      definition: exercise, load: .bodyweight, repetitions: [8, 9, 10, 11])
    try await repository.saveGoal(baseGoal, original: nil, scheduleID: "push")
    var variant = ExerciseVariant.base(for: exercise)
    variant.id = "another"
    variant.name = "Another"
    try await repository.saveVariant(variant)
    let otherGoal = ExerciseGoal(
      definition: variant.applying(to: exercise), load: .bodyweight, repetitions: [12, 12, 12, 12])
    try await repository.saveGoal(otherGoal, original: nil, scheduleID: "push")
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "push" })
    schedule.variantIDs[exercise.id] = variant.id
    try await repository.saveSchedule(schedule)
    let selectedBase = try await repository.goalContext(
      exerciseID: exercise.id, scheduleID: "push", variantID: exercise.variantID)
    XCTAssertEqual(selectedBase.adopted, baseGoal)
    let archive = try await repository.exportTraining(now: 1_794_096_000_000)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(
      TrainingArchive.decode(archive.encoded()), now: archive.createdAt)
    try await target.applyTrainingImport(preview, now: archive.createdAt)
    let restoredBase = try await target.goalContext(
      exerciseID: exercise.id, scheduleID: "push", variantID: exercise.variantID)
    XCTAssertEqual(restoredBase.adopted, baseGoal)
  }
}
