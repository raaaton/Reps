/// A future-workout assignment, independent of the progression being inspected.
public struct ExerciseWorkoutTarget: Identifiable, Equatable, Sendable {
  public var id: [String] { [schedule.id, exercise.id] }
  public let schedule: TrainingSchedule
  public let exercise: TrainingExercise
  public let goal: ExerciseGoal?
}

extension TrainingSnapshot {
  public func workoutTargets(for exercise: TrainingExercise) -> [ExerciseWorkoutTarget] {
    schedules.flatMap { schedule in
      schedule.exerciseIDs.compactMap { id in
        guard var planned = definition(exerciseID: id, variantID: schedule.variantIDs[id]),
          planned.parentExerciseID == exercise.parentExerciseID
        else { return nil }
        planned.setCount = schedule.setCounts[id] ?? planned.setCount
        return ExerciseWorkoutTarget(
          schedule: schedule, exercise: planned, goal: schedule.goals[id])
      }
    }
  }

  /// Presentation only: never adopts or copies targets between progressions.
  public func hasProgressionGoal(for exercise: TrainingExercise) -> Bool {
    let parentID = exercise.parentExerciseID
    func belongs(_ goal: ExerciseGoal) -> Bool {
      goal.definition.parentExerciseID == parentID
        || identityAliases.contains {
          $0.sourceID == goal.definition.id && $0.exerciseID == parentID
        }
    }
    return goals.contains(where: belongs)
      || variantGoals.contains { belongs($0.goal) }
      || schedules.contains {
        $0.goals.values.contains(where: belongs) || $0.baseGoals.values.contains(where: belongs)
      }
  }
}
