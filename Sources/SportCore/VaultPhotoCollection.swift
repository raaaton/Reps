import Foundation

public enum VaultPhotoPose: String, Codable, CaseIterable, Sendable {
  case frontRelaxed, frontFlexed, back
}

public struct VaultPhotoMetadata: Codable, Sendable, Equatable {
  public var dayKey: String
  public let type: String
  public var pose: VaultPhotoPose?
  public init(dayKey: String, type: String, pose: VaultPhotoPose? = nil) {
    self.dayKey = dayKey
    self.type = type
    self.pose = pose
  }
}

public struct VaultPhotoEntry: Identifiable, Sendable, Equatable {
  public let id: String
  public let metadata: VaultPhotoMetadata
  public init(id: String, metadata: VaultPhotoMetadata) {
    self.id = id
    self.metadata = metadata
  }
}

public struct VaultPhotoDay: Identifiable, Sendable {
  public let id: String
  public let photos: [VaultPhotoEntry]
}

public enum VaultPhotoCollection {
  public static func days(_ photos: [VaultPhotoEntry]) -> [VaultPhotoDay] {
    Dictionary(grouping: photos, by: { $0.metadata.dayKey }).map { day, photos in
      VaultPhotoDay(
        id: day,
        photos: photos.sorted {
          let left = $0.metadata.pose.flatMap { VaultPhotoPose.allCases.firstIndex(of: $0) } ?? 3
          let right = $1.metadata.pose.flatMap { VaultPhotoPose.allCases.firstIndex(of: $0) } ?? 3
          return left == right ? $0.id < $1.id : left < right
        })
    }.sorted { $0.id > $1.id }
  }
  public static func candidates(_ photos: [VaultPhotoEntry], pose: VaultPhotoPose)
    -> [VaultPhotoEntry]
  {
    photos.filter { $0.metadata.pose == pose }.sorted {
      $0.metadata.dayKey == $1.metadata.dayKey
        ? $0.id < $1.id : $0.metadata.dayKey < $1.metadata.dayKey
    }
  }
  public static func canCompare(_ first: VaultPhotoEntry, _ second: VaultPhotoEntry) -> Bool {
    first.id != second.id && first.metadata.dayKey != second.metadata.dayKey
      && first.metadata.pose != nil && first.metadata.pose == second.metadata.pose
  }
}
