import XCTest

@testable import RepsCore

final class RestActivityPolicyTests: XCTestCase {
  func testAbsentRestAndPausedOrMovedDeadlineRetireCompletionsAndDuplicates() {
    let records = [
      RestActivityIdentity(id: "count", restID: "r", isCompletion: false, deadline: 100),
      RestActivityIdentity(id: "duplicate", restID: "r", isCompletion: false, deadline: 100),
      RestActivityIdentity(id: "finish", restID: "r", isCompletion: true, deadline: 100),
      RestActivityIdentity(id: "old", restID: "other", isCompletion: false, deadline: 100),
    ]
    let running = RestActivitySnapshot(
      restID: "r", workoutID: "w", exerciseName: "Exercice", nextSet: 2, deadline: 100,
      remainingMS: nil)
    XCTAssertEqual(
      RestActivityPolicy.retiredIDs(records: records, snapshot: running), ["duplicate", "old"])
    let paused = RestActivitySnapshot(
      restID: "r", workoutID: "w", exerciseName: "Exercice", nextSet: 2, deadline: nil,
      remainingMS: 70)
    XCTAssertEqual(
      RestActivityPolicy.retiredIDs(records: records, snapshot: paused),
      ["duplicate", "finish", "old"])
    let resumed = RestActivitySnapshot(
      restID: "r", workoutID: "w", exerciseName: "Exercice", nextSet: 2, deadline: 200,
      remainingMS: nil)
    XCTAssertEqual(
      RestActivityPolicy.retiredIDs(records: records, snapshot: resumed),
      ["duplicate", "finish", "old"])
    XCTAssertEqual(
      RestActivityPolicy.retiredIDs(records: records, snapshot: nil),
      ["count", "duplicate", "finish", "old"])
  }
}
