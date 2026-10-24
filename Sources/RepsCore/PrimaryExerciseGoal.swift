import Foundation

extension TrainingSnapshot {
  // Rank workout targets for the Progress subtitle; never adopt or modify a goal.
  public func primaryGoal(for exercise: TrainingExercise) -> ExerciseGoal? {
    var selected: ExerciseGoal?
    var selectedPriority = -1
    var selectedTotal = Decimal.zero
    for schedule in schedules where schedule.exerciseIDs.contains(exercise.id) {
      var target = exercise
      target.setCount = schedule.setCounts[exercise.id] ?? exercise.setCount
      guard let goal = schedule.goals[exercise.id], goal.isCompatible(with: target),
        (try? goal.validated()) != nil
      else { continue }

      let priority: Int
      let total: Decimal
      switch goal.definition.tracking {
      case .repetitions:
        priority = goal.load.grams > 0 ? 1 : 0
        let repetitions = (goal.repetitions ?? []).reduce(Decimal.zero) { $0 + Decimal($1) }
        total = repetitions * Decimal(goal.load.grams > 0 ? goal.load.grams : 1)
      case .duration:
        priority = 0
        total = (1...goal.definition.setCount).reduce(Decimal.zero) {
          $0 + Decimal(goal.durationTargetMS(forSet: $1) ?? 0)
        }
      }
      // Equal totals (including untimed targets) retain the stable workout order.
      if priority > selectedPriority || (priority == selectedPriority && total > selectedTotal) {
        selected = goal
        selectedPriority = priority
        selectedTotal = total
      }
    }
    return selected
  }
}
