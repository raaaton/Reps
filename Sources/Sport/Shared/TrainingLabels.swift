import Foundation
import SportCore

enum TrainingLabels {
  static func weekday(_ day: Int) -> String {
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: "en")
    let symbols = calendar.standaloneWeekdaySymbols
    return symbols[day % 7].localizedCapitalized
  }

  static func target(_ exercise: TrainingExercise) -> String {
    let sets = exercise.setCount == 1 ? "1 set" : "\(exercise.setCount) sets"
    switch exercise.tracking {
    case .repetitions:
      guard let minimum = exercise.minimumReps, let maximum = exercise.maximumReps else {
        return sets
      }
      let range = minimum == maximum ? "\(minimum)" : "\(minimum)–\(maximum)"
      return "\(exercise.setCount)×\(range) reps"
    case .duration:
      if let duration = exercise.durationSeconds { return "\(sets) · \(duration) s" }
      return "\(sets) · untimed"
    }
  }

  static func rest(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if minutes == 0 { return "\(remainder) s" }
    if remainder == 0 { return "\(minutes) min" }
    return "\(minutes) min \(remainder) s"
  }

  static func time(_ minutes: Int) -> Date {
    Calendar.current.date(
      from: DateComponents(
        year: 2001, month: 1, day: 15, hour: minutes / 60, minute: minutes % 60
      )) ?? Date()
  }
}
