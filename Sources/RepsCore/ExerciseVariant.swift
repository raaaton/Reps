import Foundation

public enum VariantMeasure {
  public static func parse(_ input: String) throws -> String? {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    if value.isEmpty { return nil }
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard value.utf8.count <= 64, (1...2).contains(parts.count),
      parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
    else { throw TrainingError.invalid("Enter a decimal measurement using a comma or point.") }
    let whole = String(parts[0].drop(while: { $0 == "0" }))
    let fraction =
      parts.count == 2 ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
    return (whole.isEmpty ? "0" : whole) + (fraction.isEmpty ? "" : "." + fraction)
  }
}

public struct ExerciseVariant: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var exerciseID: String
  public var name: String
  public var measure: String?
  public var unit: String?
  public var tracking: TrackingMode
  public var minimumReps: Int?
  public var maximumReps: Int?
  public var durationSeconds: Int?
  public var isArchived: Bool

  public static func baseID(for exerciseID: String) -> String { exerciseID + ":base" }
  public var isBase: Bool { id == Self.baseID(for: exerciseID) }
  public var displayName: String {
    guard let measure, let unit else { return name }
    return "\(name) — \(measure) \(unit)"
  }
  public static func base(for exercise: TrainingExercise) -> Self {
    Self(
      id: baseID(for: exercise.id), exerciseID: exercise.id, name: exercise.name,
      tracking: exercise.tracking, minimumReps: exercise.minimumReps,
      maximumReps: exercise.maximumReps, durationSeconds: exercise.durationSeconds,
      isArchived: false)
  }
  public func validated() throws -> Self {
    var result = self
    result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    try TrainingText.validate(name: result.name, id: id)
    guard TrainingText.isValid(exerciseID, limit: 256) else { throw TrainingError.storage }
    result.measure = try VariantMeasure.parse(measure ?? "")
    if result.measure != nil {
      let unit = (unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard TrainingText.isValid(unit, limit: 128) else {
        throw TrainingError.invalid("Enter a unit for the measurement.")
      }
      result.unit = unit
    } else {
      result.unit = nil
    }
    let definition = try applying(
      to: TrainingExercise(
        id: exerciseID, name: name,
        tracking: tracking, setCount: 1, minimumReps: minimumReps, maximumReps: maximumReps,
        durationSeconds: durationSeconds, isEnabled: true)
    ).validated()
    result.minimumReps = definition.minimumReps
    result.maximumReps = definition.maximumReps
    result.durationSeconds = definition.durationSeconds
    return result
  }
  public func applying(to exercise: TrainingExercise) -> TrainingExercise {
    var result = exercise
    result.tracking = tracking
    result.minimumReps = minimumReps
    result.maximumReps = maximumReps
    result.durationSeconds = durationSeconds
    // Unchanged base definitions remain compatible with older snapshots and goals.
    result.variant =
      isBase && exercise.id == exerciseID && name == exercise.name && measure == nil ? nil : self
    return result
  }
}

extension TrainingExercise {
  public var parentExerciseID: String { variant?.exerciseID ?? id }
  public var variantID: String { variant?.id ?? ExerciseVariant.baseID(for: id) }
  public var variantDisplayName: String { variant?.displayName ?? name }
  public var displayName: String {
    guard let variant else { return name }
    return variant.name == name ? variant.displayName : "\(name) · \(variant.displayName)"
  }
}

public struct VariantGoal: Codable, Equatable, Sendable {
  public var variantID: String
  public var scheduleID: String
  public var goal: ExerciseGoal
}
public struct ExerciseIdentityAlias: Codable, Equatable, Sendable {
  public var sourceID: String
  public var exerciseID: String
  public var variantID: String
}
