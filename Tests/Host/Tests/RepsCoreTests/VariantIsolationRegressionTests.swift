import Foundation
import XCTest

@testable import RepsCore

final class VariantIsolationRegressionTests: XCTestCase, @unchecked Sendable {
  let now = 1_794_096_000_000
  func configured() async throws -> (RepsRepository, TrainingExercise, ExerciseVariant) {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "chin-ups" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "other"
    variant.name = "Other"
    variant.minimumReps = 1
    variant.maximumReps = 1
    try await repository.saveVariant(variant)
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    schedule.exerciseIDs = [parent.id]
    schedule.setCounts = [parent.id: 1]
    try await repository.saveSchedule(schedule)
    return (repository, parent, variant)
  }
  func testCompletingBaseNeverOverwritesAnUntrainedVariantsCustomizedGoal() async throws {
    let (repository, parent, variant) = try await configured()
    try await repository.addHistoricalWorkout(
      ManualWorkout(
        id: "old-other", name: "Old", performedAt: now - 10000,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: parent.id, tracking: .repetitions,
            sets: [ManualWorkoutSet(repetitions: 1, weightGrams: 0)], feelingTenths: 50,
            variantID: variant.id)
        ]), now: now)
    var target = variant.applying(to: parent)
    target.setCount = 1
    let customized = ExerciseGoal(definition: target, load: .bodyweight, repetitions: [7])
    try await repository.saveGoal(customized, original: nil, scheduleID: "pull-abs")
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, repetitions: 10, weightGrams: 0,
      now: now + 1000)
    try await repository.saveFeeling(
      workoutID: workout.id, exerciseID: exercise.id, tenths: 50, now: now + 2000)
    let after = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "pull-abs", variantID: variant.id)
    XCTAssertEqual(after.adopted, customized)
  }
  func testSessionOnlyVariantSwitchKeepsLoadDecisionFlow() async throws {
    let (repository, _, variant) = try await configured()
    let workout = try await repository.startWorkout(scheduleID: "pull-abs", now: now)
    let exercise = try XCTUnwrap(workout.currentExercise)
    try await repository.selectWorkoutVariant(
      workoutID: workout.id, exerciseID: exercise.id, variantID: variant.id)
    try await repository.beginSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, now: now)
    try await repository.recordSet(
      workoutID: workout.id, exerciseID: exercise.id, number: 1, repetitions: 1, weightGrams: 0,
      now: now + 1000)
    let decision = try await repository.exerciseLoadGoalDecision(
      workoutID: workout.id, exerciseID: exercise.id, feelingTenths: 50, now: now + 2000)
    XCTAssertEqual(decision?.suggestion.reason, .increaseLoad)
    XCTAssertEqual(decision?.suggestion.goal.definition.variantID, variant.id)
  }
  func testSummaryFactsNeverCompareDifferentVariants() async throws {
    let (_, parent, variant) = try await configured()
    let old = WorkoutExercise(
      id: "old", definition: parent,
      sets: [
        WorkoutSet(
          id: "s1", number: 1, repetitions: 8, durationMS: nil, weightGrams: 0, completedAt: now)
      ], feelingTenths: 60, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
    var target = variant.applying(to: parent)
    target.setCount = 1
    let current = WorkoutExercise(
      id: "new", definition: target,
      sets: [
        WorkoutSet(
          id: "s2", number: 1, repetitions: 12, durationMS: nil, weightGrams: 0, completedAt: now)
      ], feelingTenths: 50, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
    XCTAssertTrue(
      ProgressFacts.compare(
        current: current, previous: old, restSeconds: 180, previousRestSeconds: 180
      ).isEmpty)
  }
  func testTimedVariantEditReconcilesOtherProgramGoals() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "hold"
    variant.name = "Hold"
    variant.durationSeconds = 10
    try await repository.saveVariant(variant)
    let another = TrainingSchedule(
      id: "another", name: "Another", weekday: 1, isEnabled: true, reminderMinutes: nil,
      exerciseIDs: [parent.id], setCounts: [parent.id: 4])
    try await repository.saveSchedule(another, creating: true)
    for id in ["pull-abs", "another"] {
      let context = try await repository.goalContext(
        exerciseID: parent.id, scheduleID: id, variantID: variant.id)
      let goal = ExerciseGoal(
        definition: context.exercise, load: .bodyweight, repetitions: nil,
        durationsMS: [10000, 10000, 10000, 10000])
      try await repository.saveGoal(goal, original: nil, scheduleID: id)
    }
    let context = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "pull-abs", variantID: variant.id)
    var definition = context.exercise
    definition.durationSeconds = 20
    let changed = ExerciseGoal(definition: definition, load: .bodyweight, repetitions: nil)
    try await repository.saveTimedGoal(
      changed, original: context.adopted, originalExercise: context.exercise, scheduleID: "pull-abs"
    )
    let other = try await repository.goalContext(
      exerciseID: parent.id, scheduleID: "another", variantID: variant.id)
    XCTAssertTrue(try XCTUnwrap(other.adopted).isCompatible(with: other.exercise))
    XCTAssertEqual(other.exercise.durationSeconds, 20)
  }
}
