import Foundation

enum SkillSchema {
  static func migrate(_ database: SQLiteDatabase) throws {
    for statement in [
      "CREATE TABLE IF NOT EXISTS skill_definitions(id TEXT PRIMARY KEY,payload TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS skill_progress(skill_id TEXT PRIMARY KEY REFERENCES skill_definitions(id) ON DELETE CASCADE,payload TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS schedule_skills(schedule_id TEXT PRIMARY KEY REFERENCES schedules(id) ON DELETE CASCADE,payload TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS workout_skills(workout_id TEXT PRIMARY KEY REFERENCES workouts(id) ON DELETE CASCADE,payload TEXT NOT NULL)",
      "CREATE TABLE IF NOT EXISTS skill_sessions(id TEXT PRIMARY KEY,status TEXT NOT NULL CHECK(status IN ('active','completed','cancelled','skipped')),payload TEXT NOT NULL)",
      "CREATE UNIQUE INDEX IF NOT EXISTS one_active_skill_session ON skill_sessions(status) WHERE status='active'",
    ] { try database.execute(statement) }
    for definition in SkillCatalogue.definitions {
      try database.execute(
        "INSERT OR IGNORE INTO skill_definitions VALUES(?,?)",
        [.text(definition.id), try SkillCoding.encode(definition)])
    }
    try database.execute("PRAGMA user_version=17")
  }
}
enum SkillCoding {
  static func encode<T: Encodable>(_ value: T) throws -> SQLValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return .text(String(decoding: try encoder.encode(value), as: UTF8.self))
  }
  static func decode<T: Decodable>(_ type: T.Type, _ payload: String) throws -> T {
    do { return try JSONDecoder().decode(type, from: Data(payload.utf8)) } catch {
      throw TrainingError.storage
    }
  }
}
