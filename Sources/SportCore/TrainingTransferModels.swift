import Foundation

public struct TrainingDataSet: Codable, Equatable, Sendable {
  public var configuration: TrainingSnapshot
  public var notifications: NotificationPreferences
  public var workouts: [WorkoutSession]
  public var bodyWeights: [BodyWeightMeasurement] = []
  public var skillSessions: [SkillPractice] = []

  public init(
    configuration: TrainingSnapshot, notifications: NotificationPreferences,
    workouts: [WorkoutSession], bodyWeights: [BodyWeightMeasurement] = [],
    skillSessions: [SkillPractice] = []
  ) {
    self.configuration = configuration
    self.notifications = notifications
    self.workouts = workouts
    self.bodyWeights = bodyWeights
    self.skillSessions = skillSessions
  }
  enum CodingKeys: String, CodingKey {
    case configuration, notifications, workouts, bodyWeights, skillSessions
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    configuration = try c.decode(TrainingSnapshot.self, forKey: .configuration)
    notifications = try c.decode(NotificationPreferences.self, forKey: .notifications)
    workouts = try c.decode([WorkoutSession].self, forKey: .workouts)
    skillSessions = try c.decodeIfPresent([SkillPractice].self, forKey: .skillSessions) ?? []
    bodyWeights = try c.decodeIfPresent([BodyWeightMeasurement].self, forKey: .bodyWeights) ?? []
  }
}
public struct TrainingArchive: Codable, Equatable, Sendable {
  public var format = "sport.training"
  public var version = 6
  public var includesPrivatePhotos = false
  public var createdAt: Int
  public var contents: TrainingDataSet
  // Import provenance is internal, never a user-controlled archive field.
  var preservesBodyWeight = false
  enum CodingKeys: String, CodingKey {
    case format, version, includesPrivatePhotos, createdAt, contents
  }
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
      var value = try JSONDecoder().decode(Self.self, from: data)
      let originalVersion = value.version
      if value.version == 1 {
        // Legacy files are untrusted: dictionary construction must never trap on duplicates.
        try TrainingTransfer.unique(value.contents.configuration.exercises.map(\.id))
        try TrainingTransfer.unique(value.contents.configuration.goals.map { $0.definition.id })
        for schedule in value.contents.configuration.schedules {
          try TrainingTransfer.unique(schedule.exerciseIDs)
        }
        for index in value.contents.configuration.schedules.indices {
          let configuration = value.contents.configuration
          let schedule = configuration.schedules[index]
          value.contents.configuration.schedules[index].setCounts = Dictionary(
            uniqueKeysWithValues:
              schedule.exerciseIDs.compactMap { id in
                configuration.exercises.first(where: { $0.id == id }).map { (id, $0.setCount) }
              })
          value.contents.configuration.schedules[index].goals = Dictionary(
            uniqueKeysWithValues:
              configuration.goals.filter { schedule.exerciseIDs.contains($0.definition.id) }.map {
                ($0.definition.id, $0)
              })
        }
        value.version = 2
      }
      if originalVersion == 1 || originalVersion == 2 {
        value.preservesBodyWeight = true
        value.contents.bodyWeights = []
        value.contents.notifications.weightEnabled = false
        value.contents.notifications.weightWeekday = nil
        value.contents.notifications.weightMinutes = nil
        value.version = 3
      }
      if value.version == 3 { value.version = 4 }
      if value.version == 4 { value.version = 5 }
      if value.version == 5 { value.version = 6 }
      try value.validate()
      return value
    } catch let error as TrainingError { throw error } catch { throw TrainingTransfer.invalid }
  }
  func validate() throws {
    guard format == "sport.training", version == 6, !includesPrivatePhotos else {
      throw TrainingError.invalid(
        "This is not a compatible Sport training backup. Private photos are not supported."
      )
    }
    try WorkoutClock.validate(createdAt)
    try TrainingTransfer.validate(contents)
    try SkillTransfer.validate(contents, now: createdAt)
    for measurement in contents.bodyWeights { _ = try measurement.validated(now: createdAt) }
  }
}
public struct TrainingImportPreview: Identifiable, Sendable {
  public let id = UUID()
  public let isRestoration: Bool
  public var preservesBodyWeight = false
  public let identicalCount: Int
  public let incoming: TrainingDataSet
  let expected: TrainingDataSet
  public var workoutCount: Int { incoming.workouts.count }
  public var replacedCount: Int { expected.workouts.count }
  public var isUnchanged: Bool {
    if isRestoration { return incoming == expected }
    return incoming.bodyWeights == expected.bodyWeights
      && incoming.skillSessions == expected.skillSessions
      && incoming.configuration == expected.configuration
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
