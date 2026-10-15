import Foundation

public enum SessionTrendMetric: String, Hashable, Sendable {
  case volume, repetitions, duration, load
}
public struct SessionTrendContext: Hashable, Sendable {
  public let seriesCount: Int
  public let configuredSetCount: Int
  public let minimumReps: Int?
  public let maximumReps: Int?
  public let durationSeconds: Int?
  public let restSeconds: Int?
}
public struct SessionTrendPoint: Identifiable, Sendable {
  public var id: String { performance.workoutID }
  public var workoutID: String { performance.workoutID }
  public let performance: ExercisePerformance
  public let date: Date
  public let total: Int
  public let context: SessionTrendContext
  public let cumulativeTotal: Int?
  init(
    performance: ExercisePerformance, date: Date, total: Int, context: SessionTrendContext,
    cumulativeTotal: Int? = nil
  ) {
    self.performance = performance
    self.date = date
    self.total = total
    self.context = context
    self.cumulativeTotal = cumulativeTotal
  }
  public func value(for metric: SessionTrendMetric) -> Double {
    metric == .repetitions ? Double(total) : Double(total) / 1000
  }
}
public enum SessionTrends {
  private static func eligible(
    _ record: ExercisePerformance, tracking: TrackingMode, since: Date, calendar: Calendar
  ) -> Date? {
    let ex = record.exercise
    guard record.status == .completed, ex.definition.tracking == tracking,
      !ex.sets.isEmpty, let date = TrainingAnalytics.date(for: record.dayKey, calendar: calendar),
      date >= since,
      ex.sets.enumerated().allSatisfy({ index, set in
        set.number == index + 1 && set.weightGrams >= 0
          && (tracking == .repetitions
            ? (set.repetitions ?? 0) > 0 && set.durationMS == nil
            : (set.durationMS ?? 0) > 0 && set.repetitions == nil)
      })
    else { return nil }
    return date
  }
  public static func weights(
    records: [ExercisePerformance], tracking: TrackingMode, since: Date,
    calendar: Calendar = .current
  ) -> [Int] {
    Set(
      records.compactMap { record -> Int? in
        guard eligible(record, tracking: tracking, since: since, calendar: calendar) != nil,
          let weight = record.exercise.sets.first?.weightGrams,
          record.exercise.sets.allSatisfy({ $0.weightGrams == weight })
        else { return nil }
        return weight
      }
    ).sorted()
  }
  public static func selectedWeight(
    records: [ExercisePerformance], tracking: TrackingMode, since: Date, requested: Int?,
    calendar: Calendar = .current
  ) -> Int? {
    let choices = weights(records: records, tracking: tracking, since: since, calendar: calendar)
    if let requested, choices.contains(requested) { return requested }
    return records.first { record in
      eligible(record, tracking: tracking, since: since, calendar: calendar) != nil
        && record.exercise.sets.first.map { first in
          record.exercise.sets.allSatisfy { $0.weightGrams == first.weightGrams }
        } == true
    }?.exercise.sets.first?.weightGrams
  }
  public static func total(points: [SessionTrendPoint]) throws -> Int {
    try points.reduce(0) { sum, point in
      let (next, overflow) = sum.addingReportingOverflow(point.total)
      guard !overflow else {
        throw TrainingError.invalid("The total is too large to calculate exactly.")
      }
      return next
    }
  }
  public static func totalsByContext(points: [SessionTrendPoint]) throws -> [SessionTrendContext:
    Int]
  {
    try Dictionary(grouping: points, by: \.context).mapValues { try total(points: $0) }
  }
  public static func cumulativeVolume(
    records: [ExercisePerformance], since: Date, calendar: Calendar = .current
  ) throws -> [SessionTrendPoint] {
    let sessions = points(
      records: records, metric: .volume, tracking: .repetitions, weight: nil, since: since,
      calendar: calendar)
    let eligibleCount = records.filter {
      eligible($0, tracking: .repetitions, since: since, calendar: calendar) != nil
    }.count
    guard sessions.count == eligibleCount else {
      throw TrainingError.invalid("The volume is too large to calculate exactly.")
    }
    var cumulative = 0
    return try sessions.map { point in
      let (next, overflow) = cumulative.addingReportingOverflow(point.total)
      guard !overflow else {
        throw TrainingError.invalid("The total volume is too large to calculate exactly.")
      }
      cumulative = next
      return SessionTrendPoint(
        performance: point.performance, date: point.date, total: point.total,
        context: point.context, cumulativeTotal: cumulative)
    }
  }
  public static func points(
    records: [ExercisePerformance], metric: SessionTrendMetric, tracking: TrackingMode,
    weight: Int?, since: Date, calendar: Calendar = .current
  ) -> [SessionTrendPoint] {
    guard
      metric == .load
        || (tracking == .repetitions
          ? metric == .volume || metric == .repetitions : metric == .duration)
    else { return [] }
    return records.enumerated().compactMap { order, record -> (Int, SessionTrendPoint)? in
      guard let date = eligible(record, tracking: tracking, since: since, calendar: calendar) else {
        return nil
      }
      let ex = record.exercise
      var total = 0
      if metric == .load {
        total = ex.sets.map(\.weightGrams).max() ?? 0
      } else {
        if metric == .repetitions || metric == .duration, let weight {
          guard ex.sets.allSatisfy({ $0.weightGrams == weight }) else { return nil }
        }
        for set in ex.sets {
          let value: Int
          if metric == .volume {
            guard let repetitions = set.repetitions else { return nil }
            let (product, overflow) = repetitions.multipliedReportingOverflow(by: set.weightGrams)
            guard !overflow else { return nil }
            value = product
          } else {
            guard let recorded = metric == .repetitions ? set.repetitions : set.durationMS else {
              return nil
            }
            value = recorded
          }
          let (next, overflow) = total.addingReportingOverflow(value)
          guard !overflow else { return nil }
          total = next
        }
      }
      let d = ex.definition
      return (
        order,
        SessionTrendPoint(
          performance: record, date: date, total: total,
          context: SessionTrendContext(
            seriesCount: ex.sets.count, configuredSetCount: d.setCount, minimumReps: d.minimumReps,
            maximumReps: d.maximumReps, durationSeconds: d.durationSeconds,
            restSeconds: record.restSeconds))
      )
    }.sorted { $0.1.date == $1.1.date ? $0.0 > $1.0 : $0.1.date < $1.1.date }.map(\.1)
  }
}
