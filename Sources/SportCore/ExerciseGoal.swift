import Foundation

public struct ExerciseGoal: Codable, Equatable, Sendable {
  public let definition: TrainingExercise
  public var load: AvailableLoad
  public var repetitions: [Int]?
  public init(definition: TrainingExercise, load: AvailableLoad, repetitions: [Int]?) {
    self.definition = definition
    self.load = load
    self.repetitions = repetitions
  }
  public func isCompatible(with exercise: TrainingExercise) -> Bool {
    definition.id == exercise.id && definition.tracking == exercise.tracking
      && definition.setCount == exercise.setCount && definition.minimumReps == exercise.minimumReps
      && definition.maximumReps == exercise.maximumReps
      && definition.durationSeconds == exercise.durationSeconds
  }
  public func validated() throws -> Self {
    _ = try definition.validated()
    guard definition.setCount <= 1000, load.grams >= 0 else {
      throw TrainingError.invalid("This goal is too large or its load is invalid.")
    }
    switch definition.tracking {
    case .repetitions:
      guard let repetitions, repetitions.count == definition.setCount,
        repetitions.allSatisfy({ $0 > 0 })
      else { throw TrainingError.invalid("Enter a valid target for each set.") }
    case .duration:
      guard repetitions == nil else {
        throw TrainingError.invalid("This exercise tracks duration.")
      }
    }
    return self
  }
  static func encode(_ value: Self) throws -> SQLValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return .text(String(decoding: try encoder.encode(value), as: UTF8.self))
  }
  static func decode(_ text: String) throws -> Self {
    do { return try JSONDecoder().decode(Self.self, from: Data(text.utf8)).validated() } catch {
      throw TrainingError.storage
    }
  }
}
public enum GoalReason: Sendable {
  case initial, increaseLoad, decreaseLoad, addRepetition, keep, duration
}
public struct GoalSuggestion: Equatable, Sendable {
  public let goal: ExerciseGoal
  public let reason: GoalReason
  public let source: WorkoutExercise?
}
public struct GoalContext: Sendable {
  public let exercise: TrainingExercise
  public let adopted: ExerciseGoal?
  public let suggestion: GoalSuggestion?
  public let isAvailable: Bool
}
public enum GoalEngine {
  public static func matchingGoal(
    target: TrainingExercise, previous: WorkoutExercise, loads: [AvailableLoad],
    proposedLoad: AvailableLoad? = nil
  ) -> ExerciseGoal? {
    guard previous.definition.id == target.id, previous.definition.tracking == target.tracking,
      previous.definition.setCount == target.setCount,
      previous.definition.minimumReps == target.minimumReps,
      previous.definition.maximumReps == target.maximumReps,
      previous.definition.durationSeconds == target.durationSeconds,
      previous.sets.count == target.setCount,
      previous.sets.enumerated().allSatisfy({ $0.element.number == $0.offset + 1 }),
      Set(previous.sets.map(\.weightGrams)).count == 1,
      let grams = previous.sets.first?.weightGrams,
      let load = proposedLoad ?? loads.first(where: { $0.grams == grams })
    else { return nil }
    let reps: [Int]?
    if target.tracking == .repetitions {
      guard previous.sets.allSatisfy({ ($0.repetitions ?? 0) > 0 && $0.durationMS == nil }) else {
        return nil
      }
      reps = previous.sets.map { $0.repetitions ?? 0 }
    } else {
      guard previous.sets.allSatisfy({ $0.repetitions == nil && ($0.durationMS ?? 0) > 0 }) else {
        return nil
      }
      reps = nil
    }
    let goal = ExerciseGoal(definition: target, load: load, repetitions: reps)
    return (try? goal.validated()) == nil ? nil : goal
  }
  public static func suggestion(
    target: TrainingExercise, previous: WorkoutExercise?, loads: [AvailableLoad]
  ) -> GoalSuggestion? {
    guard (1...1000).contains(target.setCount) else { return nil }
    func result(_ load: AvailableLoad, _ reps: [Int]?, _ reason: GoalReason) -> GoalSuggestion? {
      let goal = ExerciseGoal(definition: target, load: load, repetitions: reps)
      guard (try? goal.validated()) != nil else { return nil }
      return GoalSuggestion(goal: goal, reason: reason, source: previous)
    }
    let assessment = Progression.assess(target: target, previous: previous, loads: loads)
    if assessment.status == .decrease, let load = assessment.nextLoad, let previous,
      var goal = matchingGoal(target: target, previous: previous, loads: loads, proposedLoad: load)
    {
      goal.load = load
      return GoalSuggestion(goal: goal, reason: .decreaseLoad, source: previous)
    }
    if target.tracking == .duration {
      let load =
        previous.flatMap { matchingGoal(target: target, previous: $0, loads: loads)?.load }
        ?? .bodyweight
      return result(load, nil, .duration)
    }
    guard let minimum = target.minimumReps, let maximum = target.maximumReps else { return nil }
    let baseline = Array(repeating: minimum, count: target.setCount)
    guard let previous, previous.definition.id == target.id,
      previous.definition.tracking == target.tracking, previous.definition.minimumReps == minimum,
      previous.definition.maximumReps == maximum, previous.sets.count == target.setCount,
      let feeling = previous.feelingTenths, (0...100).contains(feeling),
      previous.sets.enumerated().allSatisfy({
        $0.element.number == $0.offset + 1 && ($0.element.repetitions ?? 0) > 0
          && $0.element.durationMS == nil && $0.element.weightGrams >= 0
      })
    else { return result(.bodyweight, baseline, .initial) }
    if assessment.status == .increase, let load = assessment.nextLoad {
      return result(load, baseline, .increaseLoad)
    }
    guard Set(previous.sets.map(\.weightGrams)).count == 1,
      let grams = previous.sets.first?.weightGrams,
      let load = loads.first(where: { $0.grams == grams })
    else { return nil }
    var reps = previous.sets.map { $0.repetitions ?? minimum }
    if feeling < 80, let lowest = reps.min(), lowest < maximum,
      let index = reps.firstIndex(of: lowest)
    {
      reps[index] += 1
      return result(load, reps, .addRepetition)
    }
    return result(load, reps, .keep)
  }
}
