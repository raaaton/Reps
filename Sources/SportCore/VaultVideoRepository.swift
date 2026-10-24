import Foundation

extension VaultRepository {
  public func movements(lease: VaultLease) throws -> [(id: String, data: Data)] {
    try authorize(lease)
    let bounds = try db.query("SELECT id,length(metadata) AS n FROM vault_movements LIMIT 2001")
    guard bounds.count <= 2000 else { throw VaultFailure.damaged }
    for row in bounds {
      guard UUID(uuidString: try row.text("id")) != nil,
        (28...32768).contains(try row.integer("n"))
      else { throw VaultFailure.damaged }
    }
    let rows = try db.query("SELECT id,metadata FROM vault_movements")
    try lease.check()
    return try rows.map { (try $0.text("id"), try $0.blob("metadata")) }
  }
  public func saveMovement(id: String, encrypted: Data, lease: VaultLease) throws {
    guard UUID(uuidString: id) != nil, (28...32768).contains(encrypted.count) else {
      throw VaultFailure.damaged
    }
    try db.transaction {
      try authorize(lease)
      let count = try db.query("SELECT COUNT(*) AS n FROM vault_movements").first!.integer("n")
      let exists = try !db.query("SELECT id FROM vault_movements WHERE id=?", [.text(id)]).isEmpty
      guard count < 2000 || exists else { throw VaultVideoFailure.storage }
      try db.execute(
        "INSERT INTO vault_movements(id,metadata) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET metadata=excluded.metadata",
        [.text(id), .blob(encrypted)])
      try lease.check()
    }
  }
  public func videoMetadata(lease: VaultLease) throws -> [VaultEncryptedVideo] {
    try authorize(lease)
    let rows = try db.query(
      "SELECT id,movement_id,byte_count,length(metadata) AS m,length(thumbnail) AS t FROM vault_videos WHERE complete=1 LIMIT 5001"
    )
    guard rows.count <= 5000 else { throw VaultFailure.damaged }
    for row in rows {
      guard UUID(uuidString: try row.text("id")) != nil,
        UUID(uuidString: try row.text("movement_id")) != nil,
        (1...VaultVideoLimits.maximumBytes).contains(try row.integer("byte_count")),
        (28...16384).contains(try row.integer("m")),
        (28...(1024 * 1024)).contains(try row.integer("t"))
      else { throw VaultFailure.damaged }
    }
    // Only metadata is loaded here; thumbnails and media remain lazy.
    let metadata = try db.query(
      "SELECT id,movement_id,metadata,byte_count FROM vault_videos WHERE complete=1")
    try lease.check()
    return try metadata.map {
      try VaultEncryptedVideo(
        id: $0.text("id"), movementID: $0.text("movement_id"), metadata: $0.blob("metadata"),
        thumbnail: Data(), byteCount: $0.integer("byte_count"))
    }
  }
  public func beginVideo(_ value: VaultEncryptedVideo, lease: VaultLease) throws {
    guard UUID(uuidString: value.id) != nil, UUID(uuidString: value.movementID) != nil,
      (28...16384).contains(value.metadata.count),
      (28...(1024 * 1024)).contains(value.thumbnail.count),
      (1...VaultVideoLimits.maximumBytes).contains(value.byteCount)
    else { throw VaultVideoFailure.tooLarge }
    try db.transaction {
      try authorize(lease)
      guard try db.query("SELECT COUNT(*) AS n FROM vault_videos").first!.integer("n") < 5000 else {
        throw VaultVideoFailure.storage
      }
      try db.execute(
        "INSERT INTO vault_videos(id,movement_id,metadata,thumbnail,byte_count,import_session,complete) VALUES(?,?,?,?,?,?,0)",
        [
          .text(value.id), .text(value.movementID), .blob(value.metadata), .blob(value.thumbnail),
          .integer(value.byteCount), .text(lease.id.uuidString),
        ])
      try lease.check()
    }
  }
  public func appendVideoChunk(id: String, index: Int, encrypted: Data, lease: VaultLease) throws {
    try db.transaction {
      try authorize(lease)
      guard
        let row = try db.query(
          "SELECT byte_count,complete,import_session FROM vault_videos WHERE id=?", [.text(id)]
        ).first,
        try row.integer("complete") == 0, try row.text("import_session") == lease.id.uuidString
      else { throw VaultFailure.damaged }
      let total = try row.integer("byte_count")
      guard index >= 0,
        index < (total + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes,
        encrypted.count == min(
          VaultVideoLimits.chunkBytes, total - index * VaultVideoLimits.chunkBytes) + 28
      else { throw VaultFailure.damaged }
      try db.execute(
        "INSERT INTO vault_video_chunks VALUES(?,?,?)",
        [.text(id), .integer(index), .blob(encrypted)])
      try lease.check()
    }
  }
  public func finishVideo(id: String, lease: VaultLease) throws {
    try db.transaction {
      try authorize(lease)
      guard
        let row = try db.query(
          "SELECT byte_count,complete,import_session FROM vault_videos WHERE id=?", [.text(id)]
        ).first,
        try row.integer("complete") == 0, try row.text("import_session") == lease.id.uuidString
      else { throw VaultFailure.damaged }
      let total = try row.integer("byte_count")
      let chunks = try db.query(
        "SELECT position,length(ciphertext) AS n FROM vault_video_chunks WHERE video_id=? ORDER BY position",
        [.text(id)])
      guard chunks.count == (total + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes
      else { throw VaultFailure.damaged }
      for (index, chunk) in chunks.enumerated() {
        guard try chunk.integer("position") == index,
          try chunk.integer("n") == min(
            VaultVideoLimits.chunkBytes, total - index * VaultVideoLimits.chunkBytes) + 28
        else { throw VaultFailure.damaged }
      }
      try db.execute("UPDATE vault_videos SET complete=1 WHERE id=?", [.text(id)])
      try lease.check()
    }
  }
  public func videoChunk(id: String, index: Int, lease: VaultLease) throws -> Data {
    try authorize(lease)
    guard index >= 0, index < 500,
      let row = try db.query(
        "SELECT length(ciphertext) AS n FROM vault_video_chunks JOIN vault_videos ON video_id=id WHERE id=? AND position=? AND complete=1",
        [.text(id), .integer(index)]
      ).first,
      (29...(VaultVideoLimits.chunkBytes + 28)).contains(try row.integer("n"))
    else { throw VaultFailure.damaged }
    guard
      let data = try db.query(
        "SELECT ciphertext FROM vault_video_chunks WHERE video_id=? AND position=?",
        [.text(id), .integer(index)]
      ).first?.blob("ciphertext")
    else { throw VaultFailure.damaged }
    try lease.check()
    return data
  }
  public func videoThumbnail(id: String, lease: VaultLease) throws -> Data {
    try authorize(lease)
    guard
      let row = try db.query(
        "SELECT length(thumbnail) AS n FROM vault_videos WHERE id=? AND complete=1", [.text(id)]
      ).first,
      (28...(1024 * 1024)).contains(try row.integer("n"))
    else { throw VaultFailure.damaged }
    guard
      let data = try db.query("SELECT thumbnail FROM vault_videos WHERE id=?", [.text(id)]).first?
        .blob("thumbnail")
    else { throw VaultFailure.damaged }
    try lease.check()
    return data
  }
  public func cancelVideo(id: String, lease: VaultLease) throws {
    // Cleanup capability is bound to the original import session. It remains usable after
    // revocation but can never delete a published video or another session's import.
    try db.transaction {
      guard try state()?.keyID == lease.keyID else { throw VaultFailure.locked }
      try db.execute(
        "DELETE FROM vault_videos WHERE id=? AND complete=0 AND import_session=?",
        [.text(id), .text(lease.id.uuidString)])
    }
  }
  public func updateVideo(id: String, encrypted: Data, lease: VaultLease) throws {
    guard (28...16384).contains(encrypted.count) else { throw VaultFailure.damaged }
    try db.transaction {
      try authorize(lease)
      guard
        try db.query("SELECT id FROM vault_videos WHERE id=? AND complete=1", [.text(id)]).count
          == 1
      else { throw VaultFailure.damaged }
      try db.execute(
        "UPDATE vault_videos SET metadata=? WHERE id=?", [.blob(encrypted), .text(id)])
      try lease.check()
    }
  }
  public func deleteVideo(id: String, lease: VaultLease) throws {
    try db.transaction {
      try authorize(lease)
      try db.execute("DELETE FROM vault_videos WHERE id=?", [.text(id)])
      try lease.check()
    }
  }
  public func deleteMovement(id: String, lease: VaultLease) throws {
    try db.transaction {
      try authorize(lease)
      try db.execute("DELETE FROM vault_movements WHERE id=?", [.text(id)])
      try lease.check()
    }
  }
}
