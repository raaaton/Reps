public enum RepetitionNotation {
  public struct Group: Equatable, Sendable {
    public let count: Int
    public let repetitions: Int
  }

  // Group adjacent equal sets only: the original performance order must stay intact.
  public static func groups(_ repetitions: [Int]) -> [Group] {
    var result: [Group] = []
    for value in repetitions {
      if let last = result.last, last.repetitions == value {
        result[result.count - 1] = Group(count: last.count + 1, repetitions: value)
      } else {
        result.append(Group(count: 1, repetitions: value))
      }
    }
    return result
  }

  public static func compact(_ repetitions: [Int]) -> String {
    groups(repetitions).map { "\($0.count)×\($0.repetitions)" }.joined(separator: " ")
  }
}
