// Presentation events from persisted state. Never call on passive reloads or polling.
public enum WorkoutFeedback: Equatable, Sendable {
  case selection, success

  public static func change(from before: WorkoutOverview, to after: WorkoutOverview) -> Self? {
    guard let previous = before.active else {
      return after.active == nil ? nil : .selection
    }
    guard let current = after.active, current.id == previous.id else {
      return after.history.contains { $0.id == previous.id && $0.status == .completed }
        ? .success : nil
    }
    if (current.support?.steps.filter { $0.completedAt != nil }.count ?? 0)
      > (previous.support?.steps.filter { $0.completedAt != nil }.count ?? 0)
    {
      return .success
    }
    if current.currentSupport?.id != previous.currentSupport?.id { return .selection }
    if current.currentSupport?.tracking == .repetitions, previous.currentSupport?.startedAt == nil,
      current.currentSupport?.startedAt != nil
    {
      return .selection
    }
    if current.exercises.reduce(0, { $0 + $1.sets.count })
      > previous.exercises.reduce(0, { $0 + $1.sets.count })
    {
      return .success
    }
    if current.currentExercise?.id != previous.currentExercise?.id { return .selection }
    if let oldRest = previous.rest, let newRest = current.rest,
      oldRest.id == newRest.id, oldRest.status != newRest.status,
      [.running, .paused, .skipped].contains(newRest.status)
    {
      return .selection
    }
    // Timed starts already have a countdown and a distinct completion cue.
    if current.currentExercise?.definition.tracking == .repetitions,
      previous.currentExercise?.setStartedAt == nil,
      current.currentExercise?.setStartedAt != nil
    {
      return .selection
    }
    return nil
  }
}

public struct WorkoutFeedbackTracker {
  private var lastSignalled: WorkoutOverview?
  public init() {}

  public mutating func event(from before: WorkoutOverview, to after: WorkoutOverview)
    -> WorkoutFeedback?
  {
    guard let event = WorkoutFeedback.change(from: before, to: after),
      lastSignalled?.active != after.active || lastSignalled?.history != after.history
    else { return nil }
    lastSignalled = after
    return event
  }
}
