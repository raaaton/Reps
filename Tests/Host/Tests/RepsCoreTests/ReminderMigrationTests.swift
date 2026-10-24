import Foundation
import XCTest

@testable import RepsCore

final class ReminderMigrationTests: XCTestCase, @unchecked Sendable {
  func testVersionFourMigrationIsAdditiveAndDefaultsOff() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TABLE workout_sets(id TEXT,weight_grams INTEGER,load_components TEXT,duration_ms INTEGER)"
    )
    try db.execute("INSERT INTO workout_sets VALUES('saved',2375,'captured',NULL)")
    try db.execute(
      "CREATE TABLE weight_items(id TEXT PRIMARY KEY,name TEXT,grams INTEGER,enabled INTEGER)")
    try db.execute("CREATE TABLE exercises(id TEXT PRIMARY KEY,set_count INTEGER)")
    try db.execute(
      "CREATE TABLE schedule_exercises(schedule_id TEXT,exercise_id TEXT,position INTEGER)")
    try db.execute("CREATE TABLE preferences(id INTEGER PRIMARY KEY,rest_seconds INTEGER)")
    try db.execute("INSERT INTO preferences VALUES(1,180)")
    try db.execute("PRAGMA user_version=4")
    _ = try RepsRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 18)
    let row = try db.query("SELECT * FROM notification_preferences").first
    XCTAssertEqual(try row?.integer("workouts_enabled"), 0)
    XCTAssertEqual(try row?.integer("photos_enabled"), 0)
    XCTAssertEqual(try row?.integer("photo_minutes"), 360)
    XCTAssertEqual(
      try db.query("SELECT * FROM workout_sets").first?.text("load_components"), "captured")
    try db.execute("UPDATE notification_preferences SET photos_enabled=1,photo_minutes=377")
    _ = try RepsRepository(path: path)
    XCTAssertEqual(
      try db.query("SELECT photo_minutes FROM notification_preferences").first?.integer(
        "photo_minutes"), 377)
  }
}
