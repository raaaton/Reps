import Foundation
import Testing

@testable import RepsCore

struct PortableBackupTests {
  @Test func emptyVaultAndMovementsOnly() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    #expect(try await repo.backupInventory().isEmpty)
    let id = UUID().uuidString
    try await repo.initialize(keyID: id, verification: Data(repeating: 1, count: 32))
    #expect(try await repo.backupInventory().isEmpty)
    try await repo.saveMovement(
      id: UUID().uuidString, encrypted: Data(repeating: 2, count: 40), lease: VaultLease(keyID: id))
    #expect(try await repo.backupInventory().movements == 1)
    #expect(try await !repo.backupInventory().isEmpty)
  }
  @Test func snapshotPreservesBinaryDataAndRejectsRevocation() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let vault = dir.appendingPathComponent("vault").path
    let repo = try VaultRepository(path: vault)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
    let id = UUID().uuidString
    let original = Data([0, 255, 128]) + Data(repeating: 7, count: 30)
    try await repo.insert(
      VaultEncryptedPhoto(
        id: id, metadata: Data(repeating: 3, count: 32), original: original,
        thumbnail: Data(repeating: 4, count: 32)), dayKey: "2026-11-02", lease: lease)
    let training = try RepsRepository(path: dir.appendingPathComponent("training").path)
    let snapshot = dir.appendingPathComponent("snapshot").path
    _ = try await training.captureCompleteBackup(
      vaultPath: vault, snapshotPath: snapshot, lease: lease, now: 1_793_606_400_000)
    let file = try VaultBackupFile(path: snapshot)
    var records: [VaultBackupRecord] = []
    try file.readRecords { records.append($0) }
    #expect(records.count == 1)
    #expect(records[0].original == original)
    lease.invalidate()
    await #expect(throws: (any Error).self) {
      _ = try await training.captureCompleteBackup(
        vaultPath: vault, snapshotPath: dir.appendingPathComponent("revoked").path, lease: lease,
        now: 1_793_606_400_000)
    }
  }
  @Test func stagingRejectsIncompleteVideoAndDuplicateRecords() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let file = try VaultBackupFile(path: path)
    let movement = VaultBackupRecord(
      kind: .movement, id: UUID().uuidString, metadata: Data(repeating: 1, count: 32))
    try file.append(movement)
    #expect(throws: (any Error).self) { try file.append(movement) }
    let video = VaultBackupRecord(
      kind: .video, id: UUID().uuidString, movementID: movement.id, byteCount: 1025,
      metadata: Data(repeating: 2, count: 32), thumbnail: Data(repeating: 3, count: 32))
    try file.append(video)
    #expect(throws: (any Error).self) { try file.validate() }
    try file.append(
      VaultBackupRecord(
        kind: .chunk, id: video.id, position: 0, payload: Data(repeating: 4, count: 1053)))
    try file.validate()
    #expect(try file.inventory().videos == 1)
  }
  @Test func framingRejectsUnboundedParametersAndTruncation() throws {
    let header = try PortableBackupHeader(
      salt: Data(repeating: 1, count: 16), wrappedKey: Data(repeating: 2, count: 60))
    let bytes = header.encoded
    #expect(try PortableBackupHeader(data: bytes).salt == Data(repeating: 1, count: 16))
    for size in [0, 7, 16, bytes.count - 1] {
      #expect(throws: (any Error).self) { _ = try PortableBackupHeader(data: bytes.prefix(size)) }
    }
    var bad = bytes
    bad[8] = 255
    #expect(throws: (any Error).self) { _ = try PortableBackupHeader(data: bad) }
    #expect(throws: (any Error).self) { _ = try PortableBackupHeader(data: bytes + Data([0])) }
  }
  @Test func restoreRollsBackBothDatabasesAndKeepsRecovery() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let vp = dir.appendingPathComponent("vault").path
    let repo = try VaultRepository(path: vp)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
    let oldID = UUID().uuidString
    try await repo.saveMovement(id: oldID, encrypted: Data(repeating: 2, count: 32), lease: lease)
    let trainingPath = dir.appendingPathComponent("training").path
    let training = try RepsRepository(path: trainingPath)
    let before = try await training.exportTraining(now: 1_793_606_400_000)
    var incoming = before
    incoming.contents.configuration.restSeconds = 90
    let preview = try await training.previewArchiveImport(incoming, now: 1_793_606_400_000)
    let stage = try VaultBackupFile(path: dir.appendingPathComponent("stage").path)
    try stage.setState(keyID: lease.keyID, verification: Data(repeating: 3, count: 32))
    let newID = UUID().uuidString
    try stage.append(
      VaultBackupRecord(kind: .movement, id: newID, metadata: Data(repeating: 4, count: 32)))
    let stamp = try await repo.backupStamp()
    let db = try SQLiteDatabase(path: vp)
    try db.execute(
      "CREATE TRIGGER fail_restore BEFORE DELETE ON vault_movements BEGIN SELECT RAISE(ABORT,'test refusal'); END"
    )
    await #expect(throws: (any Error).self) {
      try await training.applyCompleteBackup(
        preview, vaultPath: vp, stagedPath: stage.path, expected: stamp, lease: lease,
        now: 1_793_606_400_000)
    }
    #expect(try await training.snapshot().restSeconds == before.contents.configuration.restSeconds)
    #expect(try await repo.movements(lease: lease).map(\.id) == [oldID])
    try db.execute("DROP TRIGGER fail_restore")
    try await training.applyCompleteBackup(
      preview, vaultPath: vp, stagedPath: stage.path, expected: stamp, lease: lease,
      now: 1_793_606_400_000)
    #expect(try await training.snapshot().restSeconds == 90)
    #expect(try await repo.movements(lease: lease).map(\.id) == [newID])
    #expect(
      try db.query("SELECT id FROM recovery_vault_movements").map { try $0.text("id") } == [oldID])
    await #expect(throws: (any Error).self) {
      try await training.applyCompleteBackup(
        preview, vaultPath: vp, stagedPath: stage.path, expected: stamp, lease: lease,
        now: 1_793_606_400_000)
    }
  }

  @Test func pendingKeyPreparationSurvivesReopenAndCannotChangeIdentity() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let pending = try await repo.prepareBackupKey()
    let reopened = try VaultRepository(path: path)
    #expect(try await reopened.prepareBackupKey() == pending)
    #expect(try await reopened.state() == nil)
    await #expect(throws: (any Error).self) {
      try await reopened.initialize(
        keyID: UUID().uuidString, verification: Data(repeating: 1, count: 32))
    }
    try await reopened.initialize(keyID: pending, verification: Data(repeating: 1, count: 32))
    #expect(try await reopened.state()?.keyID == pending)
    await #expect(throws: (any Error).self) { _ = try await reopened.prepareBackupKey() }
  }

  @Test func processInterruptionRecoversBothFiles() async throws {
    #if os(Linux)
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: dir) }
      let vp = dir.appendingPathComponent("vault").path
      let tp = dir.appendingPathComponent("training").path
      let vault = try VaultRepository(path: vp)
      let lease = VaultLease(keyID: UUID().uuidString)
      try await vault.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
      let id = UUID().uuidString
      try await vault.saveMovement(id: id, encrypted: Data(repeating: 2, count: 32), lease: lease)
      let training = try RepsRepository(path: tp)
      let oldRest = try await training.snapshot().restSeconds
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
      process.arguments = [
        "-c",
        #"""
        import sqlite3,sys,os
        c=sqlite3.connect(sys.argv[1])
        c.execute('ATTACH DATABASE ? AS private_backup',(sys.argv[2],))
        c.execute('PRAGMA main.synchronous=EXTRA')
        c.execute('PRAGMA private_backup.synchronous=EXTRA')
        c.execute('PRAGMA main.cache_size=1')
        c.execute('PRAGMA private_backup.cache_size=1')
        c.execute('BEGIN IMMEDIATE')
        c.execute('UPDATE preferences SET rest_seconds=99 WHERE id=1')
        c.execute('UPDATE private_backup.vault_movements SET metadata=zeroblob(2000000)')
        os._exit(91)
        """#, tp, vp,
      ]
      try process.run()
      process.waitUntilExit()
      #expect(process.terminationStatus == 91)
      let reopenedTraining = try RepsRepository(path: tp)
      let reopenedVault = try VaultRepository(path: vp)
      #expect(try await reopenedTraining.snapshot().restSeconds == oldRest)
      #expect(
        try await reopenedVault.movements(lease: lease).first?.data == Data(repeating: 2, count: 32)
      )
    #endif
  }
  @Test func jsonRestorePreservesPrivateData() async throws {
    let vault = try VaultRepository(path: ":memory:")
    let lease = VaultLease(keyID: UUID().uuidString)
    try await vault.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
    let id = UUID().uuidString
    try await vault.saveMovement(id: id, encrypted: Data(repeating: 9, count: 32), lease: lease)
    let training = try RepsRepository(path: ":memory:")
    var archive = try await training.exportTraining(now: 1_793_606_400_000)
    archive.contents.configuration.restSeconds = 90
    let preview = try await training.previewArchiveImport(archive, now: 1_793_606_400_000)
    try await training.applyTrainingImport(preview, now: 1_793_606_400_000)
    #expect(try await vault.movements(lease: lease).first?.data == Data(repeating: 9, count: 32))
    #expect(try await vault.state()?.keyID == lease.keyID)
  }

  @Test func captureFailureReportsStageAndSQLiteCodesWithoutPrivateDetails() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("private-name-sentinel.sqlite").path
    let vault = try VaultRepository(path: source)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await vault.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
    let db = try SQLiteDatabase(path: source)
    try db.execute("DROP TABLE vault_video_chunks")
    let training = try RepsRepository(path: dir.appendingPathComponent("training.sqlite").path)
    do {
      _ = try await training.captureCompleteBackup(
        vaultPath: source, snapshotPath: dir.appendingPathComponent("snapshot.sqlite").path,
        lease: lease, now: 1_793_606_400_000)
      Issue.record("Damaged source must fail")
    } catch let failure as PortableBackupStorageFailure {
      #expect(failure.stage == "snapshot.copy.vault_video_chunks")
      #expect(failure.code == 1)
      #expect(failure.extendedCode == 1)
      #expect(!failure.localizedDescription.contains("private-name-sentinel"))
      #expect(!failure.localizedDescription.contains(lease.keyID))
      #expect(!failure.localizedDescription.contains("SELECT"))
    }
    #expect(try await vault.state()?.keyID == lease.keyID)
  }

  @Test func automaticRollbackPreservesOriginalSQLiteFailure() throws {
    let db = try SQLiteDatabase(path: ":memory:")
    try db.execute("CREATE TABLE conflict_probe(value INTEGER UNIQUE ON CONFLICT ROLLBACK)")
    try db.execute("INSERT INTO conflict_probe VALUES(1)")
    db.lastFailure = nil
    #expect(throws: (any Error).self) {
      try db.transaction { try db.execute("INSERT INTO conflict_probe VALUES(1)") }
    }
    #expect(db.lastFailure?.code == 19)
    #expect(db.lastFailure?.extended == 2067)
    #expect(try db.query("SELECT value FROM conflict_probe").first?.integer("value") == 1)
  }

}
