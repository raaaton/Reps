public enum ProgressionStatus: Sendable, Equatable {
  case insufficient, maintain, achieved, increase, noHeavierLoad, decrease, noLighterLoad
}
public struct ProgressionAssessment: Sendable, Equatable {
  public let status: ProgressionStatus
  public let referenceGrams: Int?
  public let nextLoad: AvailableLoad?
}
public enum Progression {
  public static func assess(
    target: TrainingExercise, previous: WorkoutExercise?, loads: [AvailableLoad],
    feelingTenths: Int? = nil
  ) -> ProgressionAssessment {
    let missing = ProgressionAssessment(status: .insufficient, referenceGrams: nil, nextLoad: nil)
    guard let previous, previous.definition.id == target.id,
      previous.definition.tracking == target.tracking, target.setCount > 0,
      previous.sets.count == target.setCount,
      previous.sets.enumerated().allSatisfy({
        $0.element.number == $0.offset + 1 && $0.element.weightGrams >= 0
      })
    else { return missing }
    let reference = previous.sets.map(\.weightGrams).max() ?? 0
    func result(_ status: ProgressionStatus, _ next: AvailableLoad? = nil) -> ProgressionAssessment
    {
      ProgressionAssessment(status: status, referenceGrams: reference, nextLoad: next)
    }
    let effort = feelingTenths ?? previous.feelingTenths
    let validSets = previous.sets.allSatisfy {
      target.tracking == .duration
        ? $0.repetitions == nil && ($0.durationMS ?? 0) > 0
        : $0.durationMS == nil && ($0.repetitions ?? 0) > 0
    }
    if let effort, (91...100).contains(effort), validSets,
      Set(previous.sets.map(\.weightGrams)).count == 1
    {
      guard
        let lower = loads.filter({ $0.grams >= 0 && $0.grams < reference }).max(by: {
          $0.grams < $1.grams
        })
      else { return result(.noLighterLoad) }
      return result(.decrease, lower)
    }
    switch target.tracking {
    case .duration:
      guard let seconds = target.durationSeconds, seconds > 0,
        seconds <= Int.max / 1000,
        previous.sets.allSatisfy({ $0.repetitions == nil && ($0.durationMS ?? 0) > 0 })
      else { return missing }
      return result(
        previous.sets.allSatisfy { ($0.durationMS ?? 0) >= seconds * 1000 } ? .achieved : .maintain)
    case .repetitions:
      guard let maximum = target.maximumReps, let minimum = target.minimumReps,
        minimum > 0, maximum >= minimum,
        let feeling = feelingTenths ?? previous.feelingTenths, (0...100).contains(feeling),
        previous.sets.allSatisfy({ $0.durationMS == nil && ($0.repetitions ?? 0) > 0 })
      else { return missing }
      let easyBodyweight = reference == 0 && feeling < 80
      guard easyBodyweight || previous.sets.allSatisfy({ ($0.repetitions ?? 0) >= maximum }) else {
        return result(.maintain)
      }
      guard feeling < 80 else { return result(.achieved) }
      guard let next = loads.filter({ $0.grams > reference }).min(by: { $0.grams < $1.grams })
      else { return result(.noHeavierLoad) }
      return result(.increase, next)
    }
  }
}
