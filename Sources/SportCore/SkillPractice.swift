import Foundation

public enum SkillPracticeState: String, Codable, Sendable {
  case preparation, ready, practicing, paused, countdown, attempt, resting, completed, skipped,
    cancelled
  public var isTerminal: Bool { self == .completed || self == .skipped || self == .cancelled }
}
public struct SkillOrigin: Codable, Equatable, Sendable {
  public var workoutID: String?
  public var workoutName: String?
  public var workoutDay: String?
  public var isDetached: Bool = false
  public init(workoutID: String? = nil, workoutName: String? = nil, workoutDay: String? = nil) {
    self.workoutID = workoutID
    self.workoutName = workoutName
    self.workoutDay = workoutDay
  }
  public var name: String {
    guard let workoutName else { return "Standalone Practice" }
    return isDetached ? "Previous Workout · \(workoutName)" : workoutName
  }
}
public struct SkillAttempt: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var number: Int
  public var startedAt: Int
  public var completedAt: Int
  public var durationMS: Int?
  public var repetitions: Int?
}
public enum SkillAction: Sendable {
  case begin, acknowledgePreparation, pause, resume, beginAttempt, cancelCountdown
  case recordAttempt(repetitions: Int?)
  case changeRest(RestAction)
  case finish(note: String, bestHoldMS: Int?)
  case skip, cancel
  case reviseConfiguration(SkillConfiguration)
  case reviseStep(String)
}
public struct SkillCommand: Sendable {
  public let practiceID: String
  public let commandID: String
  public let expectedRevision: Int
  public let action: SkillAction
  public init(
    practiceID: String, commandID: String = UUID().uuidString, expectedRevision: Int,
    action: SkillAction
  ) {
    self.practiceID = practiceID
    self.commandID = commandID
    self.expectedRevision = expectedRevision
    self.action = action
  }
}
public struct SkillPractice: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var definition: SkillDefinition
  public var assignment: SkillAssignment
  public var origin: SkillOrigin
  public var state: SkillPracticeState = .preparation
  public var revision: Int = 0
  public var lastCommandID: String?
  public var createdAt: Int
  public var lastEventAt: Int
  public var startedAt: Int?
  public var endedAt: Int?
  public var elapsedBeforeMS: Int = 0
  public var segmentStartedAt: Int?
  public var attemptStartedAt: Int?
  public var restDeadline: Int?
  public var restRemainingMS: Int?
  public var pausedFrom: SkillPracticeState?
  public var attempts: [SkillAttempt] = []
  public var note: String = ""
  public var bestHoldMS: Int?
  public init(
    definition: SkillDefinition, assignment: SkillAssignment, origin: SkillOrigin = SkillOrigin(),
    now: Int
  ) {
    id = UUID().uuidString
    self.definition = definition
    self.assignment = assignment
    self.origin = origin
    createdAt = now
    lastEventAt = now
  }
  public var step: SkillStep? { definition.steps.first { $0.id == assignment.stepID } }
  public var configuration: SkillConfiguration { assignment.configuration }
  public func elapsedMS(at now: Int) -> Int {
    elapsedBeforeMS + (segmentStartedAt.map { max(0, now - $0) } ?? 0)
  }
  public func restRemaining(at now: Int) -> Int {
    restRemainingMS ?? restDeadline.map { max(0, $0 - now) } ?? 0
  }
  public func countdown(at now: Int) -> Int {
    guard let start = attemptStartedAt, configuration.format == .timedHolds else { return 0 }
    return max(0, min(3, (start - now + 999) / 1000))
  }
  public var storageStatus: String { state.isTerminal ? state.rawValue : "active" }

  public func applying(_ command: SkillCommand, now: Int) throws -> Self {
    guard command.practiceID == id else { throw Self.stale }
    if command.commandID == lastCommandID { return self }
    guard command.expectedRevision == revision, !state.isTerminal else { throw Self.stale }
    try WorkoutClock.validate(now)
    guard now >= lastEventAt else {
      throw TrainingError.invalid("Check the device clock before continuing.")
    }
    var p = self
    // Expired rests reconcile from their absolute deadline, never from a new countdown.
    if p.state == .resting, p.restRemaining(at: now) == 0 {
      p.state = .ready
      p.restDeadline = nil
      p.restRemainingMS = nil
    }
    switch command.action {
    case .acknowledgePreparation:
      guard p.state == .preparation else { throw Self.stale }
      p.state = .ready
    case .begin:
      guard p.state == .ready, p.configuration.format == .freePractice else { throw Self.stale }
      p.startedAt = p.startedAt ?? now
      p.segmentStartedAt = now
      p.state = .practicing
    case .pause:
      guard p.state == .practicing || p.state == .resting || p.state == .ready else {
        throw Self.stale
      }
      p.pausedFrom = p.state
      p.stopSegment(at: now)
      if p.state == .resting {
        p.restRemainingMS = p.restRemaining(at: now)
        p.restDeadline = nil
      }
      p.state = .paused
    case .resume:
      guard p.state == .paused, let previous = p.pausedFrom else { throw Self.stale }
      p.state = previous
      p.pausedFrom = nil
      if p.startedAt != nil { p.segmentStartedAt = now }
      if previous == .resting {
        let remaining = p.restRemainingMS ?? 0
        p.restDeadline = remaining > 0 ? try WorkoutClock.adding(remaining, to: now) : nil
        p.restRemainingMS = nil
        if remaining == 0 { p.state = .ready }
      }
    case .beginAttempt:
      guard p.state == .ready, p.configuration.format != .freePractice,
        p.attempts.count < p.configuration.attemptCount
      else { throw Self.stale }
      p.startedAt = p.startedAt ?? now
      p.segmentStartedAt = p.segmentStartedAt ?? now
      p.attemptStartedAt =
        p.configuration.format == .timedHolds ? try WorkoutClock.adding(3000, to: now) : now
      p.state = p.configuration.format == .timedHolds ? .countdown : .attempt
    case .cancelCountdown:
      guard p.state == .countdown, let start = p.attemptStartedAt, now < start else {
        throw Self.stale
      }
      p.attemptStartedAt = nil
      p.state = .ready
    case .recordAttempt(let repetitions):
      guard p.state == .countdown || p.state == .attempt,
        let start = p.attemptStartedAt, now > start
      else { throw Self.stale }
      var duration: Int?
      if p.configuration.format == .timedHolds {
        guard repetitions == nil else { throw Self.stale }
        duration = now - start
      } else {
        guard let repetitions, (1...10000).contains(repetitions) else {
          throw TrainingError.invalid("Enter the actual repetitions, from 1 to 10000.")
        }
      }
      p.attempts.append(
        SkillAttempt(
          id: UUID().uuidString, number: p.attempts.count + 1,
          startedAt: start, completedAt: now, durationMS: duration, repetitions: repetitions))
      p.attemptStartedAt = nil
      p.state = .ready
      if p.attempts.count < p.configuration.attemptCount, p.configuration.restSeconds > 0 {
        p.restDeadline = try WorkoutClock.adding(p.configuration.restSeconds * 1000, to: now)
        p.state = .resting
      }
    case .changeRest(let action):
      if p.state == .ready, state == .resting {
        guard case .skip = action else { throw Self.stale }
        break
      }
      guard p.state == .resting || (p.state == .paused && p.pausedFrom == .resting) else {
        throw Self.stale
      }
      switch action {
      case .skip:
        if p.state == .paused, p.startedAt != nil { p.segmentStartedAt = now }
        p.restDeadline = nil
        p.restRemainingMS = nil
        p.pausedFrom = nil
        p.state = .ready
      case .pause:
        guard p.state == .resting else { throw Self.stale }
        p.restRemainingMS = p.restRemaining(at: now)
        p.restDeadline = nil
        p.stopSegment(at: now)
        p.pausedFrom = .resting
        p.state = .paused
      case .resume:
        guard p.state == .paused else { throw Self.stale }
        let remaining = p.restRemainingMS ?? 0
        p.restDeadline = remaining > 0 ? try WorkoutClock.adding(remaining, to: now) : nil
        p.restRemainingMS = nil
        p.pausedFrom = nil
        p.state = remaining > 0 ? .resting : .ready
        p.segmentStartedAt = now
      }
    case .finish(let note, let bestHoldMS):
      guard p.startedAt != nil, p.state != .countdown, p.state != .attempt else { throw Self.stale }
      try SkillValidation.optionalText(note)
      if let bestHoldMS, !(1...86_400_000).contains(bestHoldMS) {
        throw TrainingError.invalid("Enter a valid declared hold duration.")
      }
      p.note = note
      p.bestHoldMS = bestHoldMS
      p.finish(as: .completed, at: now)
    case .skip: p.finish(as: .skipped, at: now)
    case .cancel: p.finish(as: .cancelled, at: now)
    case .reviseConfiguration(let configuration):
      guard p.startedAt == nil else {
        throw TrainingError.invalid("Change the next block before starting it.")
      }
      p.assignment.configuration = try configuration.validated()
    case .reviseStep(let stepID):
      guard p.startedAt == nil, p.definition.steps.contains(where: { $0.id == stepID }) else {
        throw Self.stale
      }
      p.assignment.stepID = stepID
    }
    p.revision += 1
    p.lastCommandID = command.commandID
    p.lastEventAt = now
    return p
  }
  private mutating func stopSegment(at now: Int) {
    if let start = segmentStartedAt { elapsedBeforeMS += max(0, now - start) }
    segmentStartedAt = nil
  }
  private mutating func finish(as state: SkillPracticeState, at now: Int) {
    stopSegment(at: now)
    self.state = state
    endedAt = now
    attemptStartedAt = nil
    restDeadline = nil
    restRemainingMS = nil
    pausedFrom = nil
  }
  private static var stale: TrainingError {
    .invalid("The practice has changed. Return to the current block.")
  }
}
