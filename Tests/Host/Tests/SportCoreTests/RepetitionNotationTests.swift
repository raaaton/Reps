import XCTest

@testable import SportCore

final class RepetitionNotationTests: XCTestCase {
  func testIdenticalAndMixedAdjacentSets() {
    XCTAssertEqual(RepetitionNotation.compact([10, 10, 10, 10]), "4×10")
    XCTAssertEqual(RepetitionNotation.compact([10, 10, 9, 9]), "2×10 2×9")
    XCTAssertEqual(RepetitionNotation.compact([10, 10, 9]), "2×10 1×9")
  }

  func testOrderEmptyAndSingleSetArePreserved() {
    XCTAssertEqual(RepetitionNotation.compact([10, 9, 10]), "1×10 1×9 1×10")
    XCTAssertEqual(RepetitionNotation.compact([]), "")
    XCTAssertEqual(RepetitionNotation.compact([8]), "1×8")
    let original = [12, 12, 10, 10, 12, 9, 9]
    XCTAssertEqual(
      RepetitionNotation.groups(original).flatMap {
        Array(repeating: $0.repetitions, count: $0.count)
      }, original)
  }
}
