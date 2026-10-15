import Foundation

public enum ProgressFact: Equatable, Sendable {
  case repetitionsAdded(Int, grams: Int)
  case durationAdded(Int, grams: Int)
  case effortLower(from: Int, to: Int)
  case loadChanged(from: Int, to: Int)
}
public enum ProgressFacts {
  static func comparable(
    current: WorkoutExercise, previous: WorkoutExercise, restSeconds: Int, previousRestSeconds: Int
  ) -> Bool {
    guard restSeconds == previousRestSeconds,
      current.definition.id == previous.definition.id,
      current.definition.tracking == previous.definition.tracking,
      current.sets.count == previous.sets.count, !current.sets.isEmpty,
      current.sets.count == current.definition.setCount,
      previous.sets.count == previous.definition.setCount,
      let weight = current.sets.first?.weightGrams,
      let oldWeight = previous.sets.first?.weightGrams, weight >= 0, oldWeight >= 0,
      current.sets.allSatisfy({ $0.weightGrams == weight }),
      previous.sets.allSatisfy({ $0.weightGrams == oldWeight })
    else { return false }
    return true
  }
  public static func compare(
    current: WorkoutExercise, previous: WorkoutExercise?, restSeconds: Int, previousRestSeconds: Int
  ) -> [ProgressFact] {
    guard let previous,
      comparable(
        current: current, previous: previous, restSeconds: restSeconds,
        previousRestSeconds: previousRestSeconds),
      let weight = current.sets.first?.weightGrams, let oldWeight = previous.sets.first?.weightGrams
    else { return [] }
    if weight > oldWeight { return [.loadChanged(from: oldWeight, to: weight)] }
    guard weight == oldWeight else { return [] }
    func total(_ sets: [WorkoutSet]) -> Int? {
      var result = 0
      for set in sets {
        let value = current.definition.tracking == .repetitions ? set.repetitions : set.durationMS
        guard let value, value > 0 else { return nil }
        let (sum, overflow) = result.addingReportingOverflow(value)
        guard !overflow else { return nil }
        result = sum
      }
      return result
    }
    guard let count = total(current.sets), let oldCount = total(previous.sets) else { return [] }
    var facts: [ProgressFact] = []
    if count > oldCount {
      facts.append(
        current.definition.tracking == .repetitions
          ? .repetitionsAdded(count - oldCount, grams: weight)
          : .durationAdded(count - oldCount, grams: weight))
    }
    if count >= oldCount, let feeling = current.feelingTenths,
      let previousFeeling = previous.feelingTenths,
      (0...100).contains(feeling), (0...100).contains(previousFeeling), feeling < previousFeeling
    {
      facts.append(.effortLower(from: previousFeeling, to: feeling))
    }
    return facts
  }
}
public struct ExerciseReport: Identifiable, Sendable {
  public var id: String { exerciseID }
  public let exerciseID: String
  public let name: String
  public let facts: [ProgressFact]
}
extension SportRepository {
  public func progressReports(workoutID: String) throws -> [ExerciseReport] {
    try database.transaction {
      let current = try readWorkout(id: workoutID)
      guard current.status == .completed, current.scheduleID != "manual" else { return [] }
      return try current.exercises.map { exercise in
        let rows = try database.query(
          "SELECT e.*,w.rest_seconds FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id WHERE e.catalogue_id=? AND w.status='completed' AND w.schedule_id!='manual' AND (w.day_key<? OR (w.day_key=? AND (w.started_at<? OR (w.started_at=? AND w.rowid<(SELECT rowid FROM workouts WHERE id=?))))) ORDER BY w.day_key DESC,w.started_at DESC,w.rowid DESC",
          [
            .text(exercise.definition.id), .text(current.dayKey), .text(current.dayKey),
            .integer(current.startedAt), .integer(current.startedAt), .text(current.id),
          ]
        )
        var previous: WorkoutExercise?
        var previousRest = 0
        for row in rows {
          let candidate = try readExercise(row)
          let rest = try row.integer("rest_seconds")
          if ProgressFacts.comparable(
            current: exercise, previous: candidate, restSeconds: current.restSeconds,
            previousRestSeconds: rest)
          {
            previous = candidate
            previousRest = rest
            break
          }
        }
        return ExerciseReport(
          exerciseID: exercise.definition.id, name: exercise.definition.name,
          facts: ProgressFacts.compare(
            current: exercise, previous: previous, restSeconds: current.restSeconds,
            previousRestSeconds: previousRest))
      }
    }
  }
}
