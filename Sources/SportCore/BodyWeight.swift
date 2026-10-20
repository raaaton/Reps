import Foundation

public struct BodyWeightMeasurement: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let dayKey: String
  public let grams: Int

  public init(id: String, dayKey: String, grams: Int) {
    self.id = id
    self.dayKey = dayKey
    self.grams = grams
  }

  func validated(now: Int, calendar: Calendar = .current) throws -> Self {
    try WorkoutClock.validate(now)
    let bytes = Array(dayKey.utf8)
    guard TrainingText.isValid(id, limit: 256), grams > 0,
      bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
      bytes.enumerated().allSatisfy({
        $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element)
      }),
      TrainingAnalytics.date(for: dayKey, calendar: calendar) != nil,
      dayKey <= WorkoutClock.dayKey(now, calendar: calendar)
    else { throw TrainingError.invalid("Enter a positive weight and a valid date up to today.") }
    return self
  }
}

public enum BodyWeightInput {
  public static func grams(from text: String) throws -> Int {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(
      of: ",", with: ".")
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    func digits(_ part: Substring) -> Bool {
      !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) }
    }
    let invalid = TrainingError.invalid(
      "Enter a positive weight in kilograms, with up to three decimal places.")
    guard (1...2).contains(parts.count), digits(parts[0]),
      parts.count == 1 || (digits(parts[1]) && parts[1].count <= 3),
      let whole = Int(parts[0])
    else { throw invalid }
    let fraction =
      parts.count == 2 ? Int(parts[1] + String(repeating: "0", count: 3 - parts[1].count))! : 0
    let (base, overflow) = whole.multipliedReportingOverflow(by: 1000)
    let (grams, additionOverflow) = base.addingReportingOverflow(fraction)
    guard !overflow, !additionOverflow, grams > 0 else { throw invalid }
    return grams
  }
}
