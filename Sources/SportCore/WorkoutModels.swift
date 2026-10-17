import Foundation

public enum WorkoutStatus: String, Codable, Sendable { case active, completed, cancelled }
public enum WorkoutPhase: Equatable, Sendable {
  case support, readySet, countdown, activeSet, completedSet, resting, feeling, completed, cancelled
}
public enum RestStatus: String, Codable, Sendable {
  case running, paused, finished, skipped, cancelled
}
public enum RestAction: Sendable { case pause, resume, skip }
public struct WorkoutSet: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let number: Int
  public let repetitions: Int?
  public let durationMS: Int?
  public let weightGrams: Int
  public let completedAt: Int
  public var components: [LoadComponent]? = nil
  public init(
    id: String, number: Int, repetitions: Int?, durationMS: Int?, weightGrams: Int,
    completedAt: Int, components: [LoadComponent]? = nil
  ) {
    self.id = id
    self.number = number
    self.repetitions = repetitions
    self.durationMS = durationMS
    self.weightGrams = weightGrams
    self.completedAt = completedAt
    self.components = components
  }
}
public struct WorkoutExercise: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let definition: TrainingExercise
  public let sets: [WorkoutSet]
  public let feelingTenths: Int?
  // For a timed set this can be a scheduled start, three seconds after Begin.
  public let setStartedAt: Int?
  public let setWeightGrams: Int?
  public let setEndedAt: Int?
  public var setComponents: [LoadComponent]? = nil
  public var goal: ExerciseGoal? = nil
  public init(
    id: String, definition: TrainingExercise, sets: [WorkoutSet], feelingTenths: Int?,
    setStartedAt: Int?, setWeightGrams: Int?, setEndedAt: Int?,
    setComponents: [LoadComponent]? = nil,
    goal: ExerciseGoal? = nil
  ) {
    self.id = id
    self.definition = definition
    self.sets = sets
    self.feelingTenths = feelingTenths
    self.setStartedAt = setStartedAt
    self.setWeightGrams = setWeightGrams
    self.setEndedAt = setEndedAt
    self.setComponents = setComponents
    self.goal = goal
  }
  public func countdownSeconds(at now: Int) -> Int {
    guard definition.tracking == .duration, let setStartedAt, now < setStartedAt else { return 0 }
    let (remaining, overflow) = setStartedAt.subtractingReportingOverflow(now)
    guard !overflow else { return 3 }
    return min(3, remaining / 1000 + (remaining % 1000 == 0 ? 0 : 1))
  }
}
public struct WorkoutRest: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let exerciseID: String
  public let afterSet: Int
  public let status: RestStatus
  public let deadline: Int?
  public let remainingMS: Int?
  public func remaining(at now: Int) -> Int {
    if status == .paused { return remainingMS ?? 0 }
    guard status == .running, let deadline, now < deadline else { return 0 }
    let (value, overflow) = deadline.subtractingReportingOverflow(now)
    return overflow ? Int.max : max(0, value)
  }
}
public struct WorkoutSession: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let scheduleID: String
  public let name: String
  public let dayKey: String
  public let startedAt: Int
  public let endedAt: Int?
  public let status: WorkoutStatus
  public let restSeconds: Int
  public let exercises: [WorkoutExercise]
  public let rest: WorkoutRest?
  public var support: WorkoutSupport? = nil
  public var workFinished: Bool { exercises.allSatisfy { $0.feelingTenths != nil } }
  public var currentSupport: WorkoutSupportStep? { support?.current(workFinished: workFinished) }
  public var isSupportRest: Bool { rest != nil && support?.restID == rest?.id }
  public var restDestination: WorkoutExercise? {
    guard let rest, rest.status == .running || rest.status == .paused else { return nil }
    if isSupportRest { return currentExercise }
    guard let index = exercises.firstIndex(where: { $0.id == rest.exerciseID }) else { return nil }
    let source = exercises[index]
    guard rest.afterSet == source.sets.count else { return nil }
    if rest.afterSet < source.definition.setCount { return source }
    guard rest.afterSet == source.definition.setCount, index + 1 < exercises.count else {
      return nil
    }
    return exercises[index + 1]
  }
  public var currentExercise: WorkoutExercise? {
    exercises.first { $0.feelingTenths == nil }
  }
  public var phase: WorkoutPhase { phase(at: WorkoutClock.now) }
  public func phase(at now: Int) -> WorkoutPhase {
    if status == .completed { return .completed }
    if status == .cancelled { return .cancelled }
    if isSupportRest, let rest, rest.status == .running || rest.status == .paused {
      return .resting
    }
    if currentSupport != nil { return .support }
    guard let exercise = currentExercise else { return .completed }
    if exercise.sets.count == exercise.definition.setCount { return .feeling }
    if let rest, restDestination?.id == exercise.id,
      rest.status == .running || rest.status == .paused
    {
      return .resting
    }
    if exercise.setEndedAt != nil { return .completedSet }
    if exercise.countdownSeconds(at: now) > 0 { return .countdown }
    return exercise.setStartedAt == nil ? .readySet : .activeSet
  }
}
public struct WorkoutSummary: Identifiable, Equatable, Sendable {
  public let id: String
  public let scheduleID: String
  public let name: String
  public let dayKey: String
  public let startedAt: Int
  public let endedAt: Int?
  public let status: WorkoutStatus
  public let setCount: Int
}
public struct WorkoutOverview: Equatable, Sendable {
  public let active: WorkoutSession?
  public let history: [WorkoutSummary]
  public let expiredRestIDs: [String]
  public var expiredStretchIDs: [String] = []
  public static let empty = WorkoutOverview(active: nil, history: [], expiredRestIDs: [])
}
public enum WorkoutWeight {
  public static func grams(_ input: String) throws -> Int {
    let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
      of: ",", with: ".")
    let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...2).contains(parts.count), !parts[0].isEmpty,
      parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
      parts.count == 1 || parts[1].count <= 3,
      let whole = Int(parts[0])
    else {
      throw TrainingError.invalid("Enter added weight in kg, with up to three decimal places.")
    }
    let fraction =
      parts.count == 2 ? Int(parts[1] + String(repeating: "0", count: 3 - parts[1].count))! : 0
    let (base, overflow) = whole.multipliedReportingOverflow(by: 1000)
    let (grams, additionOverflow) = base.addingReportingOverflow(fraction)
    guard !overflow, !additionOverflow else {
      throw TrainingError.invalid("This load is too high.")
    }
    return grams
  }
}

public enum WorkoutClock {
  public static var now: Int { Int(Date().timeIntervalSince1970 * 1000) }
  public static func date(_ milliseconds: Int) -> Date {
    Date(timeIntervalSince1970: Double(milliseconds) / 1000)
  }
  public static func dayKey(_ milliseconds: Int, calendar: Calendar = .current) -> String {
    var storageCalendar = Calendar(identifier: .gregorian)
    storageCalendar.timeZone = calendar.timeZone
    let parts = storageCalendar.dateComponents([.year, .month, .day], from: date(milliseconds))
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
  static func validate(_ now: Int) throws {
    guard (0...253_402_300_799_999).contains(now) else {
      throw TrainingError.invalid("The device date is invalid.")
    }
  }
  static func adding(_ duration: Int, to now: Int) throws -> Int {
    let (value, overflow) = now.addingReportingOverflow(duration)
    guard !overflow, duration > 0 else {
      throw TrainingError.invalid("The rest duration is too long.")
    }
    return value
  }
}
