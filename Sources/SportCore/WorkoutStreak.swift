import Foundation

public enum WorkoutStreak {
  public static func days(
    attendance: [AttendanceDay], workoutsPerWeek: Int, calendar: Calendar = .current
  ) -> Int {
    guard (1...7).contains(workoutsPerWeek), let last = attendance.last else { return 0 }
    var start: Date?
    var missed = 0
    for day in attendance {
      switch day.state {
      case .completed:
        if start == nil { start = day.date }
        missed = 0
      case .missed:
        if start != nil {
          missed += 1
          if missed >= workoutsPerWeek {
            start = nil
            missed = 0
          }
        }
      case .neutral:
        break
      }
    }
    guard let start else { return 0 }
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    return max(0, (local.dateComponents([.day], from: start, to: last.date).day ?? -1) + 1)
  }
}

public enum StreakDisplayUnit: String, CaseIterable, Sendable {
  case days, largestUnit
  public static let preferenceKey = "sport.streak.displayUnit"
  public func label(days: Int) -> String {
    let days = max(0, days)
    if self == .largestUnit {
      for (length, singular, plural) in [
        (365, "year", "years"), (30, "month", "months"), (7, "week", "weeks"),
      ] {
        if days >= length {
          let value = days / length
          return "\(value) \(value == 1 ? singular : plural)"
        }
      }
    }
    return "\(days) \(days == 1 ? "day" : "days")"
  }
}
