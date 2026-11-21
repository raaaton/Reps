import XCTest

@testable import RepsCore

final class ProgressWorkoutPresentationTests: XCTestCase {
  func configured() -> (TrainingSnapshot, TrainingExercise, TrainingExercise, ExerciseGoal) {
    let parent = TrainingExercise(
      id: "l-sit", name: "L-sit", tracking: .duration, setCount: 4,
      minimumReps: nil, maximumReps: nil, durationSeconds: 15, isEnabled: true)
    var variant = ExerciseVariant.base(for: parent)
    variant.id = "v-sit"
    variant.name = "V-sit"
    variant.durationSeconds = 3
    let selected = variant.applying(to: parent)
    let goal = ExerciseGoal(
      definition: selected, load: .bodyweight, repetitions: nil,
      durationsMS: [3000, 3000, 3000, 3000])
    var schedule = TrainingSchedule(
      id: "pull", name: "Pull + Abs", weekday: 7, isEnabled: true,
      reminderMinutes: nil, exerciseIDs: [parent.id], setCounts: [parent.id: 4],
      goals: [parent.id: goal])
    schedule.variantIDs[parent.id] = variant.id
    var snapshot = TrainingSnapshot(exercises: [parent], schedules: [schedule], restSeconds: 180)
    snapshot.variants = [ExerciseVariant.base(for: parent), variant]
    snapshot.variantGoals = [
      VariantGoal(variantID: variant.id, scheduleID: schedule.id, goal: goal)
    ]
    return (snapshot, parent, selected, goal)
  }

  func testSummaryUsesPlannedVariantInsteadOfParentBaseSettings() {
    let (snapshot, parent, _, goal) = configured()
    XCTAssertFalse(snapshot.needsGoalReview(for: parent, availableLoads: [.bodyweight]))
    XCTAssertEqual(snapshot.primaryGoal(for: parent), goal)
  }

  func testNextWorkoutRemainsTheSameWhenBrowsingAnotherProgression() {
    let (snapshot, parent, selected, goal) = configured()
    let fromBase = snapshot.workoutTargets(for: parent)
    let fromVariant = snapshot.workoutTargets(for: selected)
    XCTAssertEqual(fromBase, fromVariant)
    XCTAssertEqual(fromBase.count, 1)
    XCTAssertEqual(fromBase.first?.exercise.variantID, selected.variantID)
    XCTAssertEqual(fromBase.first?.goal, goal)
  }

  func testARealInvalidGoalStillNeedsReview() {
    var (snapshot, parent, _, _) = configured()
    snapshot.schedules[0].setCounts[parent.id] = 2
    XCTAssertTrue(snapshot.needsGoalReview(for: parent, availableLoads: [.bodyweight]))
    XCTAssertNil(snapshot.primaryGoal(for: parent))
  }

  func testAnySavedProgressionGoalHidesPromptWithoutGivingItsGoalToBase() {
    var (snapshot, parent, selected, goal) = configured()
    snapshot.schedules[0].goals = [:]
    XCTAssertTrue(snapshot.hasProgressionGoal(for: parent))
    XCTAssertTrue(snapshot.hasProgressionGoal(for: selected))
    XCTAssertNil(snapshot.workoutTargets(for: parent).first?.goal)
    snapshot.variantGoals = []
    XCTAssertFalse(snapshot.hasProgressionGoal(for: parent))
    snapshot.schedules[0].baseGoals[parent.id] = goal
    XCTAssertTrue(snapshot.hasProgressionGoal(for: parent))
  }
}
