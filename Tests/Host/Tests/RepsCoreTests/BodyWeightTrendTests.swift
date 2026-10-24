import Foundation
import XCTest

@testable import RepsCore

final class BodyWeightTrendTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
  }
  private func date(_ key: String) -> Date {
    TrainingAnalytics.date(for: key, calendar: calendar)!
  }
  private func measurement(_ key: String, _ grams: Int) -> BodyWeightMeasurement {
    BodyWeightMeasurement(id: key, dayKey: key, grams: grams)
  }
  func testPeriodsUseCalendarMonthsWithMonthEndAndLeapYearClamping() {
    XCTAssertEqual(ChartPeriod.allCases.map(\.rawValue), [3, 6, 12])
    XCTAssertEqual(
      ChartPeriod.threeMonths.startDate(ending: date("2026-05-31"), calendar: calendar),
      date("2026-02-28"))
    XCTAssertEqual(
      ChartPeriod.sixMonths.startDate(ending: date("2024-08-31"), calendar: calendar),
      date("2024-02-29"))
    XCTAssertEqual(
      ChartPeriod.year.startDate(ending: date("2024-02-29"), calendar: calendar),
      date("2023-02-28"))
  }
  func testStartUsesGregorianMonthsAndRequestedTimeZoneAtStartOfDay() {
    var nonGregorian = Calendar(identifier: .buddhist)
    nonGregorian.timeZone = calendar.timeZone
    let midday = date("2026-10-25").addingTimeInterval(12 * 3600)
    XCTAssertEqual(
      ChartPeriod.threeMonths.startDate(ending: midday, calendar: nonGregorian),
      date("2026-07-25"))
  }
  func testTrendFiltersBothBoundariesSortsDatesAndUsesIndividualWeights() {
    let values = [
      measurement("2026-10-19", 72_100), measurement("2026-07-18", 70_000),
      measurement("2026-10-20", 74_000), measurement("2026-07-19", 72_500),
      measurement("2026-08-01", 71_000), measurement("2026-02-30", 73_000),
    ]
    let points = BodyWeightTrend.points(
      measurements: values, period: .threeMonths, ending: date("2026-10-19"),
      calendar: calendar)
    XCTAssertEqual(points.map(\.measurement.dayKey), ["2026-07-19", "2026-08-01", "2026-10-19"])
    XCTAssertEqual(points.map(\.kilograms), [72.5, 71, 72.1])
    XCTAssertEqual(points[1].date, date("2026-08-01"))
    XCTAssertEqual(BodyWeightTrend.deltaGrams(points: points), -400)
  }
  func testEmptyAndSingleMeasurementDoNotInventChange() {
    XCTAssertNil(BodyWeightTrend.deltaGrams(points: []))
    let one = BodyWeightTrend.points(
      measurements: [measurement("2026-10-19", 72_100)], period: .threeMonths,
      ending: date("2026-10-19"), calendar: calendar)
    XCTAssertEqual(one.count, 1)
    XCTAssertNil(BodyWeightTrend.deltaGrams(points: one))
  }
  func testSixMonthFilterContainsMoreHistoryWithoutChangingDailyValues() {
    let values = [measurement("2026-05-01", 70_000), measurement("2026-10-01", 72_000)]
    let short = BodyWeightTrend.points(
      measurements: values, period: .threeMonths, ending: date("2026-10-19"), calendar: calendar)
    let long = BodyWeightTrend.points(
      measurements: values, period: .sixMonths, ending: date("2026-10-19"), calendar: calendar)
    XCTAssertEqual(short.map(\.measurement.grams), [72_000])
    XCTAssertEqual(long.map(\.measurement.grams), [70_000, 72_000])
    XCTAssertEqual(BodyWeightTrend.deltaGrams(points: long), 2000)
  }
}
