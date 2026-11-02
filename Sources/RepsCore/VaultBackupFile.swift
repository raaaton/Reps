import Foundation

// Used synchronously by the transfer actor. Only locally-created databases are opened here;
// a selected archive is parsed as bounded authenticated records, never as a SQLite file.
public final class VaultBackupFile {
  let db: SQLiteDatabase
  public let path: String
  static let tables = [
    "vault_state", "vault_movements", "vault_photos", "vault_videos", "vault_video_chunks",
  ]
  public init(path: String) throws {
    self.path = path
    db = try SQLiteDatabase(path: path)
    _ = try db.query("PRAGMA secure_delete=ON")
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_state(singleton INTEGER PRIMARY KEY CHECK(singleton=1),key_id TEXT NOT NULL,verification BLOB NOT NULL)"
    )
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_movements(id TEXT PRIMARY KEY NOT NULL,metadata BLOB NOT NULL)"
    )
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_photos(id TEXT PRIMARY KEY NOT NULL,metadata BLOB NOT NULL,original BLOB NOT NULL,thumbnail BLOB NOT NULL,day_key TEXT)"
    )
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_videos(id TEXT PRIMARY KEY NOT NULL,movement_id TEXT NOT NULL REFERENCES vault_movements(id) ON DELETE CASCADE,metadata BLOB NOT NULL,thumbnail BLOB NOT NULL,byte_count INTEGER NOT NULL,import_session TEXT NOT NULL,complete INTEGER NOT NULL CHECK(complete=1))"
    )
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_video_chunks(video_id TEXT NOT NULL REFERENCES vault_videos(id) ON DELETE CASCADE,position INTEGER NOT NULL,ciphertext BLOB NOT NULL,PRIMARY KEY(video_id,position))"
    )
  }
  public func inventory() throws -> VaultBackupInventory {
    try Self.inventory(db, schema: "main")
  }
  static func inventory(_ db: SQLiteDatabase, schema: String) throws -> VaultBackupInventory {
    func count(_ table: String) throws -> Int {
      try db.query("SELECT COUNT(*) AS n FROM \(schema).\(table)").first!.integer("n")
    }
    let photos = try count("vault_photos")
    let movements = try count("vault_movements")
    let videos = try count("vault_videos")
    guard photos <= 1000, movements <= 2000, videos <= 5000,
      try db.query("SELECT 1 FROM \(schema).vault_videos WHERE complete != 1 LIMIT 1").isEmpty
    else { throw PortableBackupFailure.invalid }
    return VaultBackupInventory(photos: photos, movements: movements, videos: videos)
  }
  public func setState(keyID: String, verification: Data) throws {
    guard UUID(uuidString: keyID) != nil, (28...1024).contains(verification.count) else {
      throw PortableBackupFailure.invalid
    }
    try db.execute("DELETE FROM vault_state")
    try db.execute("INSERT INTO vault_state VALUES(1,?,?)", [.text(keyID), .blob(verification)])
  }
  public func keyID() throws -> String {
    guard
      let id = try db.query("SELECT key_id FROM vault_state WHERE singleton=1").first?.text(
        "key_id"), UUID(uuidString: id) != nil
    else { throw PortableBackupFailure.invalid }
    return id
  }
  public func append(_ r: VaultBackupRecord) throws {
    guard UUID(uuidString: r.id) != nil else { throw PortableBackupFailure.invalid }
    func blob(_ value: Data?, _ maximum: Int) throws -> SQLValue {
      guard let value, (28...maximum).contains(value.count) else {
        throw PortableBackupFailure.invalid
      }
      return .blob(value)
    }
    switch r.kind {
    case .movement:
      guard r.original == nil, r.thumbnail == nil, r.payload == nil, r.position == nil,
        r.movementID == nil, r.byteCount == nil, r.dayKey == nil
      else { throw PortableBackupFailure.invalid }
      try db.execute(
        "INSERT INTO vault_movements VALUES(?,?)", [.text(r.id), try blob(r.metadata, 32768)])
    case .photo:
      guard r.payload == nil, r.position == nil, r.movementID == nil, r.byteCount == nil,
        r.dayKey.map({
          TrainingAnalytics.date(for: $0, calendar: Calendar(identifier: .gregorian)) != nil
            && $0.utf8.count == 10
        }) ?? true
      else { throw PortableBackupFailure.invalid }
      try db.execute(
        "INSERT INTO vault_photos VALUES(?,?,?,?,?)",
        [
          .text(r.id), try blob(r.metadata, 16384), try blob(r.original, 24 * 1024 * 1024 + 28),
          try blob(r.thumbnail, 1024 * 1024), r.dayKey.map(SQLValue.text) ?? .null,
        ])
    case .video:
      guard let movement = r.movementID, UUID(uuidString: movement) != nil,
        let bytes = r.byteCount, (1...VaultVideoLimits.maximumBytes).contains(bytes),
        r.original == nil, r.payload == nil, r.position == nil, r.dayKey == nil
      else { throw PortableBackupFailure.invalid }
      try db.execute(
        "INSERT INTO vault_videos VALUES(?,?,?,?,?,'backup',1)",
        [
          .text(r.id), .text(movement), try blob(r.metadata, 16384),
          try blob(r.thumbnail, 1024 * 1024), .integer(bytes),
        ])
    case .chunk:
      guard let index = r.position, (0..<500).contains(index), r.metadata == nil,
        r.original == nil, r.thumbnail == nil, r.movementID == nil, r.byteCount == nil,
        r.dayKey == nil,
        let bytes = try db.query("SELECT byte_count FROM vault_videos WHERE id=?", [.text(r.id)])
          .first?.integer("byte_count"),
        index < (bytes + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes,
        r.payload?.count == min(
          VaultVideoLimits.chunkBytes, bytes - index * VaultVideoLimits.chunkBytes) + 28
      else { throw PortableBackupFailure.invalid }
      try db.execute(
        "INSERT INTO vault_video_chunks VALUES(?,?,?)",
        [.text(r.id), .integer(index), try blob(r.payload, VaultVideoLimits.chunkBytes + 28)])
    }
  }
  public func readRecords(_ consume: (VaultBackupRecord) throws -> Void) throws {
    _ = try inventory()
    for row in try db.query("SELECT id FROM vault_movements ORDER BY id") {
      let id = try row.text("id")
      let value = try db.query("SELECT metadata FROM vault_movements WHERE id=?", [.text(id)])
        .first!
      try consume(VaultBackupRecord(kind: .movement, id: id, metadata: value.blob("metadata")))
    }
    for row in try db.query("SELECT id FROM vault_photos ORDER BY id") {
      let id = try row.text("id")
      let v = try db.query("SELECT * FROM vault_photos WHERE id=?", [.text(id)]).first!
      try consume(
        VaultBackupRecord(
          kind: .photo, id: id, dayKey: v.optionalText("day_key"), metadata: v.blob("metadata"),
          original: v.blob("original"), thumbnail: v.blob("thumbnail")))
    }
    for row in try db.query("SELECT id FROM vault_videos ORDER BY id") {
      let id = try row.text("id")
      let v = try db.query("SELECT * FROM vault_videos WHERE id=?", [.text(id)]).first!
      try consume(
        VaultBackupRecord(
          kind: .video, id: id, movementID: v.text("movement_id"),
          byteCount: v.integer("byte_count"), metadata: v.blob("metadata"),
          thumbnail: v.blob("thumbnail")))
      for c in try db.query(
        "SELECT position FROM vault_video_chunks WHERE video_id=? ORDER BY position", [.text(id)])
      {
        let index = try c.integer("position")
        let data = try db.query(
          "SELECT ciphertext FROM vault_video_chunks WHERE video_id=? AND position=?",
          [.text(id), .integer(index)]
        ).first!.blob("ciphertext")
        try consume(VaultBackupRecord(kind: .chunk, id: id, position: index, payload: data))
      }
    }
  }
  public func validate() throws {
    _ = try inventory()
    guard try db.query("PRAGMA foreign_key_check").isEmpty,
      try db.query(
        "SELECT 1 FROM vault_photos WHERE length(metadata) NOT BETWEEN 28 AND 16384 OR length(original) NOT BETWEEN 28 AND 25165852 OR length(thumbnail) NOT BETWEEN 28 AND 1048576 LIMIT 1"
      ).isEmpty,
      try db.query(
        "SELECT 1 FROM vault_movements WHERE length(metadata) NOT BETWEEN 28 AND 32768 LIMIT 1"
      ).isEmpty,
      try db.query(
        "SELECT 1 FROM vault_videos WHERE length(metadata) NOT BETWEEN 28 AND 16384 OR length(thumbnail) NOT BETWEEN 28 AND 1048576 OR byte_count NOT BETWEEN 1 AND 524288000 LIMIT 1"
      ).isEmpty
    else { throw PortableBackupFailure.invalid }
    for row in try db.query("SELECT id,byte_count FROM vault_videos") {
      let bytes = try row.integer("byte_count")
      let chunks = try db.query(
        "SELECT position,length(ciphertext) AS n FROM vault_video_chunks WHERE video_id=? ORDER BY position",
        [.text(row.text("id"))])
      guard chunks.count == (bytes + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes
      else { throw PortableBackupFailure.invalid }
      for (index, chunk) in chunks.enumerated() {
        guard try chunk.integer("position") == index,
          try chunk.integer("n") == min(
            VaultVideoLimits.chunkBytes, bytes - index * VaultVideoLimits.chunkBytes) + 28
        else { throw PortableBackupFailure.invalid }
      }
    }
    try readRecords { r in
      guard UUID(uuidString: r.id) != nil else { throw PortableBackupFailure.invalid }
    }
  }
}

extension VaultRepository {
  public func backupInventory() throws -> VaultBackupInventory {
    _ = try state()
    return try VaultBackupFile.inventory(db, schema: "main")
  }
  public func backupStamp() throws -> VaultBackupStamp {
    let state = try state()
    return try VaultBackupStamp(
      keyID: state?.keyID ?? "",
      revision: db.query("SELECT revision FROM vault_backup_revision WHERE id=1").first!.integer(
        "revision"))
  }
  static func installBackupRevision(_ db: SQLiteDatabase) throws {
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_pending_key(id INTEGER PRIMARY KEY CHECK(id=1),key_id TEXT NOT NULL)"
    )
    try db.execute(
      "CREATE TABLE IF NOT EXISTS vault_backup_revision(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL)"
    )
    try db.execute("INSERT OR IGNORE INTO vault_backup_revision VALUES(1,0)")
    for table in VaultBackupFile.tables {
      for action in ["INSERT", "UPDATE", "DELETE"] {
        try db.execute(
          "CREATE TRIGGER IF NOT EXISTS backup_\(table)_\(action) AFTER \(action) ON \(table) BEGIN UPDATE vault_backup_revision SET revision=revision+1 WHERE id=1; END"
        )
      }
    }
  }
}

extension VaultRepository {
  public func prepareBackupKey() throws -> String {
    try db.transaction {
      guard try state() == nil else { throw VaultFailure.damaged }
      if let id = try db.query("SELECT key_id FROM vault_pending_key WHERE id=1").first?.text(
        "key_id")
      {
        guard UUID(uuidString: id) != nil else { throw VaultFailure.damaged }
        return id
      }
      let id = UUID().uuidString
      try db.execute("INSERT INTO vault_pending_key VALUES(1,?)", [.text(id)])
      return id
    }
  }
}
