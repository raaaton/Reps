import Foundation

extension TrainingTransfer {
  static func text(_ value: String, limit: Int = 4096) throws {
    guard TrainingText.isValid(value, limit: limit) else { throw invalid }
  }
  static func unique(_ ids: [String]) throws {
    guard Set(ids).count == ids.count else { throw invalid }
    for id in ids { try text(id, limit: 256) }
  }
  static func components(_ items: [LoadComponent]?, grams: Int) throws {
    guard grams >= 0 else { throw invalid }
    guard let items else { return }
    guard items.count <= 1000 else { throw invalid }
    try unique(items.map(\.id))
    var sum = 0
    for item in items {
      try text(item.name)
      let (next, overflow) = sum.addingReportingOverflow(item.grams)
      guard item.grams > 0, !overflow else { throw invalid }
      sum = next
    }
    guard sum == grams else { throw invalid }
  }
  static func definition(_ value: TrainingExercise) throws {
    try text(value.id, limit: 256)
    try text(value.name)
    guard try value.validated() == value else { throw invalid }
  }
  static func goal(_ value: ExerciseGoal) throws {
    _ = try value.validated()
    try components(value.load.components, grams: value.load.grams)
  }
  private static func canonicalDate(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45 else { return false }
    return bytes.enumerated().allSatisfy {
      $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element)
    }
  }
  static func workouts(_ records: [WorkoutSession], now: Int? = nil) throws {
    guard records.count <= 10000, records.flatMap(\.exercises).count <= 100000,
      records.flatMap(\.exercises).flatMap(\.sets).count <= 100000
    else { throw invalid }
    try unique(records.map(\.id))
    try unique(records.flatMap(\.exercises).map(\.id))
    try unique(records.flatMap(\.exercises).flatMap(\.sets).map(\.id))
    for workout in records {
      try text(workout.name)
      try text(workout.scheduleID, limit: 256)
      guard workout.status != .active, workout.rest == nil, let end = workout.endedAt,
        end >= workout.startedAt, workout.restSeconds > 0,
        canonicalDate(workout.dayKey), TrainingAnalytics.date(for: workout.dayKey) != nil,
        now.map({ workout.dayKey <= WorkoutClock.dayKey($0) }) ?? true,
        workout.status != .completed || !workout.exercises.isEmpty
      else { throw invalid }
      try WorkoutClock.validate(workout.startedAt)
      try WorkoutClock.validate(end)
      try workout.support?.validate(workout: workout)
      try unique(workout.exercises.map { $0.definition.id })
      for exercise in workout.exercises {
        try definition(exercise.definition)
        guard exercise.definition.isEnabled,
          exercise.feelingTenths.map({ (0...100).contains($0) }) ?? (workout.status == .cancelled),
          workout.status != .completed || !exercise.sets.isEmpty
        else { throw invalid }
        if workout.status == .completed {
          guard exercise.setStartedAt == nil, exercise.setWeightGrams == nil,
            exercise.setEndedAt == nil, exercise.setComponents == nil
          else { throw invalid }
        }
        if let start = exercise.setStartedAt { try WorkoutClock.validate(start) }
        if let end = exercise.setEndedAt {
          try WorkoutClock.validate(end)
          guard let start = exercise.setStartedAt, end > start else { throw invalid }
        }
        if let grams = exercise.setWeightGrams {
          try components(exercise.setComponents, grams: grams)
        } else if exercise.setComponents != nil {
          throw invalid
        }
        if let goal = exercise.goal {
          try self.goal(goal)
          guard goal.definition.id == exercise.definition.id else { throw invalid }
        }
        for (index, set) in exercise.sets.enumerated() {
          guard set.number == index + 1,
            exercise.definition.tracking == .repetitions
              ? (set.repetitions ?? 0) > 0 && set.durationMS == nil
              : (set.durationMS ?? 0) > 0 && set.repetitions == nil
          else { throw invalid }
          try WorkoutClock.validate(set.completedAt)
          try components(set.components, grams: set.weightGrams)
        }
      }
    }
  }
  static func validate(_ data: TrainingDataSet) throws {
    let c = data.configuration
    guard c.exercises.count <= 1000, c.weightItems.count <= 1000, c.schedules.count <= 7,
      c.restSeconds > 0
    else { throw invalid }
    try unique(c.exercises.map(\.id))
    try unique(c.weightItems.map(\.id))
    try unique(c.schedules.map(\.id))
    try unique(c.goals.map { $0.definition.id })
    for ex in c.exercises { try definition(ex) }
    for item in c.weightItems {
      try text(item.name)
      guard item.grams > 0, item.id != WeightInventory.bag.id else { throw invalid }
    }
    _ = try WeightInventory.loads(items: c.weightItems)
    guard Set(c.schedules.map(\.weekday)).count == c.schedules.count else { throw invalid }
    for schedule in c.schedules {
      try text(schedule.name)
      try unique(schedule.exerciseIDs)
      guard (1...7).contains(schedule.weekday),
        schedule.reminderMinutes.map({ (0..<1440).contains($0) }) ?? true,
        schedule.exerciseIDs.allSatisfy({ id in c.exercises.contains { $0.id == id } }),
        !schedule.isEnabled || !c.exercises(for: schedule).isEmpty
      else { throw invalid }
    }
    for goal in c.goals {
      try self.goal(goal)
      guard c.exercises.contains(where: { $0.id == goal.definition.id }) else { throw invalid }
    }
    _ = try data.notifications.validated()
    try workouts(data.workouts)
  }
}
