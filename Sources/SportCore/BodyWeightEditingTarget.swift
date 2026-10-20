public struct BodyWeightEditingTarget: Equatable, Sendable {
  public let original: BodyWeightMeasurement?
  public let resetsInput: Bool

  public static func resolve(
    adding: Bool, current: BodyWeightMeasurement?, matching: BodyWeightMeasurement?
  ) -> Self {
    if let matching {
      // Preserve the draft and its original snapshot when revisiting the same record.
      // A later database change must still be detected by the save operation.
      return Self(
        original: current?.id == matching.id ? current : matching,
        resetsInput: current?.id != matching.id)
    }
    if adding { return Self(original: nil, resetsInput: current != nil) }
    return Self(original: current, resetsInput: false)
  }
}
