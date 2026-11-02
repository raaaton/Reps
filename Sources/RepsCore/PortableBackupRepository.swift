import Foundation

extension RepsRepository {
  private func attachBackupDatabase(_ path: String, as schema: String) throws {
    guard !path.isEmpty, path != ":memory:", FileManager.default.fileExists(atPath: path) else {
      throw PortableBackupFailure.invalid
    }
    try database.execute("ATTACH DATABASE ? AS \(schema)", [.text(path)])
  }
  private func requireAtomicBackupJournals(_ schemas: [String]) throws {
    for schema in schemas {
      guard let row = try database.query("PRAGMA \(schema).journal_mode").first,
        try row.text("journal_mode") == "delete",
        let file = try database.query("PRAGMA database_list").first(where: {
          try $0.text("name") == schema
        }),
        try !file.text("file").isEmpty
      else { throw PortableBackupFailure.invalid }
      try database.execute("PRAGMA \(schema).synchronous=EXTRA")
    }
    try database.execute("PRAGMA fullfsync=ON")
  }
  public func captureCompleteBackup(
    vaultPath: String, snapshotPath: String, lease: VaultLease, now: Int
  ) throws -> TrainingArchive {
    var stage = "snapshot.create"
    database.lastFailure = nil
    do {
      try lease.check()
      guard !FileManager.default.fileExists(atPath: snapshotPath), vaultPath != snapshotPath else {
        throw PortableBackupFailure.invalid
      }
      _ = try VaultBackupFile(path: snapshotPath)
      stage = "snapshot.attach.vault"
      try attachBackupDatabase(vaultPath, as: "private_backup")
      defer { try? database.execute("DETACH DATABASE private_backup") }
      stage = "snapshot.attach.staging"
      try attachBackupDatabase(snapshotPath, as: "staged_backup")
      defer { try? database.execute("DETACH DATABASE staged_backup") }
      stage = "snapshot.begin"
      return try database.transaction {
        stage = "snapshot.authorize"
        guard
          try database.query("SELECT key_id FROM private_backup.vault_state WHERE singleton=1")
            .first?.text("key_id") == lease.keyID
        else { throw VaultFailure.locked }
        stage = "snapshot.inventory"
        _ = try VaultBackupFile.inventory(database, schema: "private_backup")
        for table in VaultBackupFile.tables {
          stage = "snapshot.copy.\(table)"
          try database.execute(
            "INSERT INTO staged_backup.\(table) SELECT * FROM private_backup.\(table)")
        }
        stage = "snapshot.training"
        let archive = TrainingArchive(createdAt: now, contents: try readTransferData())
        try archive.validate()
        try lease.check()
        stage = "snapshot.commit"
        return archive
      }
    } catch TrainingError.storage {
      throw PortableBackupStorageFailure(
        stage: stage, code: database.lastFailure?.code, extendedCode: database.lastFailure?.extended
      )
    }
  }
  public func applyCompleteBackup(
    _ preview: TrainingImportPreview, vaultPath: String, stagedPath: String,
    expected: VaultBackupStamp, lease: VaultLease, now: Int
  ) throws {
    try lease.check()
    guard vaultPath != stagedPath, lease.keyID == expected.keyID else {
      throw PortableBackupFailure.invalid
    }
    let staged = try VaultBackupFile(path: stagedPath)
    try staged.validate()
    guard try staged.keyID() == expected.keyID else { throw PortableBackupFailure.invalid }
    try attachBackupDatabase(vaultPath, as: "private_backup")
    defer { try? database.execute("DETACH DATABASE private_backup") }
    try attachBackupDatabase(stagedPath, as: "staged_backup")
    defer { try? database.execute("DETACH DATABASE staged_backup") }
    try requireAtomicBackupJournals(["main", "private_backup"])
    try database.transaction {
      try lease.check()
      guard
        try database.query("SELECT key_id FROM private_backup.vault_state WHERE singleton=1").first?
          .text("key_id") == expected.keyID,
        try database.query("SELECT revision FROM private_backup.vault_backup_revision WHERE id=1")
          .first?.integer("revision") == expected.revision
      else { throw PortableBackupFailure.changed }
      // Recovery remains encrypted under the same destination biometric key, including the old
      // key marker. The same SQLite super-journal protects recovery, training and published vault.
      for table in VaultBackupFile.tables {
        try database.execute(
          "CREATE TABLE IF NOT EXISTS private_backup.recovery_\(table) AS SELECT * FROM private_backup.\(table) WHERE 0"
        )
        try database.execute("DELETE FROM private_backup.recovery_\(table)")
        try database.execute(
          "INSERT INTO private_backup.recovery_\(table) SELECT * FROM private_backup.\(table)")
      }
      try applyTrainingImportBody(preview, now: now)
      for table in VaultBackupFile.tables.reversed() {
        try database.execute("DELETE FROM private_backup.\(table)")
      }
      for table in VaultBackupFile.tables {
        try database.execute(
          "INSERT INTO private_backup.\(table) SELECT * FROM staged_backup.\(table)")
      }
      guard try database.query("PRAGMA private_backup.foreign_key_check").isEmpty else {
        throw PortableBackupFailure.invalid
      }
      try lease.check()
    }
  }
}
