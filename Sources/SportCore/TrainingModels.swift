import Foundation

public enum TrackingMode: String, CaseIterable, Codable, Sendable {
  case repetitions
  case duration
}

public struct TrainingExercise: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var tracking: TrackingMode
  public var setCount: Int
  public var minimumReps: Int?
  public var maximumReps: Int?
  public var durationSeconds: Int?
  public var isEnabled: Bool

  public init(
    id: String, name: String, tracking: TrackingMode, setCount: Int,
    minimumReps: Int?, maximumReps: Int?, durationSeconds: Int?, isEnabled: Bool
  ) {
    self.id = id
    self.name = name
    self.tracking = tracking
    self.setCount = setCount
    self.minimumReps = minimumReps
    self.maximumReps = maximumReps
    self.durationSeconds = durationSeconds
    self.isEnabled = isEnabled
  }

  public func validated() throws -> Self {
    var result = self
    result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !result.name.isEmpty else {
      throw TrainingError.invalid("Enter an exercise name.")
    }
    try TrainingText.validate(name: result.name, id: id)
    guard setCount > 0 else { throw TrainingError.invalid("Choose at least one set.") }
    switch tracking {
    case .repetitions:
      guard let minimumReps, let maximumReps, minimumReps > 0, maximumReps >= minimumReps else {
        throw TrainingError.invalid(
          "The maximum must be at least the minimum, with at least one repetition.")
      }
      result.durationSeconds = nil
    case .duration:
      if let durationSeconds, durationSeconds <= 0 {
        throw TrainingError.invalid("Enter a positive duration, or leave it blank.")
      }
      result.minimumReps = nil
      result.maximumReps = nil
    }
    return result
  }
}

public struct TrainingSchedule: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var weekday: Int
  public var isEnabled: Bool
  public var reminderMinutes: Int?
  public var exerciseIDs: [String]

  public init(
    id: String, name: String, weekday: Int, isEnabled: Bool,
    reminderMinutes: Int?, exerciseIDs: [String]
  ) {
    self.id = id
    self.name = name
    self.weekday = weekday
    self.isEnabled = isEnabled
    self.reminderMinutes = reminderMinutes
    self.exerciseIDs = exerciseIDs
  }
}

public struct TrainingSnapshot: Codable, Equatable, Sendable {
  public var exercises: [TrainingExercise]
  public var schedules: [TrainingSchedule]
  public var restSeconds: Int
  public var weightItems: [WeightItem] = []
  public var goals: [ExerciseGoal] = []

  public func exercises(for schedule: TrainingSchedule) -> [TrainingExercise] {
    schedule.exerciseIDs.compactMap { id in exercises.first { $0.id == id && $0.isEnabled } }
  }

  public func schedule(on date: Date, calendar: Calendar = .current) -> TrainingSchedule? {
    schedules.first {
      $0.isEnabled && $0.weekday == Self.isoWeekday(on: date, calendar: calendar)
        && !exercises(for: $0).isEmpty
    }
  }

  public func schedulesEmptied(removingExerciseID id: String) -> [TrainingSchedule] {
    schedules.filter {
      $0.isEnabled && $0.exerciseIDs.contains(id)
        && exercises(for: $0).allSatisfy { $0.id == id }
    }
  }

  public static func isoWeekday(on date: Date, calendar: Calendar = .current) -> Int {
    (calendar.component(.weekday, from: date) + 5) % 7 + 1
  }
}

public enum TrainingError: Error, LocalizedError, Sendable {
  case invalid(String)
  case storage
  case newerSchema

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): message
    case .storage:
      "Unable to access local data. Try again without deleting Sport."
    case .newerSchema:
      "These data require a newer version of Sport. They have been preserved."
    }
  }
}
