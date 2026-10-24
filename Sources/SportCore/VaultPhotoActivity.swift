import Foundation

// Public activity contains dates/counts only, never media, poses or photo identifiers.
public struct VaultPhotoActivity: Sendable, Equatable {
  public let countsByDay: [String: Int]
  public let needsUnlock: Bool
  public init(countsByDay: [String: Int] = [:], needsUnlock: Bool = false) {
    self.countsByDay = countsByDay
    self.needsUnlock = needsUnlock
  }
}

// Only constructed from metadata already authenticated/decrypted during normal unlock.
public struct VaultPhotoIndexEntry: Sendable {
  public let id: String
  public let dayKey: String
  public let encryptedMetadata: Data
  public init(id: String, dayKey: String, encryptedMetadata: Data) {
    self.id = id
    self.dayKey = dayKey
    self.encryptedMetadata = encryptedMetadata
  }
}
