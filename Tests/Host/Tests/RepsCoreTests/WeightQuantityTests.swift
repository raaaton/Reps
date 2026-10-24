import Foundation
import XCTest

@testable import RepsCore

final class WeightQuantityTests: XCTestCase, @unchecked Sendable {
  let now = 1_791_720_000_000

  func testTenIdenticalBooksProduceOneLoadPerCountAndOneGroupedComponent() throws {
    let books = WeightItem(id: "book", name: "Book", grams: 100, isEnabled: true, quantity: 10)
    let loads = try WeightInventory.loads(items: [books])
    XCTAssertEqual(
      loads.map(\.grams), [0, 3000, 3100, 3200, 3300, 3400, 3500, 3600, 3700, 3800, 3900, 4000])
    let full = try XCTUnwrap(loads.last)
    XCTAssertEqual(full.components.count, 2)
    XCTAssertEqual(full.components[0], WeightInventory.bag)
    XCTAssertEqual(full.components[1].quantity, 10)
    XCTAssertEqual(full.components[1].grams, 1000)
    XCTAssertEqual(full.components[1].displayName, "Book × 10")
    XCTAssertEqual(full.components[1].unitGrams, 100)
    XCTAssertEqual(WeightInventory.spacedLoads(loads).map(\.grams), [0, 3000, 3500, 4000])
  }

  func testMixedQuantitiesDeduplicateTotalsAndIgnoreInventoryOrder() throws {
    let a = WeightItem(id: "a", name: "A", grams: 100, isEnabled: true, quantity: 2)
    let b = WeightItem(id: "b", name: "B", grams: 200, isEnabled: true)
    let disabled = WeightItem(id: "c", name: "Disabled", grams: 800, isEnabled: false, quantity: 10)
    let loads = try WeightInventory.loads(items: [a, b, disabled])
    XCTAssertEqual(loads.map(\.grams), [0, 3000, 3100, 3200, 3300, 3400])
    XCTAssertEqual(loads, try WeightInventory.loads(items: [disabled, b, a]))
    XCTAssertEqual(loads.last?.components.map(\.quantity), [1, 2, 1])
  }

  func testInvalidQuantitiesAndMultipliedOverflowAreRejected() throws {
    for quantity in [-1, 0, 1001, Int.max] {
      XCTAssertThrowsError(
        try WeightInventory.loads(items: [
          WeightItem(id: "bad", name: "Bad", grams: 100, isEnabled: true, quantity: quantity)
        ]))
    }
    XCTAssertThrowsError(
      try WeightInventory.loads(items: [
        WeightItem(
          id: "overflow", name: "Overflow", grams: Int.max / 2, isEnabled: true, quantity: 3)
      ]))
  }

  func testQuantityPersistsAndInvalidUpdateRollsBack() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    var item = WeightItem(id: "books", name: "Books", grams: 100, isEnabled: true, quantity: 10)
    try await r.saveWeightItem(item)
    let reopened = try RepsRepository(path: path)
    let before = try await reopened.snapshot()
    XCTAssertEqual(before.weightItems.first { $0.id == item.id }?.quantity, 10)
    item.quantity = 0
    do {
      try await reopened.saveWeightItem(item)
      XCTFail("Zero quantity accepted")
    } catch {}
    item.quantity = 1001
    item.isEnabled = false
    do {
      try await reopened.saveWeightItem(item)
      XCTFail("Invalid disabled quantity accepted")
    } catch {}
    let after = try await reopened.snapshot()
    XCTAssertEqual(after, before)
  }

  func testVersionSeventeenMigrationDefaultsToOneWithoutChangingGoalsOrHistory() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let before = try await r.exportTraining(now: now)
    let db = try SQLiteDatabase(path: path)
    try db.execute("ALTER TABLE weight_items DROP COLUMN quantity")
    try db.execute("PRAGMA user_version=17")
    let migrated = try RepsRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version")[0].integer("user_version"), 20)
    let after = try await migrated.exportTraining(now: now)
    XCTAssertEqual(after.contents, before.contents)
    XCTAssertTrue(after.contents.configuration.weightItems.allSatisfy { $0.quantity == 1 })
    _ = try RepsRepository(path: path)
    XCTAssertEqual(try db.query("SELECT count(*) AS n FROM weight_items")[0].integer("n"), 3)
  }

  func testActiveAndRecordedQuantitySnapshotsSurviveInventoryEditAndTransfers() async throws {
    let r = try RepsRepository(path: ":memory:")
    let snapshot = try await r.snapshot()
    for item in snapshot.weightItems { try await r.deleteWeightItem(id: item.id) }
    var item = WeightItem(id: "books", name: "Book", grams: 100, isEnabled: true, quantity: 10)
    try await r.saveWeightItem(item)
    var s = try XCTUnwrap(snapshot.schedules.first { $0.id == "pull-abs" })
    s.exerciseIDs = ["l-sit"]
    try await r.saveSchedule(s)
    let w = try await r.startWorkout(scheduleID: s.id, now: now)
    let e = try XCTUnwrap(w.currentExercise)
    let load = try XCTUnwrap(WeightInventory.loads(items: [item]).last)
    try await r.beginSet(
      workoutID: w.id, exerciseID: e.id, number: 1, weightGrams: 4000, load: load, now: now)
    item.quantity = 2
    item.name = "Renamed"
    try await r.saveWeightItem(item)
    let activeArchive = try await r.exportTraining(now: now + 1000)
    let target = try RepsRepository(path: ":memory:")
    let preview = try await target.previewArchiveImport(
      TrainingArchive.decode(activeArchive.encoded()), now: now + 1000)
    try await target.applyTrainingImport(preview, now: now + 1000)
    let active = try await target.workout(id: w.id)
    XCTAssertEqual(active.currentExercise?.setComponents, load.components)
    try await target.finishTimedSet(workoutID: w.id, exerciseID: e.id, number: 1, now: now + 10_000)
    try await target.cancelWorkout(id: w.id, now: now + 11_000)
    let saved = try await target.workout(id: w.id)
    XCTAssertEqual(saved.exercises.first?.sets.first?.components, load.components)
    let csv = try TrainingCSV.encode([saved])
    XCTAssertEqual(try TrainingCSV.decode(csv), [saved])
    let archive = try await target.exportTraining(now: now + 12_000)
    XCTAssertEqual(try TrainingArchive.decode(archive.encoded()).contents, archive.contents)
  }

  func testLegacyArchiveDefaultsMissingQuantitiesAndRejectsInvalidNewQuantities() async throws {
    let r = try RepsRepository(path: ":memory:")
    let archive = try await r.exportTraining(now: now)
    var root = try XCTUnwrap(
      JSONSerialization.jsonObject(with: archive.encoded()) as? [String: Any])
    var contents = try XCTUnwrap(root["contents"] as? [String: Any])
    var config = try XCTUnwrap(contents["configuration"] as? [String: Any])
    var items = try XCTUnwrap(config["weightItems"] as? [[String: Any]])
    for i in items.indices { items[i].removeValue(forKey: "quantity") }
    config["weightItems"] = items
    contents["configuration"] = config
    root["contents"] = contents
    config.removeValue(forKey: "maximumWeightObjects")
    config.removeValue(forKey: "backpackWeightGrams")
    contents["configuration"] = config
    root["contents"] = contents
    root["version"] = 6
    let legacy = try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root))
    XCTAssertEqual(legacy.version, 9)
    XCTAssertTrue(legacy.contents.configuration.weightItems.allSatisfy { $0.quantity == 1 })
    root["version"] = 7
    for bad: Any in [0, -1, 1001, 1.5, NSNull()] {
      items[0]["quantity"] = bad
      config["weightItems"] = items
      contents["configuration"] = config
      root["contents"] = contents
      XCTAssertThrowsError(try TrainingArchive.decode(JSONSerialization.data(withJSONObject: root)))
    }
  }
}
