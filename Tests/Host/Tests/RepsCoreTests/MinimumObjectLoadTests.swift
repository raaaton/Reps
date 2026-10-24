import Foundation
import XCTest

@testable import RepsCore

final class MinimumObjectLoadTests: XCTestCase, @unchecked Sendable {
  func testCountsPhysicalCopiesRatherThanGroupedLines() throws {
    let items = [
      WeightItem(id: "a-books", name: "Book", grams: 100, isEnabled: true, quantity: 10),
      WeightItem(id: "z-heavy", name: "Heavy", grams: 500, isEnabled: true, quantity: 2),
    ]
    let all = try WeightInventory.loads(items: items)
    let load = try XCTUnwrap(all.first { $0.grams == 4000 })
    XCTAssertEqual(load.components.map(\.id), ["base-bag", "z-heavy"])
    XCTAssertEqual(load.components.last?.quantity, 2)
    XCTAssertEqual(all.map(\.grams), all.map(\.grams).sorted())
    XCTAssertEqual(try WeightInventory.loads(items: items.reversed()), all)
  }

  func testOneHeavyObjectBeatsTenBooks() throws {
    let items = [
      WeightItem(id: "a-books", name: "Book", grams: 100, isEnabled: true, quantity: 10),
      WeightItem(id: "z-heavy", name: "Heavy", grams: 1000, isEnabled: true),
    ]
    let load = try XCTUnwrap(WeightInventory.loads(items: items).first { $0.grams == 4000 })
    XCTAssertEqual(load.components.map(\.id), ["base-bag", "z-heavy"])
    XCTAssertEqual(load.components.last?.quantity, 1)
  }

  func testTenObjectLimitLeavesInventoryLargerThanTenAndExcludesBag() throws {
    let items = [WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: 20)]
    let all = try WeightInventory.loads(items: items)
    XCTAssertEqual(all.count, 12)
    XCTAssertEqual(all.last?.grams, 4000)
    XCTAssertEqual(all.last?.components.last?.quantity, 10)
    XCTAssertEqual(all.last?.components.first, WeightInventory.bag)
  }

  func testCapAppliesAcrossDifferentItemTypes() throws {
    let items = [
      WeightItem(id: "a", name: "A", grams: 100, isEnabled: true, quantity: 8),
      WeightItem(id: "b", name: "B", grams: 100, isEnabled: true, quantity: 8),
      WeightItem(id: "c", name: "C", grams: 200, isEnabled: true),
    ]
    let all = try WeightInventory.loads(items: items)
    XCTAssertEqual(all.last?.grams, 4100)
    XCTAssertFalse(all.contains { $0.grams == 4200 })
    for load in all {
      XCTAssertLessThanOrEqual(
        load.components.filter { $0.id != "base-bag" }.reduce(0) { $0 + $1.quantity }, 10)
    }
  }

  func testMinimumIsExactRatherThanGreedyHeaviestFirstAndTiesAreStable() throws {
    let items = [
      WeightItem(id: "a", name: "Heavy", grams: 600, isEnabled: true),
      WeightItem(id: "b", name: "Medium", grams: 400, isEnabled: true, quantity: 2),
      WeightItem(id: "c", name: "Small", grams: 100, isEnabled: true, quantity: 2),
    ]
    let load = try XCTUnwrap(WeightInventory.loads(items: items).first { $0.grams == 3800 })
    XCTAssertEqual(load.components.map(\.id), ["base-bag", "b"])
    XCTAssertEqual(load.components.last?.quantity, 2)
    let equal = [
      WeightItem(id: "z", name: "Z", grams: 500, isEnabled: true),
      WeightItem(id: "a", name: "A", grams: 500, isEnabled: true),
    ]
    let tied = try XCTUnwrap(WeightInventory.loads(items: equal).first { $0.grams == 3500 })
    XCTAssertEqual(tied.components.last?.id, "a")
  }

  func testStillFeasibleSavedGoalRemainsUsableWhenANewerCompositionWins() async throws {
    let r = try RepsRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    for item in snapshot.weightItems { try await r.deleteWeightItem(id: item.id) }
    let books = WeightItem(id: "a-books", name: "Book", grams: 100, isEnabled: true, quantity: 10)
    try await r.saveWeightItem(books)
    let old = try XCTUnwrap(WeightInventory.loads(items: [books]).last)
    let context = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    let goal = ExerciseGoal(definition: context.exercise, load: old, repetitions: [8, 8, 8, 8])
    try await r.saveGoal(goal, original: context.adopted, scheduleID: "push")
    try await r.saveWeightItem(
      WeightItem(id: "z-heavy", name: "Heavy", grams: 1000, isEnabled: true))
    let after = try await r.snapshot()
    let all = try WeightInventory.loads(items: after.weightItems)
    XCTAssertEqual(all.first { $0.grams == 4000 }?.components.last?.id, "z-heavy")
    let current = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    XCTAssertTrue(current.isAvailable)
    XCTAssertEqual(current.adopted, goal)
    XCTAssertFalse(after.needsGoalReview(for: context.exercise, availableLoads: all))
    try await r.saveGoal(goal, original: goal, scheduleID: "push")
  }
}

extension MinimumObjectLoadTests {
  func testExactNonPreferredSelectionValidationAndPickerPreferTheMinimum() throws {
    var items = [
      WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: 10),
      WeightItem(id: "heavy", name: "Heavy", grams: 1000, isEnabled: true),
    ]
    let books = AvailableLoad(
      grams: 4000,
      components: [
        WeightInventory.bag, LoadComponent(id: "books", name: "Book", grams: 1000, quantity: 10),
      ])
    XCTAssertTrue(WeightInventory.isAvailable(books, items: items))
    let preferred = try WeightInventory.loads(items: items)
    let choices = WeightInventory.spacedLoads(preferred, retaining: books, items: items)
    XCTAssertEqual(choices.filter { $0.grams == 4000 }.count, 1)
    XCTAssertEqual(choices.first { $0.grams == 4000 }?.components.last?.id, "heavy")
    items[0].quantity = 9
    XCTAssertFalse(WeightInventory.isAvailable(books, items: items))
    items[0].quantity = 10
    items[0].isEnabled = false
    XCTAssertFalse(WeightInventory.isAvailable(books, items: items))
    items[0].isEnabled = true
    items[0].name = "Changed"
    XCTAssertFalse(WeightInventory.isAvailable(books, items: items))
  }

  func testNewSelectionRejectsMoreThanTenCopiesAndMalformedOrMissingBag() throws {
    let item = WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: 20)
    let eleven = AvailableLoad(
      grams: 4100,
      components: [
        WeightInventory.bag, LoadComponent(id: item.id, name: item.name, grams: 1100, quantity: 11),
      ])
    XCTAssertFalse(WeightInventory.isAvailable(eleven, items: [item]))
    for components in [
      [LoadComponent(id: item.id, name: item.name, grams: 100)],
      [WeightInventory.bag, WeightInventory.bag],
      [WeightInventory.bag, LoadComponent(id: item.id, name: item.name, grams: 200, quantity: 1)],
      [WeightInventory.bag, LoadComponent(id: item.id, name: item.name, grams: 100, quantity: 0)],
    ] {
      let malformed = AvailableLoad(
        grams: components.reduce(0) { $0 + $1.grams }, components: components)
      XCTAssertFalse(WeightInventory.isAvailable(malformed, items: [item]))
    }
    XCTAssertTrue(WeightInventory.isAvailable(.bodyweight, items: []))
    XCTAssertTrue(
      WeightInventory.isAvailable(
        AvailableLoad(grams: 3000, components: [WeightInventory.bag]), items: []))
  }

  func testOldSnapshotsAboveTenObjectsRemainReadableInBackups() async throws {
    let r = try RepsRepository(path: ":memory:")
    var archive = try await r.exportTraining(now: 1_791_720_000_000)
    let context = try await r.goalContext(exerciseID: "push-ups", scheduleID: "push")
    let old = AvailableLoad(
      grams: 4100,
      components: [
        WeightInventory.bag, LoadComponent(id: "old", name: "Old Book", grams: 1100, quantity: 11),
      ])
    archive.contents.configuration.goals = [
      ExerciseGoal(definition: context.exercise, load: old, repetitions: [8, 8, 8, 8])
    ]
    let decoded = try TrainingArchive.decode(archive.encoded())
    XCTAssertEqual(decoded.contents.configuration.goals.first?.load, old)
  }
}
