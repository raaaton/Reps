import Foundation

public enum VaultVideoLimits {
  public static let chunkBytes = 1024 * 1024
  public static let maximumBytes = 500 * 1024 * 1024
  public static let maximumSeconds = 300.0
}

public enum VaultVideoFailure: Error, LocalizedError, Sendable {
  case invalid, tooLarge, storage, name
  public var errorDescription: String? {
    switch self {
    case .invalid: "This video cannot be imported. Choose a playable MOV or MP4 video."
    case .tooLarge: "Choose a video no longer than 5 minutes and no larger than 500 MiB."
    case .storage: "The video could not be saved. Check available iPhone storage and try again."
    case .name: "Enter a movement name between 1 and 100 characters."
    }
  }
}

public struct VaultMovementMetadata: Codable, Equatable, Sendable {
  public var name: String
  public let skillID: String?
  public init(name: String, skillID: String? = nil) {
    self.name = name
    self.skillID = skillID
  }
  public func validate() throws {
    guard TrainingText.isValid(name), skillID != nil || name.count <= 100,
      skillID.map({ TrainingText.isValid($0, limit: 256) }) ?? true
    else { throw VaultVideoFailure.name }
  }
}

public struct VaultMovementEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public var metadata: VaultMovementMetadata
  public init(id: String, metadata: VaultMovementMetadata) {
    self.id = id
    self.metadata = metadata
  }
}

public struct VaultVideoMetadata: Codable, Equatable, Sendable {
  public var dayKey: String
  public let movementID: String
  public let type: String
  public let duration: Double
  public let byteCount: Int
  public let importedAt: Int
  public init(
    dayKey: String, movementID: String, type: String, duration: Double, byteCount: Int,
    importedAt: Int
  ) {
    self.dayKey = dayKey
    self.movementID = movementID
    self.type = type
    self.duration = duration
    self.byteCount = byteCount
    self.importedAt = importedAt
  }
  public func validate() throws {
    guard UUID(uuidString: movementID) != nil, dayKey.utf8.count == 10,
      dayKey.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil,
      TrainingAnalytics.date(for: dayKey, calendar: Calendar(identifier: .gregorian)) != nil,
      ["com.apple.quicktime-movie", "public.mpeg-4"].contains(type), duration.isFinite,
      duration > 0, duration <= VaultVideoLimits.maximumSeconds,
      (1...VaultVideoLimits.maximumBytes).contains(byteCount), importedAt >= 0
    else { throw VaultVideoFailure.invalid }
  }
}

public struct VaultVideoEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public var metadata: VaultVideoMetadata
  public init(id: String, metadata: VaultVideoMetadata) {
    self.id = id
    self.metadata = metadata
  }
}

public struct VaultEncryptedVideo: Sendable {
  public let id: String
  public let movementID: String
  public let metadata: Data
  public let thumbnail: Data
  public let byteCount: Int
  public init(id: String, movementID: String, metadata: Data, thumbnail: Data, byteCount: Int) {
    self.id = id
    self.movementID = movementID
    self.metadata = metadata
    self.thumbnail = thumbnail
    self.byteCount = byteCount
  }
}

public enum VaultMovementCollection {
  public static func following(
    _ skills: [SkillDefinition], progress: [SkillProgress], movements: [VaultMovementEntry] = []
  ) -> [VaultMovementEntry] {
    skills.filter { skill in
      !skill.isArchived && progress.contains { $0.skillID == skill.id && !$0.completed(in: skill) }
    }.map { skill in
      let existing = movements.first { $0.metadata.skillID == skill.id }
      return VaultMovementEntry(
        id: existing?.id ?? UUID().uuidString,
        metadata: .init(name: skill.americanEnglish.name, skillID: skill.id))
    }
  }
  public static func saved(
    _ movements: [VaultMovementEntry], following: [VaultMovementEntry], videos: [VaultVideoEntry]
  ) -> [VaultMovementEntry] {
    let active = Set(following.map(\.id))
    let recorded = Set(videos.map(\.metadata.movementID))
    return movements.filter {
      !active.contains($0.id) && ($0.metadata.skillID == nil || recorded.contains($0.id))
    }
    .sorted {
      $0.metadata.name == $1.metadata.name ? $0.id < $1.id : $0.metadata.name < $1.metadata.name
    }
  }
  public static func videos(_ values: [VaultVideoEntry], movementID: String) -> [VaultVideoEntry] {
    values.filter { $0.metadata.movementID == movementID }.sorted {
      if $0.metadata.dayKey != $1.metadata.dayKey { return $0.metadata.dayKey > $1.metadata.dayKey }
      if $0.metadata.importedAt != $1.metadata.importedAt {
        return $0.metadata.importedAt > $1.metadata.importedAt
      }
      return $0.id < $1.id
    }
  }
}

public struct VaultVideoRange: Equatable, Sendable {
  public let lower: Int
  public let upper: Int
  public static func requested(offset: Int64, length: Int, total: Int, toEnd: Bool = false) throws
    -> Self
  {
    guard (1...VaultVideoLimits.maximumBytes).contains(total), offset >= 0, offset <= Int64(total),
      length >= 0
    else {
      throw VaultVideoFailure.invalid
    }
    let start = Int(offset)
    return Self(lower: start, upper: start + (toEnd ? total - start : min(length, total - start)))
  }
}

public struct VaultVideoAlignment: Equatable, Sendable {
  public let first: Double
  public let second: Double
  public init(first: Double, second: Double) {
    self.first = first
    self.second = second
  }
  public func remaining(firstDuration: Double, secondDuration: Double) -> Double {
    guard first.isFinite, second.isFinite, firstDuration.isFinite, secondDuration.isFinite else {
      return 0
    }
    return max(0, min(firstDuration - max(0, first), secondDuration - max(0, second)))
  }
}
