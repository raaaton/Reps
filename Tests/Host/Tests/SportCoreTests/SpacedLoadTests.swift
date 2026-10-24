import XCTest

@testable import SportCore

final class SpacedLoadTests: XCTestCase {
  private func loads(_ grams: [Int]) -> [AvailableLoad] {
    grams.map { AvailableLoad(grams: $0, components: []) }
  }
  func testKeepsLightestAndExactHalfKilogramBoundary() {
    let input = loads([10500, 10000, 10200, 10499, 11000])
    XCTAssertEqual(WeightInventory.spacedLoads(input).map(\.grams), [10000, 10500, 11000])
  }
  func testChainedNeighborsAreComparedToLastRetainedWeight() {
    XCTAssertEqual(
      WeightInventory.spacedLoads(loads([10000, 10400, 10800])).map(\.grams), [10000, 10800])
  }
  func testFilteringDoesNotDiscardSmallItemsBeforeTheyCanCombine() throws {
    let items = (0..<3).map { WeightItem(id: "\($0)", name: "Small", grams: 200, isEnabled: true) }
    let all = try WeightInventory.loads(items: items)
    XCTAssertEqual(WeightInventory.spacedLoads(all).map(\.grams), [0, 3000, 3600])
    XCTAssertEqual(all.map(\.grams), [0, 3000, 3200, 3400, 3600])
    XCTAssertEqual(all.last?.components.reduce(0) { $0 + $1.grams }, 3600)
  }
  func testExistingSelectionSurvivesOnlyWhenStillAvailable() {
    let all = loads([0, 3000, 3200, 3500])
    XCTAssertEqual(
      WeightInventory.spacedLoads(all, retaining: all[2]).map(\.grams), [0, 3000, 3200, 3500])
    XCTAssertEqual(
      WeightInventory.spacedLoads(all, retaining: loads([3300])[0]).map(\.grams), [0, 3000, 3500])
    XCTAssertEqual(WeightInventory.spacedLoads([]), [])
  }
}
