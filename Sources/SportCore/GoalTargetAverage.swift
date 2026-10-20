// Exact integer ceiling of a mean, optionally expressed in larger units (ms -> seconds).
// Quotients/remainders avoid overflowing the sum of large valid recorded values.
enum GoalTargetAverage {
  static func ceiling(_ values: [Int], unit: Int = 1) -> Int? {
    guard !values.isEmpty, values.count <= 1000, unit > 0,
      values.allSatisfy({ $0 > 0 })
    else { return nil }
    let (divisor, divisorOverflow) = values.count.multipliedReportingOverflow(by: unit)
    guard !divisorOverflow else { return nil }
    var whole = 0
    var remainder = 0
    for value in values {
      let (nextWhole, wholeOverflow) = whole.addingReportingOverflow(value / divisor)
      let (nextRemainder, remainderOverflow) = remainder.addingReportingOverflow(value % divisor)
      guard !wholeOverflow, !remainderOverflow else { return nil }
      whole = nextWhole
      remainder = nextRemainder
    }
    let extra = remainder / divisor + (remainder % divisor == 0 ? 0 : 1)
    let (result, overflow) = whole.addingReportingOverflow(extra)
    return overflow ? nil : result
  }
}

extension ExerciseGoal {
  // Learned future targets use one whole-number mean; manual per-set edits stay available.
  func averaged(to target: TrainingExercise) -> Self? {
    guard (1...1000).contains(target.setCount) else { return nil }
    if let repetitions {
      guard let mean = GoalTargetAverage.ceiling(repetitions) else { return nil }
      return Self(
        definition: target, load: load,
        repetitions: Array(repeating: mean, count: target.setCount))
    }
    if let durationsMS {
      guard let seconds = GoalTargetAverage.ceiling(durationsMS, unit: 1000) else { return nil }
      let (ms, overflow) = seconds.multipliedReportingOverflow(by: 1000)
      guard !overflow else { return nil }
      return Self(
        definition: target, load: load, repetitions: nil,
        durationsMS: Array(repeating: ms, count: target.setCount))
    }
    return Self(definition: target, load: load, repetitions: nil)
  }
}
