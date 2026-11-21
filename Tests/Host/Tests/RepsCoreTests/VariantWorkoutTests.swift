import Foundation
import XCTest

@testable import RepsCore

final class VariantWorkoutTests: XCTestCase, @unchecked Sendable {
  func testSessionChoiceLoadsOwnGoalsAndLocksEvenAfterCancelledCountdown() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "chin-ups" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "chin-timed"
    variant.name = "Hold"
    variant.tracking = .duration
    variant.minimumReps = nil
    variant.maximumReps = nil
    variant.durationSeconds = 20
    try await repository.saveVariant(variant)
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: 1_794_096_000_000)
    let occurrence = try XCTUnwrap(workout.currentExercise)
    try await repository.selectWorkoutVariant(
      workoutID: workout.id, exerciseID: occurrence.id, variantID: variant.id)
    let changed = try await repository.workout(id: workout.id)
    XCTAssertEqual(changed.currentExercise?.definition.variantID, variant.id)
    XCTAssertEqual(changed.currentExercise?.definition.setCount, occurrence.definition.setCount)
    let untouched = try await repository.snapshot()
    XCTAssertEqual(untouched.schedules, snapshot.schedules)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: occurrence.id, number: 1, now: workout.startedAt + 100)
    try await repository.cancelSetCountdown(
      workoutID: workout.id, exerciseID: occurrence.id, number: 1,
      expectedStart: workout.startedAt + 3100, now: workout.startedAt + 200)
    do {
      try await repository.selectWorkoutVariant(
        workoutID: workout.id, exerciseID: occurrence.id,
        variantID: ExerciseVariant.baseID(for: parent.id))
      XCTFail("A started first set must permanently lock the variant")
    } catch {}
    variant.name = "Renamed hold"
    variant.measure = "10"
    variant.unit = "cm"
    try await repository.saveVariant(variant)
    let frozen = try await repository.workout(id: workout.id)
    XCTAssertEqual(frozen.currentExercise?.definition.variant?.name, "Hold")
    XCTAssertNil(frozen.currentExercise?.definition.variant?.measure)
  }

  func testGoalsAndHistoryDoNotCrossVariants() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "push-ups" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "hands-high"
    variant.name = "Hands elevated"
    variant.minimumReps = 3
    variant.maximumReps = 6
    try await repository.saveVariant(variant)
    let target = variant.applying(to: parent)
    let goal = ExerciseGoal(definition: target, load: .bodyweight, repetitions: [3, 4, 5, 6])
    try await repository.saveGoal(goal, original: nil, scheduleID: "push")
    let context = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: variant.id)
    XCTAssertEqual(context.adopted, goal)
    let base = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: parent.variantID)
    XCTAssertNil(base.adopted)
    let draft = ManualWorkout(
      id: "variant-history", name: "Manual", performedAt: 1_794_096_000_000,
      exercises: [
        ManualWorkoutExercise(
          catalogueID: parent.id, tracking: .repetitions,
          sets: [ManualWorkoutSet(repetitions: 6, weightGrams: 0)], feelingTenths: 50,
          variantID: variant.id)
      ])
    try await repository.addHistoricalWorkout(draft, now: draft.performedAt)
    let history = try await repository.exerciseHistory(exerciseID: parent.id, variantID: variant.id)
    XCTAssertEqual(history.count, 1)
    let baseHistory = try await repository.exerciseHistory(
      exerciseID: parent.id, variantID: parent.variantID)
    XCTAssertTrue(baseHistory.isEmpty)
    let baseSuggestion = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: parent.variantID)
    XCTAssertEqual(baseSuggestion.suggestion?.reason, .initial)
    var other = target
    other.variant = nil
    XCTAssertFalse(goal.isCompatible(with: other))
    XCTAssertEqual(
      Progression.assess(target: other, previous: history.first?.exercise, loads: [.bodyweight])
        .status, .insufficient)
  }
}

extension VariantWorkoutTests {
  func testChangingProgramSetsResizesOnlyThatContextAndKeepsOtherVariantGoals() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "push-ups" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "hands"
    variant.name = "Hands"
    try await repository.saveVariant(variant)
    let goal = ExerciseGoal(
      definition: variant.applying(to: parent), load: .bodyweight, repetitions: [8, 9, 10, 11])
    try await repository.saveGoal(goal, original: nil, scheduleID: "push")
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "push" })
    schedule.variantIDs[parent.id] = variant.id
    schedule.setCounts[parent.id] = 2
    try await repository.saveSchedule(schedule)
    let selected = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: variant.id)
    XCTAssertEqual(selected.adopted?.repetitions, [8, 9])
    schedule.variantIDs[parent.id] = parent.variantID
    try await repository.saveSchedule(schedule)
    let retained = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: variant.id)
    XCTAssertEqual(retained.adopted?.repetitions, [8, 9])
    let base = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "push", variantID: parent.variantID)
    XCTAssertNil(base.adopted)
  }

  func testCancelledCountdownLockSurvivesArchiveRestore() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let now = 1_794_096_000_000
    var snapshot = try await repository.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = ["l-sit"]
    try await repository.saveSchedule(schedule)
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    let occurrence = try XCTUnwrap(workout.currentExercise)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: occurrence.id, number: 1, now: now)
    try await repository.cancelSetCountdown(
      workoutID: workout.id, exerciseID: occurrence.id, number: 1, expectedStart: now + 3000,
      now: now + 100)
    let archive = try await repository.exportTraining(now: now + 200)
    let decoded = try TrainingArchive.decode(archive.encoded())
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(decoded, now: now + 200)
    try await target.applyTrainingImport(preview, now: now + 200)
    snapshot = try await target.snapshot()
    var variant = try XCTUnwrap(snapshot.variants.first { $0.exerciseID == "l-sit" })
    variant.id = "advanced"
    variant.name = "Advanced"
    try await target.saveVariant(variant)
    do {
      try await target.selectWorkoutVariant(
        workoutID: workout.id, exerciseID: occurrence.id, variantID: variant.id)
      XCTFail("Restoring an unfinished workout must not unlock a started progression")
    } catch {}
  }
}
