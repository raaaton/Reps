import XCTest

@testable import SportCore

final class PrimaryExerciseGoalTests: XCTestCase {
  private func exercise(timed: Bool = false) -> TrainingExercise {
    TrainingExercise(
      id: "exercise", name: "Exercise", tracking: timed ? .duration : .repetitions,
      setCount: 4, minimumReps: timed ? nil : 8, maximumReps: timed ? nil : 12,
      durationSeconds: timed ? 30 : nil, isEnabled: true)
  }

  private func goal(_ exercise: TrainingExercise, reps: [Int], grams: Int) -> ExerciseGoal {
    var target = exercise
    target.setCount = reps.count
    return ExerciseGoal(
      definition: target, load: AvailableLoad(grams: grams, components: []),
      repetitions: target.tracking == .repetitions ? reps : nil)
  }

  private func snapshot(_ exercise: TrainingExercise, goals: [ExerciseGoal]) -> TrainingSnapshot {
    TrainingSnapshot(
      exercises: [exercise],
      schedules: goals.enumerated().map { index, goal in
        TrainingSchedule(
          id: "workout-\(index)", name: "Workout \(index)", weekday: index + 1,
          isEnabled: true, reminderMinutes: nil, exerciseIDs: [exercise.id],
          setCounts: [exercise.id: goal.definition.setCount], goals: [exercise.id: goal])
      }, restSeconds: 60)
  }

  // A heavier individual load must not beat a larger total target volume.
  func testPrimaryWorkoutUsesTotalWeightedTargetAndKeepsItsExactGoal() {
    let e = exercise()
    let small = goal(e, reps: [12, 12], grams: 8000)  // 192 kg-reps
    let main = goal(e, reps: [10, 10, 9, 9], grams: 6000)  // 228 kg-reps
    let s = snapshot(e, goals: [small, main])
    XCTAssertEqual(s.primaryGoal(for: e), main)
  }

  // The user's explicit rule: weighted repetition goals take priority over bodyweight goals.
  func testWeightedWorkoutWinsEvenWithFewerRepetitionsAndFractionalLoad() {
    let e = exercise()
    let bodyweight = goal(e, reps: [12, 12, 12, 12], grams: 0)
    let weighted = goal(e, reps: [8], grams: 500)
    XCTAssertEqual(snapshot(e, goals: [bodyweight, weighted]).primaryGoal(for: e), weighted)
  }

  // Using a per-set maximum instead of summing actual per-set targets picks the wrong workout.
  func testBodyweightWorkoutUsesSumOfRepetitions() {
    let e = exercise()
    let small = goal(e, reps: [12, 8, 8], grams: 0)
    let main = goal(e, reps: [10, 10, 10], grams: 0)
    XCTAssertEqual(snapshot(e, goals: [small, main]).primaryGoal(for: e), main)
  }

  // Isometric selection follows sets × time, irrespective of added weight.
  func testIsometricWorkoutUsesTotalTimeWithoutWeightPriority() {
    let e = exercise(timed: true)
    let small = goal(e, reps: [1, 1], grams: 6000)
    let main = goal(e, reps: [1, 1, 1], grams: 0)
    XCTAssertEqual(snapshot(e, goals: [small, main]).primaryGoal(for: e), main)
  }

  func testTiesAndUntimedWorkoutsKeepFirstWorkoutOrder() {
    let e = exercise()
    let first = goal(e, reps: [10, 10], grams: 6000)
    let tied = goal(e, reps: [12, 12], grams: 5000)
    XCTAssertEqual(snapshot(e, goals: [first, tied]).primaryGoal(for: e), first)
    var untimed = exercise(timed: true)
    untimed.durationSeconds = nil
    let a = goal(untimed, reps: [1, 1], grams: 0)
    let b = goal(untimed, reps: [1, 1, 1], grams: 6000)
    XCTAssertEqual(snapshot(untimed, goals: [a, b]).primaryGoal(for: untimed), a)
  }

  // Stale targets or goals retained outside an assignment cannot become its main workout.
  func testSkipsMissingUnassignedAndIncompatibleGoals() {
    let e = exercise()
    let valid = goal(e, reps: [8, 8], grams: 0)
    let other = goal(e, reps: [12, 12, 12, 12], grams: 8000)
    var s = snapshot(e, goals: [other, other, valid])
    s.schedules[0].exerciseIDs = []
    s.schedules[1].setCounts[e.id] = 1
    XCTAssertEqual(s.primaryGoal(for: e), valid)
    s.schedules[2].goals = [:]
    XCTAssertNil(s.primaryGoal(for: e))
    XCTAssertNil(snapshot(e, goals: []).primaryGoal(for: e))
    XCTAssertEqual(snapshot(e, goals: [valid]).primaryGoal(for: e), valid)
  }
}
