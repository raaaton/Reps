import Foundation

public struct TrainingDataSet: Codable, Equatable, Sendable {
  public var configuration: TrainingSnapshot
  public var notifications: NotificationPreferences
  public var workouts: [WorkoutSession]
}
public struct TrainingArchive: Codable, Equatable, Sendable {
  public var format = "sport.training"
  public var version = 1
  public var includesPrivatePhotos = false
  public var createdAt: Int
  public var contents: TrainingDataSet
  public func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(self)
    guard data.count <= TrainingTransfer.maximumBytes else { throw TrainingTransfer.invalid }
    return data
  }
  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= TrainingTransfer.maximumBytes else { throw TrainingTransfer.invalid }
    do {
      try TrainingTransfer.checkJSONShape(data)
      let value = try JSONDecoder().decode(Self.self, from: data)
      try value.validate()
      return value
    } catch let error as TrainingError { throw error } catch { throw TrainingTransfer.invalid }
  }
  func validate() throws {
    guard format == "sport.training", version == 1, !includesPrivatePhotos else {
      throw TrainingError.invalid(
        "This is not a compatible Sport training backup. Private photos are not supported."
      )
    }
    try WorkoutClock.validate(createdAt)
    try TrainingTransfer.validate(contents)
  }
}
public struct TrainingImportPreview: Identifiable, Sendable {
  public let id = UUID()
  public let isRestoration: Bool
  public let identicalCount: Int
  public let incoming: TrainingDataSet
  let expected: TrainingDataSet
  public var workoutCount: Int { incoming.workouts.count }
  public var replacedCount: Int { expected.workouts.count }
  public var isUnchanged: Bool {
    if isRestoration { return incoming == expected }
    return incoming.configuration == expected.configuration
      && incoming.notifications == expected.notifications
      && incoming.workouts.sorted { $0.id < $1.id } == expected.workouts.sorted { $0.id < $1.id }
  }
  public var setCount: Int { incoming.workouts.flatMap(\.exercises).flatMap(\.sets).count }
}
public enum TrainingTransfer {
  public static let maximumBytes = 10 * 1024 * 1024
  static var invalid: TrainingError {
    .invalid(
      "Invalid or oversized file. Use a Sport CSV or compatible training backup (10 MB maximum)."
    )
  }
}
