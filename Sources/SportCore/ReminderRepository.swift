import Foundation

extension SportRepository {
  public func reminderContext() throws -> ReminderContext {
    try database.transaction {
      guard let row = try database.query("SELECT * FROM notification_preferences WHERE id=1").first
      else { throw TrainingError.storage }
      let preferences = NotificationPreferences(
        workoutsEnabled: try row.integer("workouts_enabled") == 1,
        photosEnabled: try row.integer("photos_enabled") == 1,
        photoMinutes: try row.integer("photo_minutes"))
      let days = try database.query("SELECT DISTINCT schedule_id,day_key FROM workouts").map {
        row in
        ReminderDay(scheduleID: try row.text("schedule_id"), dayKey: try row.text("day_key"))
      }
      return ReminderContext(
        training: try readSnapshot(), preferences: try preferences.validated(),
        startedDays: Set(days))
    }
  }
  public func saveNotificationPreferences(_ preferences: NotificationPreferences) throws {
    let value = try preferences.validated()
    try database.transaction {
      try database.execute(
        "UPDATE notification_preferences SET workouts_enabled=?,photos_enabled=?,photo_minutes=? WHERE id=1",
        [
          .integer(value.workoutsEnabled ? 1 : 0), .integer(value.photosEnabled ? 1 : 0),
          .integer(value.photoMinutes),
        ])
    }
  }
}
