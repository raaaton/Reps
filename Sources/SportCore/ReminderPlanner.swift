import Foundation

public struct NotificationPreferences: Codable, Equatable, Sendable {
  public var workoutsEnabled: Bool
  public var photosEnabled: Bool
  public var photoMinutes: Int
  public var weightEnabled: Bool
  public var weightWeekday: Int?
  public var weightMinutes: Int?
  public init(
    workoutsEnabled: Bool = false, photosEnabled: Bool = false, photoMinutes: Int = 360,
    weightEnabled: Bool = false, weightWeekday: Int? = nil, weightMinutes: Int? = nil
  ) {
    self.workoutsEnabled = workoutsEnabled
    self.photosEnabled = photosEnabled
    self.photoMinutes = photoMinutes
    self.weightEnabled = weightEnabled
    self.weightWeekday = weightWeekday
    self.weightMinutes = weightMinutes
  }
  private enum CodingKeys: String, CodingKey {
    case workoutsEnabled, photosEnabled, photoMinutes, weightEnabled, weightWeekday, weightMinutes
  }
  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    workoutsEnabled = try values.decode(Bool.self, forKey: .workoutsEnabled)
    photosEnabled = try values.decode(Bool.self, forKey: .photosEnabled)
    photoMinutes = try values.decode(Int.self, forKey: .photoMinutes)
    weightEnabled = try values.decodeIfPresent(Bool.self, forKey: .weightEnabled) ?? false
    weightWeekday = try values.decodeIfPresent(Int.self, forKey: .weightWeekday)
    weightMinutes = try values.decodeIfPresent(Int.self, forKey: .weightMinutes)
  }
  public func validated() throws -> Self {
    guard (0..<1440).contains(photoMinutes) else {
      throw TrainingError.invalid("Choose a valid reminder time.")
    }
    if let weightWeekday, !(1...7).contains(weightWeekday) {
      throw TrainingError.invalid("Choose a valid reminder day.")
    }
    if let weightMinutes, !(0..<1440).contains(weightMinutes) {
      throw TrainingError.invalid("Choose a valid reminder time.")
    }
    if weightEnabled && (weightWeekday == nil || weightMinutes == nil) {
      throw TrainingError.invalid("Choose a day and time for your body weight reminder.")
    }
    return self
  }
}
public struct ReminderDay: Hashable, Sendable {
  public let scheduleID: String
  public let dayKey: String
}
public struct ReminderContext: Equatable, Sendable {
  public var training: TrainingSnapshot
  public var preferences: NotificationPreferences
  public var startedDays: Set<ReminderDay>
  public var bodyWeightDays: Set<String> = []
}
public enum ReminderKind: String, Sendable { case workout, photos, bodyWeight }
public struct ReminderOccurrence: Equatable, Sendable {
  public let id: String
  public let kind: ReminderKind
  public let title: String
  public let body: String
  public let components: DateComponents
  public let repeats: Bool
  public let date: Date?
  public init(
    id: String, kind: ReminderKind, title: String, body: String, components: DateComponents,
    repeats: Bool, date: Date?
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.body = body
    self.components = components
    self.repeats = repeats
    self.date = date
  }
}
public enum ReminderPlanner {
  public static func bodyWeightIdentifier(dayKey: String) -> String {
    "sport.local.bodyweight.\(dayKey)"
  }
  public static func plan(context: ReminderContext, now: Date, calendar: Calendar = .current) throws
    -> [ReminderOccurrence]
  {
    _ = try context.preferences.validated()
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    var result: [ReminderOccurrence] = []
    if context.preferences.workoutsEnabled {
      let start = local.startOfDay(for: now)
      for offset in 0..<28 {
        guard let day = local.date(byAdding: .day, value: offset, to: start),
          let schedule = context.training.schedule(on: day, calendar: local),
          let minutes = schedule.reminderMinutes
        else { continue }
        guard (0..<1440).contains(minutes) else { throw TrainingError.storage }
        let key = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000), calendar: local)
        guard !context.startedDays.contains(ReminderDay(scheduleID: schedule.id, dayKey: key)),
          let occurrence = local.nextDate(
            after: day.addingTimeInterval(-1),
            matching: DateComponents(hour: minutes / 60, minute: minutes % 60, second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first),
          local.isDate(occurrence, inSameDayAs: day), occurrence > now
        else { continue }
        let components = local.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: occurrence)
        result.append(
          ReminderOccurrence(
            id: "sport.local.workout.\(schedule.id).\(key)", kind: .workout,
            title: "🏋️‍♂️ \(schedule.name)",
            body: "Your workout is scheduled for today.", components: components,
            repeats: false, date: occurrence))
      }
    }
    if context.preferences.weightEnabled,
      let weekday = context.preferences.weightWeekday,
      let minutes = context.preferences.weightMinutes
    {
      let start = local.startOfDay(for: now)
      for offset in 0..<28 {
        guard let day = local.date(byAdding: .day, value: offset, to: start),
          (local.component(.weekday, from: day) + 5) % 7 + 1 == weekday
        else { continue }
        let key = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000), calendar: local)
        guard !context.bodyWeightDays.contains(key),
          let occurrence = local.nextDate(
            after: day.addingTimeInterval(-1),
            matching: DateComponents(hour: minutes / 60, minute: minutes % 60, second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first),
          local.isDate(occurrence, inSameDayAs: day), occurrence > now
        else { continue }
        result.append(
          ReminderOccurrence(
            id: bodyWeightIdentifier(dayKey: key), kind: .bodyWeight,
            title: "Weekly Check-In", body: "Your body weight check-in is scheduled for today.",
            components: local.dateComponents(
              [.year, .month, .day, .hour, .minute, .second], from: occurrence),
            repeats: false, date: occurrence))
      }
    }
    if context.preferences.photosEnabled {
      result.append(
        ReminderOccurrence(
          id: "sport.local.photos.monthly", kind: .photos, title: "📸 Monthly progress check",
          body: "Time to review your progress.",
          components: DateComponents(
            day: 1, hour: context.preferences.photoMinutes / 60,
            minute: context.preferences.photoMinutes % 60, second: 0), repeats: true, date: nil))
    }
    return result
  }
}
