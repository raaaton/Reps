import Foundation

public struct RestActivitySnapshot: Equatable, Sendable {
  public let restID: String
  public let workoutID: String
  public let exerciseName: String
  public let nextSet: Int
  public let deadline: Int?
  public let remainingMS: Int?

  public var isPaused: Bool { deadline == nil }

  public static func current(in workout: WorkoutSession?, at now: Int) -> Self? {
    guard let workout, workout.status == .active, workout.phase(at: now) == .resting,
      let exercise = workout.currentExercise, let rest = workout.rest,
      rest.exerciseID == exercise.id, workout.isSupportRest || rest.afterSet == exercise.sets.count,
      rest.remaining(at: now) > 0
    else { return nil }
    return Self(
      restID: rest.id, workoutID: workout.id,
      exerciseName: workout.isSupportRest && workout.currentSupport?.kind == .warmUp
        ? exercise.definition.name + " · Warm-up" : exercise.definition.name,
      nextSet: workout.isSupportRest ? (workout.currentSupport?.number ?? 1) : rest.afterSet + 1,
      deadline: rest.deadline, remainingMS: rest.remainingMS)
  }
}
