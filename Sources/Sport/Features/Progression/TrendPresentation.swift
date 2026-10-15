import SportCore
import SwiftUI

enum TrendPresentation {
  static func title(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "Added-Weight Volume per Workout"
    case .repetitions: "Repetitions per Workout"
    case .duration: "Work Time per Workout"
    case .load: "Maximum Added Weight"
    }
  }
  static func summaryTitle(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "Total Added-Weight Volume"
    case .repetitions: "Total Repetitions"
    default: title(metric)
    }
  }
  static func value(_ total: Int, metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume: "\(WorkoutLabels.weight(total)) kg"
    case .repetitions: "\(total) reps"
    case .duration: "\(WorkoutLabels.weight(total)) s"
    case .load: "\(WorkoutLabels.weight(total)) kg"
    }
  }
  static func unitDescription(_ metric: SessionTrendMetric) -> String {
    switch metric {
    case .volume:
      "The total adds completed workouts in the period. The curve and callouts show each workout: repetitions × added weight. Bodyweight is excluded."
    case .repetitions:
      "The total adds all workouts shown in this period. Each point shows repetitions in one workout, including all recorded loads."
    case .duration:
      "Time recorded across all sets of the workout. Rest is not included."
    case .load:
      "Heaviest added weight used in the workout. This number alone does not measure strength gains."
    }
  }
}
