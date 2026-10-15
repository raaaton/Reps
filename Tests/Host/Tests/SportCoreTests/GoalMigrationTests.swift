import Foundation
import XCTest

@testable import SportCore

final class GoalMigrationTests: XCTestCase, @unchecked Sendable {
  func testMigrationFivePreservesNotificationsAndSnapshots() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TABLE notification_preferences(id INTEGER,workouts_enabled INTEGER,photos_enabled INTEGER,photo_minutes INTEGER)"
    )
    try db.execute("INSERT INTO notification_preferences VALUES(1,1,0,377)")
    try db.execute("CREATE TABLE workout_sets(id TEXT,weight_grams INTEGER,load_components TEXT)")
    try db.execute("INSERT INTO workout_sets VALUES('old',2375,'snapshot')")
    try db.execute("PRAGMA user_version=5")
    _ = try SportRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 8)
    XCTAssertEqual(try db.query("SELECT count(*) AS n FROM exercise_goals").first?.integer("n"), 0)
    XCTAssertEqual(try db.query("SELECT count(*) AS n FROM workout_goals").first?.integer("n"), 0)
    XCTAssertEqual(
      try db.query("SELECT photo_minutes FROM notification_preferences").first?.integer(
        "photo_minutes"), 377)
    XCTAssertEqual(
      try db.query("SELECT load_components FROM workout_sets").first?.text("load_components"),
      "snapshot")
  }
}
