import Foundation

public enum ChartPeriod: Int, CaseIterable, Identifiable, Hashable, Codable, Sendable {
  case threeMonths = 3
  case sixMonths = 6
  case year = 12

  public var id: Int { rawValue }
  public var label: String {
    switch self {
    case .threeMonths: "3 Months"
    case .sixMonths: "6 Months"
    case .year: "1 Year"
    }
  }
  public var caption: String {
    switch self {
    case .threeMonths: "Past 3 Months"
    case .sixMonths: "Past 6 Months"
    case .year: "Past Year"
    }
  }
  public func startDate(ending: Date, calendar: Calendar = .current) -> Date {
    var local = Calendar(identifier: .gregorian)
    local.timeZone = calendar.timeZone
    let day = local.startOfDay(for: ending)
    return local.startOfDay(for: local.date(byAdding: .month, value: -rawValue, to: day) ?? day)
  }
}
