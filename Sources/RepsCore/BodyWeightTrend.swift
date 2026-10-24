import Foundation

public struct BodyWeightPoint: Identifiable, Equatable, Sendable {
  public let measurement: BodyWeightMeasurement
  public let date: Date
  public var id: String { measurement.id }
  public var kilograms: Double { Double(measurement.grams) / 1000 }
}

public enum BodyWeightTrend {
  public static func points(
    measurements: [BodyWeightMeasurement], period: ChartPeriod, ending: Date,
    calendar: Calendar = .current
  ) -> [BodyWeightPoint] {
    let since = period.startDate(ending: ending, calendar: calendar)
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    let lastDay = local.startOfDay(for: ending)
    return measurements.compactMap { measurement in
      guard measurement.grams > 0,
        let date = TrainingAnalytics.date(for: measurement.dayKey, calendar: local),
        date >= since, date <= lastDay
      else { return nil }
      return BodyWeightPoint(measurement: measurement, date: date)
    }.sorted { $0.date < $1.date }
  }
  public static func deltaGrams(points: [BodyWeightPoint]) -> Int? {
    guard points.count > 1, let first = points.first, let last = points.last else { return nil }
    return last.measurement.grams - first.measurement.grams
  }
}
