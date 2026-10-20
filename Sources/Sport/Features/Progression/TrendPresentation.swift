import SportCore
import SwiftUI

enum TrendPresentation {
  static func title(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "Average Added-Weight Volume per Set"
    case .repetitions: "Average Repetitions per Set"
    case .duration: "Average Work Time per Set"
    case .load: "Maximum Added Weight"
    }
  }
  static func summaryTitle(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "Total Added-Weight Volume"
    case .repetitions: "Total Repetitions"
    case .duration: "Total Work Time"
    default: title(metric)
    }
  }
  static func value(_ total: Int, metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "\(WorkoutLabels.weight(total)) kg"
    case .repetitions: "\(total) reps"
    case .duration: "\(WorkoutLabels.seconds(total)) s"
    case .load: "\(WorkoutLabels.weight(total)) kg"
    }
  }
  static func chartValue(_ value: Double, metric: SessionTrendMetric) -> String {
    let formatted = value.formatted(.number.precision(.fractionLength(0...2)))
    let unit = metric == .repetitions ? "reps" : metric == .duration ? "s" : "kg"
    return "\(formatted) \(unit)\(metric == .load ? "" : " per set")"
  }
  static func workoutTitle(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "Volume for This Workout"
    case .repetitions: "Repetitions for This Workout"
    case .duration: "Work Time for This Workout"
    case .load: "Maximum Added Weight"
    }
  }
  static func setCount(_ count: Int) -> String { "\(count) \(count == 1 ? "set" : "sets")" }
  static func unitDescription(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume:
      "The total adds completed workouts in the period. The curve shows average volume per set: repetitions × added weight. Details show workout totals. Bodyweight is excluded."
    case .repetitions:
      "The total adds all workouts shown in this period. Each point shows average repetitions per set, including all recorded loads. Details show workout totals."
    case .duration:
      "The total adds work time across all workouts in this period. Each point shows average work time per set. Details show workout totals. Rest is not included."
    case .load:
      "Heaviest added weight used in the workout. This number alone does not measure strength gains."
    }
  }
}
