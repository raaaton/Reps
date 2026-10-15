import Foundation
import SportCore

// Display only; the database always stores integer milliseconds and grams.
enum WorkoutLabels {
  static func repetitionDescription(_ repetitions: [Int]) -> String {
    RepetitionNotation.groups(repetitions).map {
      "\($0.count) \($0.count == 1 ? "set" : "sets") of \($0.repetitions) repetitions"
    }.joined(separator: ", ")
  }

  static func day(_ key: String) -> String {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return key }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    guard
      let date = calendar.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    else { return key }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en")
    formatter.dateStyle = .long
    return formatter.string(from: date)
  }

  static func time(_ milliseconds: Int) -> String {
    let seconds = max(0, milliseconds / 1000)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  static func elapsed(_ milliseconds: Int) -> String {
    let seconds = max(0, milliseconds / 1000)
    let hours = seconds / 3600
    let minutes = seconds % 3600 / 60
    let remainder = seconds % 60
    return hours > 0 ? "\(hours) h \(minutes) min \(remainder) s" : "\(minutes) min \(remainder) s"
  }
  static func weight(_ grams: Int) -> String {
    let whole = grams / 1000
    let remainder = grams % 1000
    guard remainder != 0 else { return String(whole) }
    var fraction = String(format: "%03d", remainder)
    while fraction.last == "0" { fraction.removeLast() }
    return "\(whole)\(Locale.current.decimalSeparator ?? ",")\(fraction)"
  }

  static func performance(_ set: WorkoutSet) -> String {
    let result = set.repetitions.map { "\($0) reps" } ?? "\(time(set.durationMS ?? 0))"
    return "\(result) · \(weight(set.weightGrams)) kg"
  }

  static func feeling(_ tenths: Int) -> String {
    (Double(tenths) / 10).formatted(.number.precision(.fractionLength(1)))
  }
}
