import Foundation

public enum StretchMovement: String, Codable, CaseIterable, Sendable {
  case quadriceps, shoulders, upperBack
  public var name: String {
    switch self {
    case .quadriceps: "Standing Quad Stretch"
    case .shoulders: "Cross-body Shoulder Stretch"
    case .upperBack: "Upper Back Stretch"
    }
  }
  public var instructions: String {
    switch self {
    case .quadriceps:
      "Use a wall for balance. Hold your ankle behind you, keep your knees close and gently bring your heel toward your glutes. Switch legs for the second hold."
    case .shoulders:
      "Bring one arm across your chest. Support it above the elbow with the other hand, keeping your shoulder relaxed. Switch arms for the second hold."
    case .upperBack:
      "Clasp your hands in front of you at shoulder height. Reach forward gently, allowing your upper back to round. Keep your neck relaxed."
    }
  }
  public var sides: Int { self == .upperBack ? 1 : 2 }
  public static func suggested(firstID: String) -> Self {
    switch firstID {
    case "bulgarians": .quadriceps
    case "push-ups", "pike-push-ups": .shoulders
    default: .upperBack
    }
  }
}
public enum SupportKind: String, Codable, Sendable { case warmUp, stretch }
public struct WorkoutSupportStep: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let kind: SupportKind
  public let name: String
  public let instructions: String
  public let number: Int
  public let count: Int
  public let tracking: TrackingMode
  public let targetRepetitions: Int?
  public let targetDurationMS: Int?
  public let restAfterMS: Int
  public var startedAt: Int? = nil
  public var completedAt: Int? = nil
  public var repetitions: Int? = nil
  public var durationMS: Int? = nil
  public var automaticDeadline: Int? {
    guard kind == .stretch, completedAt == nil, let startedAt, let targetDurationMS else {
      return nil
    }
    return try? WorkoutClock.adding(targetDurationMS, to: startedAt)
  }
  public func countdown(at now: Int) -> Int {
    guard tracking == .duration, let startedAt, startedAt > now else { return 0 }
    return min(3, (startedAt - now + 999) / 1000)
  }
}
public struct WorkoutSupport: Codable, Equatable, Sendable {
  public var steps: [WorkoutSupportStep]
  public var restID: String? = nil
  public var restAnchorID: String? = nil
  public func current(workFinished: Bool) -> WorkoutSupportStep? {
    steps.first { $0.completedAt == nil && ($0.kind == .warmUp || workFinished) }
  }
  public static func make(
    first: WorkoutExercise, restSeconds: Int, stretch: StretchMovement,
    stretchSeconds: Int
  ) throws -> Self {
    guard restSeconds > 0, (5...600).contains(stretchSeconds) else {
      throw TrainingError.invalid("Choose a stretch duration from 5 to 600 seconds.")
    }
    let (restMS, overflow) = restSeconds.multipliedReportingOverflow(by: 1000)
    guard !overflow else { throw TrainingError.invalid("The rest duration is too long.") }
    let d = first.definition
    let weighted = (first.goal?.load.grams ?? 0) > 0
    let count = weighted ? 1 : 2
    let reps = first.goal?.repetitions?.first ?? d.minimumReps ?? 1
    let seconds = d.durationSeconds
    let (targetMS, targetOverflow) = (seconds ?? 0).multipliedReportingOverflow(by: 1000)
    guard !targetOverflow else { throw TrainingError.invalid("The target duration is too long.") }
    var steps = (1...count).map { number in
      WorkoutSupportStep(
        id: UUID().uuidString, kind: .warmUp, name: d.name,
        instructions: "Use bodyweight only. Move smoothly and keep the effort easy.",
        number: number, count: count, tracking: d.tracking,
        targetRepetitions: d.tracking == .repetitions ? (weighted ? reps : max(1, reps / 2)) : nil,
        targetDurationMS: d.tracking == .duration && seconds != nil
          ? (weighted ? targetMS : max(1, targetMS / 2)) : nil,
        restAfterMS: number == count ? restMS : restMS / 2)
    }
    for number in 1...stretch.sides {
      steps.append(
        WorkoutSupportStep(
          id: UUID().uuidString, kind: .stretch, name: stretch.name,
          instructions: stretch.instructions
            + " Breathe normally. Hold comfortably, without bouncing or pain.",
          number: number, count: stretch.sides, tracking: .duration, targetRepetitions: nil,
          targetDurationMS: stretchSeconds * 1000, restAfterMS: 0))
    }
    return Self(steps: steps)
  }
  public func validate(workout: WorkoutSession) throws {
    guard !workout.exercises.isEmpty, (2...4).contains(steps.count),
      Set(steps.map(\.id)).count == steps.count,
      (1...2).contains(steps.filter { $0.kind == .warmUp }.count),
      (1...2).contains(steps.filter { $0.kind == .stretch }.count)
    else { throw TrainingTransfer.invalid }
    for kind in [SupportKind.warmUp, .stretch] {
      let group = steps.filter { $0.kind == kind }
      guard Set(group.map(\.name)).count == 1,
        group.enumerated().allSatisfy({
          $0.element.number == $0.offset + 1 && $0.element.count == group.count
        })
      else { throw TrainingTransfer.invalid }
    }
    if let restID { try TrainingTransfer.text(restID, limit: 256) }
    if let restAnchorID { try TrainingTransfer.text(restAnchorID, limit: 256) }
    var latest = workout.startedAt
    var pending = false
    var stretching = false
    for step in steps {
      try TrainingTransfer.text(step.id, limit: 256)
      try TrainingTransfer.text(step.name)
      try TrainingTransfer.text(step.instructions)
      guard (1...2).contains(step.number), (1...2).contains(step.count), step.number <= step.count,
        step.restAfterMS >= 0,
        step.targetRepetitions.map({ $0 > 0 }) ?? true,
        step.targetDurationMS.map({ $0 > 0 }) ?? true
      else { throw TrainingTransfer.invalid }
      if step.kind == .stretch { stretching = true }
      guard !stretching || step.kind == .stretch else { throw TrainingTransfer.invalid }
      if step.tracking == .repetitions {
        guard step.targetRepetitions != nil, step.targetDurationMS == nil, step.durationMS == nil
        else { throw TrainingTransfer.invalid }
      } else {
        guard step.targetRepetitions == nil, step.repetitions == nil else {
          throw TrainingTransfer.invalid
        }
      }
      if let start = step.startedAt {
        try WorkoutClock.validate(start)
        guard start >= workout.startedAt else { throw TrainingTransfer.invalid }
      }
      if let end = step.completedAt {
        try WorkoutClock.validate(end)
        guard !pending, let start = step.startedAt, start >= latest, end > start,
          end <= (workout.endedAt ?? end),
          step.tracking == .repetitions
            ? (step.repetitions ?? 0) > 0 : step.durationMS == end - start
        else { throw TrainingTransfer.invalid }
        latest = end
      } else {
        pending = true
        guard step.repetitions == nil, step.durationMS == nil else {
          throw TrainingTransfer.invalid
        }
      }
    }
    guard workout.status != .completed || !pending else { throw TrainingTransfer.invalid }
  }
}
