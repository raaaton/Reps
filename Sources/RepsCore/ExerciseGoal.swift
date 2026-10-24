import Foundation

public struct ExerciseGoal: Codable, Equatable, Sendable {
  public let definition: TrainingExercise
  public var load: AvailableLoad
  public var repetitions: [Int]?
  public var durationsMS: [Int]?
  public init(
    definition: TrainingExercise, load: AvailableLoad, repetitions: [Int]?,
    durationsMS: [Int]? = nil
  ) {
    self.definition = definition
    self.load = load
    self.repetitions = repetitions
    self.durationsMS = durationsMS
  }
  // The catalogue edit accepts the new definition, while each workout keeps its load and count.
  func reconciled(to target: TrainingExercise) throws -> Self {
    guard definition.id == target.id, (1...1000).contains(target.setCount) else {
      throw TrainingError.storage
    }
    let repetitions: [Int]?
    if target.tracking == .repetitions {
      let minimum = target.minimumReps ?? 1
      let maximum = target.maximumReps ?? minimum
      let previous = definition.tracking == .repetitions ? self.repetitions ?? [] : []
      let rangeChanged =
        definition.minimumReps != target.minimumReps
        || definition.maximumReps != target.maximumReps
      repetitions = (0..<target.setCount).map { index in
        guard previous.indices.contains(index) else { return minimum }
        return rangeChanged ? min(maximum, max(minimum, previous[index])) : previous[index]
      }
    } else {
      repetitions = nil
    }
    let durations: [Int]?
    if target.tracking == .duration, definition.tracking == .duration,
      definition.durationSeconds == target.durationSeconds, let previous = durationsMS,
      let last = previous.last
    {
      durations =
        Array(previous.prefix(target.setCount))
        + Array(repeating: last, count: max(0, target.setCount - previous.count))
    } else {
      durations = nil
    }
    return try Self(
      definition: target, load: load, repetitions: repetitions, durationsMS: durations
    )
    .validated()
  }
  // Preserve ordered targets; additional sets repeat the last known target.
  func resized(to target: TrainingExercise) -> Self {
    var definition = definition
    definition.setCount = target.setCount
    let reps = repetitions.map {
      Array($0.prefix(target.setCount))
        + Array(
          repeating: $0.last ?? target.minimumReps ?? 1,
          count: max(0, target.setCount - $0.count))
    }
    let durations = durationsMS.flatMap { values -> [Int]? in
      guard let last = values.last else { return nil }
      return Array(values.prefix(target.setCount))
        + Array(repeating: last, count: max(0, target.setCount - values.count))
    }
    return Self(definition: definition, load: load, repetitions: reps, durationsMS: durations)
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
      guard durationsMS == nil, let repetitions, repetitions.count == definition.setCount,
        repetitions.allSatisfy({ $0 > 0 })
      else { throw TrainingError.invalid("Enter a valid target for each set.") }
    case .duration:
      guard repetitions == nil,
        durationsMS.map({ values in
          values.count == definition.setCount && values.allSatisfy { $0 > 0 && $0 % 100 == 0 }
        }) ?? true
      else {
        throw TrainingError.invalid("This exercise tracks duration.")
      }
    }
    return self
  }
  public func durationTargetMS(forSet number: Int) -> Int? {
    guard definition.tracking == .duration, (1...definition.setCount).contains(number) else {
      return nil
    }
    if let durationsMS, durationsMS.indices.contains(number - 1) { return durationsMS[number - 1] }
    guard let seconds = definition.durationSeconds else { return nil }
    let (value, overflow) = seconds.multipliedReportingOverflow(by: 1000)
    return overflow ? nil : value
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
  public var scheduleID: String? = nil
}
public enum GoalEngine {
  public static func lastSessionGoal(
    target: TrainingExercise, previous: WorkoutExercise, loads: [AvailableLoad]
  ) -> ExerciseGoal? {
    guard previous.definition.id == target.id, previous.definition.tracking == target.tracking,
      (1...1000).contains(target.setCount), !previous.sets.isEmpty,
      previous.sets.count == previous.definition.setCount, previous.feelingTenths != nil,
      previous.sets.enumerated().allSatisfy({
        $0.element.number == $0.offset + 1 && $0.element.weightGrams >= 0
      }),
      let grams = previous.sets.map(\.weightGrams).max()
    else { return nil }
    let selected = previous.sets.filter { $0.weightGrams == grams }
    guard let first = selected.first else { return nil }
    // Average at one real load only; a lighter set cannot raise the heavier-load target.
    let load: AvailableLoad
    if let components = first.components {
      guard selected.allSatisfy({ $0.components == components }) else { return nil }
      load = AvailableLoad(grams: grams, components: components)
    } else {
      guard let available = loads.first(where: { $0.grams == grams }) else { return nil }
      load = available
    }
    var sourceDefinition = target
    sourceDefinition.setCount = selected.count
    let source: ExerciseGoal
    if target.tracking == .repetitions {
      guard previous.sets.allSatisfy({ ($0.repetitions ?? 0) > 0 && $0.durationMS == nil }) else {
        return nil
      }
      source = ExerciseGoal(
        definition: sourceDefinition, load: load,
        repetitions: selected.compactMap(\.repetitions))
    } else {
      guard previous.sets.allSatisfy({ $0.repetitions == nil && ($0.durationMS ?? 0) > 0 }) else {
        return nil
      }
      source = ExerciseGoal(
        definition: sourceDefinition, load: load, repetitions: nil,
        durationsMS: selected.compactMap(\.durationMS))
    }
    guard let goal = source.averaged(to: target) else { return nil }
    return try? goal.validated()
  }
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
    let goal = ExerciseGoal(
      definition: target, load: load, repetitions: reps,
      durationsMS: target.tracking == .duration ? previous.sets.compactMap(\.durationMS) : nil)
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
    if let previous, previous.definition.setCount != target.setCount,
      let goal = lastSessionGoal(target: target, previous: previous, loads: loads)
    {
      return GoalSuggestion(goal: goal, reason: .keep, source: previous)
    }
    let assessment = Progression.assess(target: target, previous: previous, loads: loads)
    if assessment.status == .decrease, let load = assessment.nextLoad, let previous,
      var goal = matchingGoal(target: target, previous: previous, loads: loads, proposedLoad: load)
    {
      goal.load = load
      return GoalSuggestion(goal: goal, reason: .decreaseLoad, source: previous)
    }
    if target.tracking == .duration {
      if let previous, let goal = lastSessionGoal(target: target, previous: previous, loads: loads)
      {
        return GoalSuggestion(goal: goal, reason: .duration, source: previous)
      }
      return result(.bodyweight, nil, .duration)
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

public struct ExerciseLoadGoalDecision: Equatable, Sendable {
  public let workoutID: String
  public let exerciseID: String
  public let feelingTenths: Int
  public let original: ExerciseGoal?
  public let suggestion: GoalSuggestion
}
