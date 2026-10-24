import Foundation
import XCTest

@testable import RepsCore

final class TimedBaselineGoalTests: XCTestCase, @unchecked Sendable {
  func testDurationTargetsRoundTripAndResizeWithoutChangingTheConfiguredProgram() throws {
    let d = TrainingExercise(
      id: "hold", name: "Hold", tracking: .duration, setCount: 2,
      minimumReps: nil, maximumReps: nil, durationSeconds: 30, isEnabled: true)
    let legacy = ExerciseGoal(definition: d, load: .bodyweight, repetitions: nil)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
    object["durationsMS"] = [12300, 10700]
    let decoded = try JSONDecoder().decode(
      ExerciseGoal.self,
      from: JSONSerialization.data(withJSONObject: removingNewTrainingFields(object)))
    let validated = try decoded.validated()
    let roundTrip = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(validated)) as? [String: Any])
    XCTAssertEqual(roundTrip["durationsMS"] as? [Int], [12300, 10700])
    var four = d
    four.setCount = 4
    let resized = validated.resized(to: four)
    let encoded = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(resized)) as? [String: Any])
    XCTAssertEqual(encoded["durationsMS"] as? [Int], [12300, 10700, 10700, 10700])
    XCTAssertEqual(resized.definition.durationSeconds, 30)
  }

  func testMalformedTimedTargetsAreRejectedRatherThanIgnored() throws {
    let d = TrainingExercise(
      id: "hold", name: "Hold", tracking: .duration, setCount: 2,
      minimumReps: nil, maximumReps: nil, durationSeconds: nil, isEnabled: true)
    let legacy = ExerciseGoal(definition: d, load: .bodyweight, repetitions: nil)
    for values in [[0, 1000], [1000], [1000, -100], [12345, 1000]] {
      var object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
      object["durationsMS"] = values
      let decoded = try JSONDecoder().decode(
        ExerciseGoal.self,
        from: JSONSerialization.data(withJSONObject: removingNewTrainingFields(object)))
      XCTAssertThrowsError(try decoded.validated())
    }
  }
}

extension TimedBaselineGoalTests {
  func testTimedTargetsSurviveArchiveRestoreAndCanBeClearedExplicitly() async throws {
    let r = try RepsRepository(path: ":memory:")
    let now = 1_791_892_800_000
    let snapshot = try await r.snapshot()
    var schedule = try XCTUnwrap(snapshot.schedules.first { $0.id == "legs" })
    schedule.exerciseIDs = ["l-sit"]
    schedule.setCounts = ["l-sit": 2]
    try await r.saveSchedule(schedule)
    let context = try await r.goalContext(exerciseID: "l-sit", scheduleID: "legs")
    let goal = ExerciseGoal(
      definition: context.exercise, load: .bodyweight, repetitions: nil,
      durationsMS: [12300, 10700])
    try await r.saveGoal(goal, original: nil, scheduleID: "legs")
    let archive = try await r.exportTraining(now: now)
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.version, 7)
    let destination = try RepsRepository(path: ":memory:")
    let preview = try await destination.previewArchiveImport(decoded, now: now)
    try await destination.applyTrainingImport(preview, now: now)
    let restored = try await destination.goalContext(exerciseID: "l-sit", scheduleID: "legs")
    XCTAssertEqual(restored.adopted?.durationsMS, [12300, 10700])
    XCTAssertEqual(restored.adopted?.durationTargetMS(forSet: 2), 10700)
    try await destination.saveTimedGoal(
      ExerciseGoal(definition: restored.exercise, load: .bodyweight, repetitions: nil),
      original: restored.adopted, originalExercise: restored.exercise, scheduleID: "legs")
    let cleared = try await destination.goalContext(exerciseID: "l-sit", scheduleID: "legs")
    XCTAssertNil(cleared.adopted?.durationTargetMS(forSet: 1))
    let legacy = try await destination.exportTraining(now: now)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: legacy.encoded()) as? [String: Any])
    object["version"] = 3
    let v3 = try TrainingArchive.decode(
      JSONSerialization.data(withJSONObject: removingNewTrainingFields(object)))
    XCTAssertEqual(v3.contents, legacy.contents)
  }
}
