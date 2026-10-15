import Foundation

public enum VaultFailure: Error, LocalizedError, Sendable {
  case locked, damaged, invalidPhoto, tooLarge
  public var errorDescription: String? {
    switch self {
    case .locked: "Unlock the vault with Face ID to continue."
    case .damaged: "The vault or its key is inaccessible. No data or key has been replaced."
    case .invalidPhoto:
      "This photo cannot be imported. Choose a JPEG, HEIC or PNG image."
    case .tooLarge: "This photo is too large. Limit: 24 MB and 64 million pixels."
    }
  }
}

public final class VaultLease: @unchecked Sendable {
  public let id = UUID()
  public let keyID: String
  private let lock = NSLock()
  private var valid = true
  public init(keyID: String) { self.keyID = keyID }
  public func invalidate() {
    lock.lock()
    valid = false
    lock.unlock()
  }
  public func check() throws {
    lock.lock()
    let value = valid
    lock.unlock()
    if !value { throw VaultFailure.locked }
  }
}

public struct VaultEncryptedPhoto: Sendable {
  public let id: String
  public let metadata: Data
  public let original: Data
  public let thumbnail: Data
  public init(id: String, metadata: Data, original: Data, thumbnail: Data) {
    self.id = id
    self.metadata = metadata
    self.original = original
    self.thumbnail = thumbnail
  }
}

// Independent database: training transfers never read or replace encrypted vault rows.
public actor VaultRepository {
  private let db: SQLiteDatabase
  public init(path: String) throws {
    let database = try SQLiteDatabase(path: path)
    guard try database.query("PRAGMA secure_delete=ON").first?.integer("secure_delete") == 1
    else { throw VaultFailure.damaged }
    let version = try database.query("PRAGMA user_version").first!.integer("user_version")
    guard version == 0 || version == 1 else { throw VaultFailure.damaged }
    if version == 0 {
      try database.transaction {
        try database.execute(
          "CREATE TABLE vault_state (singleton INTEGER PRIMARY KEY CHECK(singleton=1), key_id TEXT NOT NULL, verification BLOB NOT NULL)"
        )
        try database.execute(
          "CREATE TABLE vault_photos (id TEXT PRIMARY KEY NOT NULL, metadata BLOB NOT NULL, original BLOB NOT NULL, thumbnail BLOB NOT NULL)"
        )
        try database.execute("PRAGMA user_version=1")
      }
    }
    db = database
  }
  public func state() throws -> (keyID: String, verification: Data)? {
    if let bounds = try db.query(
      "SELECT length(key_id) AS id_size,length(verification) AS n FROM vault_state WHERE singleton=1"
    ).first {
      guard try bounds.integer("id_size") == 36, (28...1024).contains(try bounds.integer("n"))
      else { throw VaultFailure.damaged }
    }
    if let row = try db.query("SELECT key_id,verification FROM vault_state WHERE singleton=1").first
    {
      let id = try row.text("key_id")
      let check = try row.blob("verification")
      guard UUID(uuidString: id) != nil, (28...1024).contains(check.count) else {
        throw VaultFailure.damaged
      }
      return (id, check)
    }
    guard try db.query("SELECT COUNT(*) AS n FROM vault_photos").first!.integer("n") == 0 else {
      throw VaultFailure.damaged
    }
    return nil
  }
  public func initialize(keyID: String, verification: Data) throws {
    guard UUID(uuidString: keyID) != nil, (28...1024).contains(verification.count) else {
      throw VaultFailure.damaged
    }
    try db.transaction {
      guard try state() == nil else { throw VaultFailure.damaged }
      try db.execute("INSERT INTO vault_state VALUES(1,?,?)", [.text(keyID), .blob(verification)])
    }
  }
  private func authorize(_ lease: VaultLease) throws {
    try lease.check()
    guard try state()?.keyID == lease.keyID else { throw VaultFailure.locked }
  }
  public func metadata(lease: VaultLease) throws -> [(id: String, data: Data)] {
    try authorize(lease)
    let bounds = try db.query(
      "SELECT length(id) AS id_size,length(metadata) AS n FROM vault_photos LIMIT 1001")
    guard bounds.count <= 1000 else { throw VaultFailure.damaged }
    for row in bounds {
      guard try row.integer("id_size") == 36, (28...16384).contains(try row.integer("n")) else {
        throw VaultFailure.damaged
      }
    }
    let rows = try db.query("SELECT id,metadata FROM vault_photos ORDER BY rowid DESC")
    try lease.check()
    return try rows.map { (try $0.text("id"), try $0.blob("metadata")) }
  }
  public func content(id: String, thumbnail: Bool, lease: VaultLease) throws -> Data {
    try authorize(lease)
    let column = thumbnail ? "thumbnail" : "original"
    guard
      let bounds = try db.query(
        "SELECT length(\(column)) AS n FROM vault_photos WHERE id=?", [.text(id)]
      ).first,
      (28...(thumbnail ? 1024 * 1024 : 24 * 1024 * 1024 + 28)).contains(try bounds.integer("n"))
    else { throw VaultFailure.damaged }
    guard let row = try db.query("SELECT \(column) FROM vault_photos WHERE id=?", [.text(id)]).first
    else { throw VaultFailure.damaged }
    try lease.check()
    return try row.blob(column)
  }
  public func insert(_ photo: VaultEncryptedPhoto, lease: VaultLease) throws {
    guard UUID(uuidString: photo.id) != nil, (28...16384).contains(photo.metadata.count),
      (28...(24 * 1024 * 1024 + 28)).contains(photo.original.count),
      (28...(1024 * 1024)).contains(photo.thumbnail.count)
    else { throw VaultFailure.tooLarge }
    try db.transaction {
      try authorize(lease)
      guard try db.query("SELECT COUNT(*) AS n FROM vault_photos").first!.integer("n") < 1000 else {
        throw VaultFailure.tooLarge
      }
      try db.execute(
        "INSERT INTO vault_photos VALUES(?,?,?,?)",
        [.text(photo.id), .blob(photo.metadata), .blob(photo.original), .blob(photo.thumbnail)])
      try lease.check()
    }
  }
  public func changeMetadata(id: String, encrypted: Data, lease: VaultLease) throws {
    guard (28...16384).contains(encrypted.count) else { throw VaultFailure.damaged }
    try db.transaction {
      try authorize(lease)
      guard try db.query("SELECT id FROM vault_photos WHERE id=?", [.text(id)]).count == 1 else {
        throw VaultFailure.damaged
      }
      try db.execute(
        "UPDATE vault_photos SET metadata=? WHERE id=?", [.blob(encrypted), .text(id)])
      try lease.check()
    }
  }
  public func delete(id: String?, lease: VaultLease) throws {
    try db.transaction {
      try authorize(lease)
      if let id {
        try db.execute("DELETE FROM vault_photos WHERE id=?", [.text(id)])
      } else {
        try db.execute("DELETE FROM vault_photos")
      }
      try lease.check()
    }
  }
  public func reset() throws {
    try db.transaction {
      try db.execute("DELETE FROM vault_photos")
      try db.execute("DELETE FROM vault_state")
    }
  }
  public func delete(ids: [String], lease: VaultLease) throws {
    guard ids.count <= 1000, ids.allSatisfy({ UUID(uuidString: $0) != nil }) else {
      throw VaultFailure.damaged
    }
    try db.transaction {
      try authorize(lease)
      for id in ids {
        try db.execute("DELETE FROM vault_photos WHERE id=?", [.text(id)])
      }
      try lease.check()
    }
  }
}
