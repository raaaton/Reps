import Foundation

public enum PortableBackupFailure: Error, LocalizedError, Sendable {
  case invalid, password, interrupted, changed
  public var errorDescription: String? {
    switch self {
    case .invalid: "The backup is damaged, incomplete or unsupported. Nothing was imported."
    case .password: "The password is incorrect or the backup is damaged. Nothing was imported."
    case .interrupted: "The transfer was interrupted. Try again."
    case .changed: "The vault changed. Select the backup again before restoring."
    }
  }
}

public struct PortableBackupHeader: Sendable {
  public static let prefix = Data("REPSBK01".utf8)
  public static let size = 88
  public static let blockBytes = 1024 * 1024
  public static let maximumRecordBytes = 36 * 1024 * 1024
  public static let rounds: UInt32 = 600_000
  public let salt: Data
  public let wrappedKey: Data
  public init(salt: Data, wrappedKey: Data) throws {
    guard salt.count == 16, wrappedKey.count == 60 else { throw PortableBackupFailure.invalid }
    self.salt = salt
    self.wrappedKey = wrappedKey
  }
  public var authenticatedPrefix: Data {
    Self.prefix + Data([0, 9, 39, 192]) + salt
  }
  public var encoded: Data { authenticatedPrefix + wrappedKey }
  public init(data: Data) throws {
    let bytes = Data(data)
    guard bytes.count == Self.size, bytes.prefix(8) == Self.prefix,
      bytes.subdata(in: 8..<12) == Data([0, 9, 39, 192])
    else { throw PortableBackupFailure.invalid }
    salt = bytes.subdata(in: 12..<28)
    wrappedKey = bytes.subdata(in: 28..<88)
  }
}

public struct VaultBackupInventory: Codable, Equatable, Sendable {
  public let photos: Int
  public let movements: Int
  public let videos: Int
  public var isEmpty: Bool { photos == 0 && movements == 0 && videos == 0 }
}

public struct VaultBackupStamp: Equatable, Sendable {
  public let keyID: String
  public let revision: Int
  public init(keyID: String, revision: Int) {
    self.keyID = keyID
    self.revision = revision
  }
}

public struct VaultBackupRecord: Codable, Sendable {
  public enum Kind: String, Codable, Sendable { case photo, movement, video, chunk }
  public let kind: Kind
  public let id: String
  public var movementID: String?
  public var byteCount: Int?
  public var position: Int?
  public var dayKey: String?
  public var metadata: Data?
  public var original: Data?
  public var thumbnail: Data?
  public var payload: Data?
  public init(
    kind: Kind, id: String, movementID: String? = nil, byteCount: Int? = nil,
    position: Int? = nil, dayKey: String? = nil, metadata: Data? = nil,
    original: Data? = nil, thumbnail: Data? = nil, payload: Data? = nil
  ) {
    self.kind = kind
    self.id = id
    self.movementID = movementID
    self.byteCount = byteCount
    self.position = position
    self.dayKey = dayKey
    self.metadata = metadata
    self.original = original
    self.thumbnail = thumbnail
    self.payload = payload
  }
  public mutating func mapPayloads(_ transform: (Data, String, String) throws -> Data) throws {
    let role: String
    switch kind {
    case .photo: role = "metadata"
    case .movement: role = "movement-metadata"
    case .video: role = "video-metadata"
    case .chunk: role = "video-chunk/\(position ?? -1)"
    }
    if let metadata { self.metadata = try transform(metadata, id, role) }
    if let original { self.original = try transform(original, id, "original") }
    if let thumbnail {
      self.thumbnail = try transform(
        thumbnail, id, kind == .video ? "video-thumbnail" : "thumbnail")
    }
    if let payload { self.payload = try transform(payload, id, role) }
  }
}
