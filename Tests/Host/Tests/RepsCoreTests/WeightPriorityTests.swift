import Foundation
import XCTest

@testable import RepsCore

final class WeightPriorityTests: XCTestCase, @unchecked Sendable {
  private func load(_ grams: Int, count: Int) -> AvailableLoad {
    AvailableLoad(
      grams: grams,
      components: [
        WeightInventory.bag,
        LoadComponent(id: "item-\(grams)", name: "Item", grams: grams - 3000, quantity: count),
      ])
  }

  func testFewerObjectsWinsBeforeSpacingEvenWhenHeavier() {
    let input = [
      .bodyweight, AvailableLoad(grams: 3000, components: [WeightInventory.bag]),
      load(10000, count: 5), load(10200, count: 1), load(10700, count: 1),
    ]
    XCTAssertEqual(WeightInventory.spacedLoads(input).map(\.grams), [0, 3000, 10200, 10700])
    XCTAssertEqual(
      WeightInventory.spacedLoads(input.reversed()), WeightInventory.spacedLoads(input))
  }

  func testHigherPriorityChoiceBlocksBothLighterAndHeavierNeighbors() {
    let input = [load(10000, count: 5), load(10400, count: 1), load(10800, count: 2)]
    XCTAssertEqual(WeightInventory.spacedLoads(input).map(\.grams), [10400])
    XCTAssertEqual(
      WeightInventory.spacedLoads(input + [load(10900, count: 1)]).map(\.grams), [10400, 10900])
  }

  func testPhysicalCopiesAreCountedAndTiesPreferLowerWeight() {
    let input = [load(10500, count: 2), load(10000, count: 8), load(10200, count: 2)]
    XCTAssertEqual(WeightInventory.spacedLoads(input).map(\.grams), [10200])
    let boundary = [load(Int.max, count: 1), load(Int.max - 500, count: 1)]
    XCTAssertEqual(WeightInventory.spacedLoads(boundary).map(\.grams), [Int.max - 500, Int.max])
  }
}
