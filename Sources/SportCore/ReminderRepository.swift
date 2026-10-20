import Foundation

extension SportRepository {
  func readNotificationPreferences() throws -> NotificationPreferences {
    guard let row = try database.query("SELECT * FROM notification_preferences WHERE id=1").first
    else { throw TrainingError.storage }
    return try NotificationPreferences(
      workoutsEnabled: row.integer("workouts_enabled") == 1,
      photosEnabled: row.integer("photos_enabled") == 1,
      photoMinutes: row.integer("photo_minutes"),
      weightEnabled: row.integer("weight_enabled") == 1,
      weightWeekday: row.optionalInteger("weight_weekday"),
      weightMinutes: row.optionalInteger("weight_minutes")
    ).validated()
  }
  func writeNotificationPreferences(_ preferences: NotificationPreferences) throws {
    let value = try preferences.validated()
    try database.execute(
      """
      UPDATE notification_preferences SET workouts_enabled=?,photos_enabled=?,photo_minutes=?,
      weight_enabled=?,weight_weekday=?,weight_minutes=? WHERE id=1
      """,
      [
        .integer(value.workoutsEnabled ? 1 : 0), .integer(value.photosEnabled ? 1 : 0),
        .integer(value.photoMinutes), .integer(value.weightEnabled ? 1 : 0),
        value.weightWeekday.map(SQLValue.integer) ?? .null,
        value.weightMinutes.map(SQLValue.integer) ?? .null,
      ])
  }
  public func reminderContext() throws -> ReminderContext {
    try database.transaction {
      let preferences = try readNotificationPreferences()
      let days = try database.query("SELECT DISTINCT schedule_id,day_key FROM workouts").map {
        row in
        ReminderDay(scheduleID: try row.text("schedule_id"), dayKey: try row.text("day_key"))
      }
      let weightDays = try database.query("SELECT day_key FROM body_weight_measurements").map {
        try $0.text("day_key")
      }
      return ReminderContext(
        training: try readSnapshot(), preferences: try preferences.validated(),
        startedDays: Set(days), bodyWeightDays: Set(weightDays))
    }
  }
  public func saveNotificationPreferences(_ preferences: NotificationPreferences) throws {
    try database.transaction {
      try writeNotificationPreferences(preferences)
    }
  }
}
