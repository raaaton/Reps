import Foundation
import XCTest

@testable import SportCore

final class SessionTrendsTests: XCTestCase, @unchecked Sendable {
  var since: Date { ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")! }
  func record(
    _ id: String, day: String = "2026-10-11", reps: [Int] = [10, 10, 9, 8],
    grams: [Int] = [3900, 3900, 3900, 3900], rest: Int? = 180, status: WorkoutStatus = .completed,
    mode: TrackingMode = .repetitions
  ) -> ExercisePerformance {
    let def = TrainingExercise(
      id: "x", name: "X", tracking: mode, setCount: reps.count,
      minimumReps: mode == .repetitions ? 8 : nil, maximumReps: mode == .repetitions ? 12 : nil,
      durationSeconds: mode == .duration ? 30 : nil, isEnabled: true)
    let sets = reps.enumerated().map { i, v in
      WorkoutSet(
        id: "\(id)-\(i)", number: i + 1, repetitions: mode == .repetitions ? v : nil,
        durationMS: mode == .duration ? v : nil, weightGrams: grams[i], completedAt: 1)
    }
    return ExercisePerformance(
      workoutID: id, workoutName: id, dayKey: day, status: status,
      exercise: WorkoutExercise(
        id: id, definition: def, sets: sets, feelingTenths: 75, setStartedAt: nil,
        setWeightGrams: nil, setEndedAt: nil), restSeconds: rest)
  }
  func testOneExactPointPerSessionAndSameDayOrderFromHistory() {
    let records = [record("a-latest", reps: [12, 12, 12, 12]), record("z-earlier")]
    let points = SessionTrends.points(
      records: records, metric: .repetitions, tracking: .repetitions, weight: 3900, since: since)
    XCTAssertEqual(points.map(\.workoutID), ["z-earlier", "a-latest"])
    XCTAssertEqual(points.map(\.total), [37, 48])
    XCTAssertEqual(points.count, 2)
    XCTAssertEqual(points.first?.context.seriesCount, 4)
  }
  func testMixedLoadsExcludedFromTotalsButMaximumLoadRemainsFactual() {
    let mixed = record("mixed", grams: [3900, 4500, 3900, 4500])
    XCTAssertTrue(
      SessionTrends.points(
        records: [mixed], metric: .repetitions, tracking: .repetitions, weight: 3900, since: since
      ).isEmpty)
    let loads = SessionTrends.points(
      records: [mixed], metric: .load, tracking: .repetitions, weight: nil, since: since)
    XCTAssertEqual(loads.first?.total, 4500)
    XCTAssertEqual(
      SessionTrends.weights(records: [mixed], tracking: .repetitions, since: since), [])
  }

  func testRepetitionsWithoutLoadFilterIncludeMixedLoadsAndDifferentConditions() throws {
    let records = [
      record("mixed", day: "2026-10-12", grams: [0, 6000, 0, 6000], rest: nil),
      record("weighted", grams: [6000, 6000, 6000, 6000], rest: 60),
      record("bodyweight", day: "2026-10-10", reps: [10, 9], grams: [0, 0]),
      record("cancelled", status: .cancelled),
    ]
    let points = SessionTrends.points(
      records: records, metric: .repetitions, tracking: .repetitions, weight: nil, since: since)
    XCTAssertEqual(points.map(\.workoutID), ["bodyweight", "weighted", "mixed"])
    XCTAssertEqual(points.map(\.total), [19, 37, 37])
    XCTAssertEqual(try SessionTrends.total(points: points), 93)
  }
  func testContextsSeparateUnknownRestDifferentRestAndDifferentNumberOfSets() {
    let records = [
      record("manual", rest: nil), record("short", rest: 60), record("normal"),
      record("three", reps: [10, 10, 10], grams: [3900, 3900, 3900]),
    ]
    let points = SessionTrends.points(
      records: records, metric: .repetitions, tracking: .repetitions, weight: 3900, since: since)
    XCTAssertEqual(Set(points.map(\.context)).count, 4)
    XCTAssertNil(points.first { $0.workoutID == "manual" }?.context.restSeconds)
  }
  func testTimedTotalsPreserveMillisecondsAndInvalidOrOutsideRecordsDoNotCreatePoints() {
    let valid = record("timed", reps: [12125, 10000, 11000, 10000], mode: .duration)
    let points = SessionTrends.points(
      records: [valid], metric: .duration, tracking: .duration, weight: 3900, since: since)
    XCTAssertEqual(points.first?.total, 43125)
    XCTAssertTrue(
      SessionTrends.points(
        records: [valid], metric: .repetitions, tracking: .duration, weight: 3900, since: since
      ).isEmpty)
    let records = [
      record("cancel", status: .cancelled), record("invalid-date", day: "2026-02-30"),
      record("old", day: "2025-12-31"), record("zero", reps: [0, 8, 8, 8]),
    ]
    XCTAssertTrue(
      SessionTrends.points(
        records: records, metric: .repetitions, tracking: .repetitions, weight: 3900, since: since
      ).isEmpty)
    XCTAssertTrue(
      SessionTrends.points(
        records: [record("overflow", reps: [Int.max, 1], grams: [0, 0])], metric: .repetitions,
        tracking: .repetitions, weight: 0, since: since
      ).isEmpty)
  }
  func testWeightsOnlyIncludeUniformCompletedSessionsInSelectedPeriod() {
    let recent = record("recent", grams: [4500, 4500, 4500, 4500])
    let old = record("old", day: "2025-01-01")
    XCTAssertEqual(
      SessionTrends.weights(records: [old, recent], tracking: .repetitions, since: since), [4500])
  }
  func testRepositoryUsesRecordedRestAndDoesNotInventManualRest() async throws {
    let r = try SportRepository(path: ":memory:")
    let now = 1_791_720_000_000
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let w = try await r.startWorkout(scheduleID: "pull-abs", now: now, calendar: calendar)
    try await r.cancelWorkout(id: w.id, now: now + 1000)
    try await r.saveRest(seconds: 60)
    try await r.addHistoricalWorkout(
      ManualWorkout(
        id: "manual", name: "Manual", performedAt: now,
        exercises: [
          ManualWorkoutExercise(
            catalogueID: "chin-ups", tracking: .repetitions,
            sets: [ManualWorkoutSet(repetitions: 12, weightGrams: 0)], feelingTenths: 75)
        ]), now: now, calendar: calendar)
    let history = try await r.exerciseHistory(exerciseID: "chin-ups")
    XCTAssertEqual(history.first { $0.workoutID == w.id }?.restSeconds, 180)
    XCTAssertNil(history.first { $0.workoutID == "manual" }?.restSeconds)
  }
  func testSelectedWeightIsLatestEligibleWithinPeriodAndKeepsValidUserChoice() {
    let recent = record("recent", grams: [4500, 4500, 4500, 4500])
    let older = record("old", grams: [3900, 3900, 3900, 3900])
    let outOfPeriod = record("outside", day: "2025-01-01", grams: [5100, 5100, 5100, 5100])
    let records = [outOfPeriod, recent, older]
    XCTAssertEqual(
      SessionTrends.selectedWeight(
        records: records, tracking: .repetitions, since: since, requested: nil), 4500)
    XCTAssertEqual(
      SessionTrends.selectedWeight(
        records: records, tracking: .repetitions, since: since, requested: 3900), 3900)
    XCTAssertEqual(
      SessionTrends.selectedWeight(
        records: records, tracking: .repetitions, since: since, requested: 5100), 4500)
  }

  func testVolumeUsesEveryRepetitionAndAddedLoadAcrossSessions() {
    let records = [
      record("latest", reps: [12, 12, 12, 12], grams: [6000, 6000, 6000, 6000]),
      record(
        "earlier", day: "2026-10-01", reps: [10, 10, 10, 10], grams: [4500, 4500, 4500, 4500]),
    ]
    let points = SessionTrends.points(
      records: records, metric: .volume, tracking: .repetitions, weight: nil, since: since)
    XCTAssertEqual(points.map(\.total), [180000, 288000])
    XCTAssertEqual(points.map { $0.value(for: .volume) }, [180, 288])
    XCTAssertEqual(points.map(\.workoutID), ["earlier", "latest"])
  }
  func testVolumeIncludesMixedLoadsWithGramPrecisionAndBodyweightRemainsZero() {
    let mixed = record("mixed", reps: [12, 10, 8, 8], grams: [6000, 4500, 0, 3000])
    let precise = record("precise", reps: [3], grams: [1234])
    let body = record("body", grams: [0, 0, 0, 0])
    let points = SessionTrends.points(
      records: [mixed, precise, body], metric: .volume, tracking: .repetitions, weight: 6000,
      since: since)
    XCTAssertEqual(points.first { $0.workoutID == "mixed" }?.total, 141000)
    XCTAssertEqual(points.first { $0.workoutID == "precise" }?.value(for: .volume), 3.702)
    XCTAssertEqual(points.first { $0.workoutID == "body" }?.total, 0)
  }
  func testVolumeRefusesOverflowAndDoesNotUseCancelledOrTimedRecords() {
    let records = [
      record("multiply-overflow", reps: [Int.max], grams: [2]),
      record("sum-overflow", reps: [Int.max, 1], grams: [1, 1]),
      record("cancel", status: .cancelled),
      record("timed", mode: .duration),
      record("old", day: "2025-01-01"),
    ]
    XCTAssertTrue(
      SessionTrends.points(
        records: records, metric: .volume, tracking: .repetitions, weight: nil, since: since
      ).isEmpty)
    XCTAssertTrue(
      SessionTrends.points(
        records: [record("timed", mode: .duration)], metric: .volume,
        tracking: .duration, weight: nil, since: since
      ).isEmpty)
  }
  func testTimedSessionTotalIncludesAllLoadsAndCanStillFilterUniformLoad() {
    let mixed = record(
      "mixed", reps: [12125, 10000, 11000, 10000], grams: [0, 3900, 4500, 0], mode: .duration)
    let uniform = record("uniform", reps: [10000, 10000, 10000, 10000], mode: .duration)
    let all = SessionTrends.points(
      records: [mixed, uniform], metric: .duration, tracking: .duration, weight: nil, since: since)
    XCTAssertEqual(all.map(\.total), [40000, 43125])
    XCTAssertEqual(all.last?.value(for: .duration), 43.125)
    let filtered = SessionTrends.points(
      records: [mixed, uniform], metric: .duration, tracking: .duration, weight: 3900, since: since)
    XCTAssertEqual(filtered.map(\.workoutID), ["uniform"])
  }

  func testCumulativeVolumeAddsSessionsAcrossLoadsAndHistoricalConditions() throws {
    let records = [
      record(
        "last", day: "2026-10-11", reps: [12, 12, 12, 12], grams: [6000, 6000, 6000, 6000], rest: 60
      ),
      record("first", day: "2026-09-01", reps: [10, 10], grams: [4500, 4500], rest: nil),
      record("middle", day: "2026-10-01", reps: [10], grams: [3000]),
      record("cancel", status: .cancelled),
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let points = try SessionTrends.cumulativeVolume(
      records: records, since: since, calendar: calendar)
    XCTAssertEqual(points.map(\.workoutID), ["first", "middle", "last"])
    XCTAssertEqual(points.map(\.total), [90000, 30000, 288000])
    XCTAssertEqual(points.map(\.cumulativeTotal), [90000, 120000, 408000])
    XCTAssertEqual(points.map { $0.value(for: .volume) }, [90, 30, 288])
    XCTAssertEqual(Set(points.map(\.context)).count, 3)
    // A narrower viewport must not reset a historical cumulative balance.
    let visible = points.filter { $0.performance.dayKey >= "2026-10-01" }
    XCTAssertEqual(visible.map(\.cumulativeTotal), [120000, 408000])
    // A deliberately bounded total includes only records from that boundary.
    let bounded = try SessionTrends.cumulativeVolume(
      records: records, since: ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")!,
      calendar: calendar)
    XCTAssertEqual(bounded.map(\.cumulativeTotal), [30000, 318000])
  }
  func testCumulativeVolumeHandlesZeroSameDayAndRemovedHistory() throws {
    let older = record("older", grams: [0, 0, 0, 0])
    let latest = record("latest", reps: [12], grams: [6000])
    let points = try SessionTrends.cumulativeVolume(records: [latest, older], since: since)
    XCTAssertEqual(points.map(\.workoutID), ["older", "latest"])
    XCTAssertEqual(points.map(\.cumulativeTotal), [0, 72000])
    let lastWithoutLoad = try SessionTrends.cumulativeVolume(
      records: [record("body-latest", grams: [0, 0, 0, 0]), latest], since: since)
    XCTAssertEqual(lastWithoutLoad.last?.total, 0)
    XCTAssertEqual(lastWithoutLoad.last?.cumulativeTotal, 72000)
    let afterDeletion = try SessionTrends.cumulativeVolume(records: [older], since: since)
    XCTAssertEqual(afterDeletion.last?.cumulativeTotal, 0)
    XCTAssertTrue(try SessionTrends.cumulativeVolume(records: [], since: since).isEmpty)
  }
  func testCumulativeVolumeReportsOverflowRatherThanShowingPartialTotal() {
    XCTAssertThrowsError(
      try SessionTrends.cumulativeVolume(
        records: [record("a", reps: [Int.max], grams: [1]), record("b", reps: [1], grams: [1])],
        since: since))
    XCTAssertThrowsError(
      try SessionTrends.cumulativeVolume(
        records: [record("a", reps: [Int.max], grams: [2]), record("valid")], since: since))
  }

  func testRepetitionPeriodTotalsUseOnlyVisibleLoadPeriodAndContext() throws {
    let records = [
      record("latest", reps: [12, 12, 12, 12]),
      record("earlier", day: "2026-10-01", reps: [10, 10, 10, 10]),
      record("different-rest", reps: [8, 8, 8, 8], rest: 60),
      record("different-load", grams: [4500, 4500, 4500, 4500]),
      record("outside", day: "2025-01-01"),
      record("cancelled", status: .cancelled),
    ]
    let points = SessionTrends.points(
      records: records, metric: .repetitions, tracking: .repetitions, weight: 3900, since: since)
    XCTAssertEqual(try SessionTrends.total(points: points), 120)
    let totals = try SessionTrends.totalsByContext(points: points)
    let normalContext = try XCTUnwrap(points.first { $0.workoutID == "latest" }?.context)
    let shortContext = try XCTUnwrap(points.first { $0.workoutID == "different-rest" }?.context)
    XCTAssertEqual(totals[normalContext], 88)
    XCTAssertEqual(totals[shortContext], 32)
    XCTAssertEqual(points.first { $0.workoutID == "latest" }?.value(for: .repetitions), 48)
    XCTAssertEqual(points.first { $0.workoutID == "earlier" }?.value(for: .repetitions), 40)
  }
  func testPeriodTotalEmptySingleAndOverflowAreExplicit() throws {
    XCTAssertEqual(try SessionTrends.total(points: []), 0)
    XCTAssertTrue(try SessionTrends.totalsByContext(points: []).isEmpty)
    let single = SessionTrends.points(
      records: [record("one")], metric: .repetitions, tracking: .repetitions, weight: 3900,
      since: since)
    XCTAssertEqual(try SessionTrends.total(points: single), 37)
    let overflow = SessionTrends.points(
      records: [record("huge", reps: [Int.max], grams: [0]), record("one", reps: [1], grams: [0])],
      metric: .repetitions, tracking: .repetitions, weight: 0, since: since)
    XCTAssertThrowsError(try SessionTrends.total(points: overflow))
    XCTAssertThrowsError(try SessionTrends.totalsByContext(points: overflow))
  }

}
