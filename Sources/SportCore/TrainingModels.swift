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
  public var setCounts: [String: Int]
  public var goals: [String: ExerciseGoal]
  public var skills: [SkillAssignment] = []
  public var skillPlacement: SkillPlacement = .beforeForce

  public init(
    id: String, name: String, weekday: Int, isEnabled: Bool,
    reminderMinutes: Int?, exerciseIDs: [String], setCounts: [String: Int] = [:],
    goals: [String: ExerciseGoal] = [:], skills: [SkillAssignment] = [],
    skillPlacement: SkillPlacement = .beforeForce
  ) {
    self.id = id
    self.name = name
    self.weekday = weekday
    self.isEnabled = isEnabled
    self.reminderMinutes = reminderMinutes
    self.exerciseIDs = exerciseIDs
    self.setCounts = setCounts
    self.goals = goals
    self.skills = skills
    self.skillPlacement = skillPlacement
  }

  enum CodingKeys: String, CodingKey {
    case id, name, weekday, isEnabled, reminderMinutes, exerciseIDs, setCounts, goals, skills,
      skillPlacement
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    weekday = try c.decode(Int.self, forKey: .weekday)
    isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
    reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes)
    exerciseIDs = try c.decode([String].self, forKey: .exerciseIDs)
    setCounts = try c.decodeIfPresent([String: Int].self, forKey: .setCounts) ?? [:]
    goals = try c.decodeIfPresent([String: ExerciseGoal].self, forKey: .goals) ?? [:]
    skills = try c.decodeIfPresent([SkillAssignment].self, forKey: .skills) ?? []
    skillPlacement =
      try c.decodeIfPresent(SkillPlacement.self, forKey: .skillPlacement) ?? .beforeForce
  }

}

public struct TrainingSnapshot: Codable, Equatable, Sendable {
  public var exercises: [TrainingExercise]
  public var schedules: [TrainingSchedule]
  public var restSeconds: Int
  public var weightItems: [WeightItem] = []
  public var goals: [ExerciseGoal] = []
  public var stretchingEnabled: Bool = true
  public var skills: [SkillDefinition] = []
  public var skillProgress: [SkillProgress] = []

  public init(
    exercises: [TrainingExercise], schedules: [TrainingSchedule], restSeconds: Int,
    weightItems: [WeightItem] = [], goals: [ExerciseGoal] = [], stretchingEnabled: Bool = true,
    skills: [SkillDefinition] = [], skillProgress: [SkillProgress] = []
  ) {
    self.exercises = exercises
    self.schedules = schedules
    self.restSeconds = restSeconds
    self.weightItems = weightItems
    self.goals = goals
    self.stretchingEnabled = stretchingEnabled
    self.skills = skills
    self.skillProgress = skillProgress
  }

  enum CodingKeys: String, CodingKey {
    case exercises, schedules, restSeconds, weightItems, goals, stretchingEnabled, skills,
      skillProgress
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    exercises = try c.decode([TrainingExercise].self, forKey: .exercises)
    schedules = try c.decode([TrainingSchedule].self, forKey: .schedules)
    restSeconds = try c.decode(Int.self, forKey: .restSeconds)
    weightItems = try c.decode([WeightItem].self, forKey: .weightItems)
    goals = try c.decode([ExerciseGoal].self, forKey: .goals)
    stretchingEnabled = try c.decodeIfPresent(Bool.self, forKey: .stretchingEnabled) ?? true
    skills =
      try c.decodeIfPresent([SkillDefinition].self, forKey: .skills) ?? SkillCatalogue.definitions
    skillProgress = try c.decodeIfPresent([SkillProgress].self, forKey: .skillProgress) ?? []
  }

  public func exercises(for schedule: TrainingSchedule) -> [TrainingExercise] {
    schedule.exerciseIDs.compactMap { id in
      guard var exercise = exercises.first(where: { $0.id == id && $0.isEnabled }) else {
        return nil
      }
      exercise.setCount = schedule.setCounts[id] ?? exercise.setCount
      return exercise
    }
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
