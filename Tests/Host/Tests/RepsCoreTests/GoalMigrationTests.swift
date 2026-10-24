import Foundation
import XCTest

@testable import RepsCore

final class GoalMigrationTests: XCTestCase, @unchecked Sendable {
  func testMigrationFivePreservesNotificationsAndSnapshots() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TABLE notification_preferences(id INTEGER,workouts_enabled INTEGER,photos_enabled INTEGER,photo_minutes INTEGER)"
    )
    try db.execute("INSERT INTO notification_preferences VALUES(1,1,0,377)")
    try db.execute(
      "CREATE TABLE workout_sets(id TEXT,weight_grams INTEGER,load_components TEXT,duration_ms INTEGER)"
    )
    try db.execute("INSERT INTO workout_sets VALUES('old',2375,'snapshot',NULL)")
    try db.execute(
      "CREATE TABLE weight_items(id TEXT PRIMARY KEY,name TEXT,grams INTEGER,enabled INTEGER)")
    try db.execute("CREATE TABLE exercises(id TEXT PRIMARY KEY,set_count INTEGER)")
    try db.execute(
      "CREATE TABLE schedule_exercises(schedule_id TEXT,exercise_id TEXT,position INTEGER)")
    try db.execute("CREATE TABLE preferences(id INTEGER PRIMARY KEY,rest_seconds INTEGER)")
    try db.execute("INSERT INTO preferences VALUES(1,180)")
    try db.execute("PRAGMA user_version=5")
    _ = try RepsRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 20)
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
