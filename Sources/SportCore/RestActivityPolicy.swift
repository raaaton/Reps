public struct RestActivityIdentity: Sendable {
  public let id: String
  public let restID: String
  public let isCompletion: Bool
  public let deadline: Int?
  public init(id: String, restID: String, isCompletion: Bool, deadline: Int?) {
    self.id = id
    self.restID = restID
    self.isCompletion = isCompletion
    self.deadline = deadline
  }
}
public enum RestActivityPolicy {
  public static func retiredIDs(records: [RestActivityIdentity], snapshot: RestActivitySnapshot?)
    -> [String]
  {
    var keptCountdown = false
    var keptCompletion = false
    return records.compactMap { record in
      guard let snapshot, record.restID == snapshot.restID else { return record.id }
      if record.isCompletion {
        guard !snapshot.isPaused, record.deadline == snapshot.deadline, !keptCompletion else {
          return record.id
        }
        keptCompletion = true
      } else {
        guard !keptCountdown else { return record.id }
        keptCountdown = true
      }
      return nil
    }
  }
}
