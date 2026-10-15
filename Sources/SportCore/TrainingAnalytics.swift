import Foundation

public enum AttendanceState: Sendable { case neutral, partial, completed }
public struct AttendanceDay: Identifiable, Sendable {
  public var id: String { key }
  public let key: String
  public let date: Date
  public let state: AttendanceState
  public let workouts: [WorkoutSummary]
}
public struct TrendSample: Identifiable, Sendable {
  public let id: String
  public let workoutID: String
  public let date: Date
  public let dayKey: String
  public let number: Int
  public let grams: Int
  public let repetitions: Int?
  public let durationMS: Int?
}
public enum TrainingAnalytics {
  public static func date(for key: String, calendar: Calendar = .current) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, parts[0] >= 1 else { return nil }
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    guard
      let midday = local.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    else { return nil }
    let check = local.dateComponents([.year, .month, .day], from: midday)
    guard check.year == parts[0], check.month == parts[1], check.day == parts[2] else { return nil }
    return local.startOfDay(for: midday)
  }
  public static func summaries(in overview: WorkoutOverview) -> [WorkoutSummary] {
    guard let active = overview.active else { return overview.history }
    return overview.history + [
      WorkoutSummary(
        id: active.id, scheduleID: active.scheduleID, name: active.name, dayKey: active.dayKey,
        startedAt: active.startedAt, endedAt: active.endedAt, status: active.status,
        setCount: active.exercises.flatMap(\.sets).count)
    ]
  }
  public static func attendance(
    history: [WorkoutSummary], ending: Date, weeks: Int = 13, calendar: Calendar = .current
  ) -> [AttendanceDay] {
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    let end = local.startOfDay(for: ending)
    let offset = TrainingSnapshot.isoWeekday(on: end, calendar: local) - 1
    guard let monday = local.date(byAdding: .day, value: -offset, to: end),
      let start = local.date(byAdding: .day, value: -(min(53, max(1, weeks)) - 1) * 7, to: monday)
    else { return [] }
    let grouped = Dictionary(grouping: history, by: \.dayKey)
    var result: [AttendanceDay] = []
    var day = start
    while day <= end {
      let key = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000), calendar: local)
      let entries = grouped[key] ?? []
      let state: AttendanceState =
        entries.contains { $0.status == .completed }
        ? .completed : entries.contains { $0.setCount > 0 } ? .partial : .neutral
      result.append(AttendanceDay(key: key, date: day, state: state, workouts: entries))
      guard let next = local.date(byAdding: .day, value: 1, to: day), next > day else { break }
      day = next
    }
    return result
  }
  public static func chartWeights(records: [ExercisePerformance], tracking: TrackingMode) -> [Int] {
    Set(
      records.filter { $0.status == .completed && $0.exercise.definition.tracking == tracking }
        .flatMap {
          $0.exercise.sets.map(\.weightGrams)
        }
    ).sorted()
  }
  public static func chartWeight(
    records: [ExercisePerformance], tracking: TrackingMode, selected: Int?
  ) -> Int? {
    let choices = chartWeights(records: records, tracking: tracking)
    if let selected, choices.contains(selected) { return selected }
    return records.first {
      $0.status == .completed && $0.exercise.definition.tracking == tracking
        && !$0.exercise.sets.isEmpty
    }?.exercise.sets.first?.weightGrams ?? choices.first
  }
  public static func samples(
    records: [ExercisePerformance], tracking: TrackingMode, weight: Int? = nil, since: Date,
    calendar: Calendar = .current
  ) -> [TrendSample] {
    records.filter { $0.status == .completed && $0.exercise.definition.tracking == tracking }
      .flatMap { record -> [TrendSample] in
        guard let date = date(for: record.dayKey, calendar: calendar), date >= since else {
          return []
        }
        return record.exercise.sets.compactMap { set in
          guard set.weightGrams >= 0, weight.map({ $0 == set.weightGrams }) ?? true,
            tracking == .repetitions
              ? (set.repetitions ?? 0) > 0 && set.durationMS == nil
              : (set.durationMS ?? 0) > 0 && set.repetitions == nil
          else { return nil }
          return TrendSample(
            id: set.id, workoutID: record.workoutID, date: date, dayKey: record.dayKey,
            number: set.number, grams: set.weightGrams, repetitions: set.repetitions,
            durationMS: set.durationMS)
        }
      }.sorted {
        $0.date == $1.date
          ? ($0.workoutID == $1.workoutID ? $0.number < $1.number : $0.workoutID < $1.workoutID)
          : $0.date < $1.date
      }
  }
}
extension WorkoutSession {
  public var totalElapsedMS: Int? {
    guard scheduleID != "manual", status != .active, let endedAt else { return nil }
    let (elapsed, overflow) = endedAt.subtractingReportingOverflow(startedAt)
    return !overflow && elapsed >= 0 ? elapsed : nil
  }
}
