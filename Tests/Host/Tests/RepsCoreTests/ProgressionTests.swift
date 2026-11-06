import XCTest

@testable import RepsCore

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
  func testProgressionUsesSpacedChoicesAndKeepsReferenceExact() {
    let choices = [0, 3000, 3200, 3500, 3700, 4000].map {
      AvailableLoad(grams: $0, components: [])
    }
    let record = previous(weights: [3000, 3000, 3000, 3000])
    XCTAssertEqual(
      Progression.assess(target: target, previous: record, loads: choices).nextLoad?.grams, 3500)
    let old = previous(weights: [3200, 3200, 3200, 3200])
    let result = Progression.assess(target: target, previous: old, loads: choices)
    XCTAssertEqual(result.referenceGrams, 3200)
    XCTAssertEqual(result.nextLoad?.grams, 3500)
  }
  func testMixedLoadsUseStrictlyHeavierChoice() {
    let result = Progression.assess(target: target, previous: previous(), loads: loads)
    XCTAssertEqual(result.status, .increase)
    XCTAssertEqual(result.referenceGrams, 4500)
    XCTAssertEqual(result.nextLoad?.grams, 5100)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: 90), loads: loads).status,
      .achieved)
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(reps: [12, 11, 12, 12]), loads: loads)
        .status, .maintain)
  }
  func testFeelingStrictlyBelowNineQualifiesWithoutRoundingOldValues() {
    for feeling in [75, 79, 80, 85, 89] {
      XCTAssertEqual(
        Progression.assess(target: target, previous: previous(feeling: feeling), loads: loads)
          .status, .increase)
    }
    XCTAssertEqual(
      Progression.assess(target: target, previous: previous(feeling: 90), loads: loads).status,
      .achieved)
  }
  func testGoalProposalUsesStrictFeelingBoundaryForWeightedAndBodyweightMaximums() {
    for grams in [0, 3900] {
      for feeling in [80, 85, 89, 90] {
        let record = previous(feeling: feeling, weights: Array(repeating: grams, count: 4))
        let goal = GoalEngine.suggestion(target: target, previous: record, loads: loads)
        XCTAssertEqual(goal?.reason, feeling < 90 ? .increaseLoad : .keep)
        XCTAssertEqual(goal?.goal.load.grams, feeling < 90 ? (grams == 0 ? 3000 : 4500) : grams)
        XCTAssertEqual(goal?.goal.repetitions, feeling < 90 ? [8, 8, 8, 8] : [12, 12, 12, 12])
      }
    }
  }
  func testSubmaximumBodyweightNeverProposesAddedLoad() {
    for feeling in [75, 80, 85, 89, 90] {
      let record = previous(reps: [12, 12, 11, 12], feeling: feeling, weights: [0, 0, 0, 0])
      let goal = GoalEngine.suggestion(target: target, previous: record, loads: loads)
      XCTAssertEqual(goal?.goal.load.grams, 0)
      XCTAssertEqual(goal?.reason, feeling < 80 ? .addRepetition : .keep)
      XCTAssertEqual(goal?.goal.repetitions, feeling < 80 ? [12, 12, 12, 12] : [12, 12, 11, 12])
    }
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
  func testBodyweightAtMaximumUsesSmallestPositiveLoad() {
    let actual = previous(reps: [12, 12, 12, 12], feeling: 89, weights: [0, 0, 0, 0])
    let choices = [5100, 0, 3900, 3000].map { AvailableLoad(grams: $0, components: []) }
    let assessment = Progression.assess(target: target, previous: actual, loads: choices)
    XCTAssertEqual(assessment.status, .increase)
    XCTAssertEqual(assessment.nextLoad?.grams, 3000)
    let goal = GoalEngine.suggestion(target: target, previous: actual, loads: choices)
    XCTAssertEqual(goal?.goal.load.grams, 3000)
    XCTAssertEqual(goal?.goal.repetitions, [8, 8, 8, 8])
    XCTAssertEqual(goal?.reason, .increaseLoad)
  }
  func testFirstLoadRequiresEveryBodyweightSetAtMaximumAndCompleteSets() {
    for effort in [0, 75, 79, 80, 85, 89, 90] {
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
    let actual = previous(reps: [12, 12, 12, 12], feeling: 89, weights: [0, 0, 0, 0])
    let result = Progression.assess(target: target, previous: actual, loads: [.bodyweight])
    XCTAssertEqual(result.status, .noHeavierLoad)
    XCTAssertNil(result.nextLoad)
  }
}
