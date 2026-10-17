import XCTest

@testable import SportCore

final class ProgressionTests: XCTestCase {
  private var target: TrainingExercise {
    TrainingExercise(
      id: "ex", name: "Ex", tracking: .repetitions, setCount: 4, minimumReps: 8, maximumReps: 12,
      durationSeconds: nil, isEnabled: true)
  }
  private func previous(
    reps: [Int] = [12, 12, 12, 12], feeling: Int? = 70, weights: [Int] = [3000, 3900, 4500, 4500]
  ) -> WorkoutExercise {
    WorkoutExercise(
      id: "past", definition: target,
      sets: reps.enumerated().map {
        WorkoutSet(
          id: "s\($0.offset)", number: $0.offset + 1, repetitions: $0.element, durationMS: nil,
          weightGrams: weights[$0.offset], completedAt: 100)
      }, feelingTenths: feeling, setStartedAt: nil, setWeightGrams: nil, setEndedAt: nil)
  }
  private var loads: [AvailableLoad] {
    [0, 3000, 3900, 4500, 5100].map { AvailableLoad(grams: $0, components: []) }
  }
  func testInclusiveThresholdAndMixedLoadsUseStrictlyHeavierChoice() {
    let result = Progression.assess(target: target, previous: previous(), loads: loads)
    XCTAssertEqual(result.status, .increase)
    XCTAssertEqual(result.referenceGrams, 4500)
    XCTAssertEqual(result.nextLoad?.grams, 5100)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: 80), loads: loads).status,
      .achieved)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(reps: [12, 11, 12, 12]), loads: loads)
        .status, .maintain)
  }
  func testFeelingJustBelowEightQualifiesWithoutRoundingOldValues() {
    for feeling in [75, 79] {
      XCTAssertEqual(
        Progression.assess(target: target, previous: previous(feeling: feeling), loads: loads)
          .status, .increase)
    }
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: 80), loads: loads).status,
      .achieved)
  }
  func testIncompleteMissingOrInconsistentRecordsNeverInventRecommendation() {
    XCTAssertEqual(
      Progression.assess(target: target, previous: nil, loads: loads).status, .insufficient)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(reps: [12, 12, 12]), loads: loads)
        .status, .insufficient)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: nil), loads: loads).status,
      .insufficient)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: 101), loads: loads).status,
      .insufficient)
    let unavailable = Progression.assess(
      target: target, previous: previous(), loads: Array(loads.dropLast()))
    XCTAssertEqual(unavailable.status, .noHeavierLoad)
    XCTAssertNil(unavailable.nextLoad)
    XCTAssertEqual(unavailable.referenceGrams, 4500)
  }
  func testTimedTargetsCompareDurationsWithoutLoadIncrease() {
    var timed = target
    timed.tracking = .duration
    timed.minimumReps = nil
    timed.maximumReps = nil
    timed.durationSeconds = 30
    let sets = (1...4).map {
      WorkoutSet(
        id: "s\($0)", number: $0, repetitions: nil, durationMS: 30_000, weightGrams: 0,
        completedAt: 100)
    }
    let record = WorkoutExercise(
      id: "past", definition: timed, sets: sets, feelingTenths: 30, setStartedAt: nil,
      setWeightGrams: nil, setEndedAt: nil)
    let result = Progression.assess(target: timed, previous: record, loads: loads)
    XCTAssertEqual(result.status, .achieved)
    XCTAssertNil(result.nextLoad)
    timed.durationSeconds = 31
    XCTAssertEqual(
      Progression.assess(target: timed, previous: record, loads: loads).status, .maintain)
    timed.durationSeconds = nil
    XCTAssertEqual(
      Progression.assess(target: timed, previous: record, loads: loads).status, .insufficient)
  }
}

extension ProgressionTests {
  func testEasyBodyweightUsesSmallestPositiveLoadBeforeMaximumReps() {
    let actual = previous(reps: [10, 9, 9, 8], feeling: 79, weights: [0, 0, 0, 0])
    let choices = [5100, 0, 3900, 3000].map { AvailableLoad(grams: $0, components: []) }
    let assessment = Progression.assess(target: target, previous: actual, loads: choices)
    XCTAssertEqual(assessment.status, .increase)
    XCTAssertEqual(assessment.nextLoad?.grams, 3000)
    let goal = GoalEngine.suggestion(target: target, previous: actual, loads: choices)
    XCTAssertEqual(goal?.goal.load.grams, 3000)
    XCTAssertEqual(goal?.goal.repetitions, [8, 8, 8, 8])
    XCTAssertEqual(goal?.reason, .increaseLoad)
  }
  func testFirstLoadRequiresFeelingBelowEightAndCompleteBodyweightSets() {
    for effort in [80, 90] {
      let actual = previous(reps: [10, 9, 9, 8], feeling: effort, weights: [0, 0, 0, 0])
      let result = Progression.assess(target: target, previous: actual, loads: loads)
      XCTAssertEqual(result.status, .maintain)
      XCTAssertNil(result.nextLoad)
    }
    let incomplete = previous(reps: [10, 9, 8], feeling: 75, weights: [0, 0, 0])
    XCTAssertEqual(
      Progression.assess(target: target, previous: incomplete, loads: loads).status, .insufficient)
    for weights in [[0, 3000, 0, 0], [3000, 3000, 3000, 3000]] {
      let weighted = previous(reps: [10, 9, 9, 8], feeling: 75, weights: weights)
      XCTAssertNil(Progression.assess(target: target, previous: weighted, loads: loads).nextLoad)
    }
  }
  func testEasyBodyweightWithoutAvailableLoadDoesNotInventOne() {
    let actual = previous(reps: [10, 9, 9, 8], feeling: 75, weights: [0, 0, 0, 0])
    let result = Progression.assess(target: target, previous: actual, loads: [.bodyweight])
    XCTAssertEqual(result.status, .noHeavierLoad)
    XCTAssertNil(result.nextLoad)
  }
}
