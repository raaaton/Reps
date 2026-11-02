#if DEBUG
  import CryptoKit
  import Foundation
  import RepsCore
  import UIKit

  @MainActor
  enum PortableBackupProbe {
    static var stage = "KDF known vector"
    static func run() async throws -> String {
      let workspace = try PortableBackupWorkspace()
      defer { withExtendedLifetime(workspace) {} }
      let engine = PortableBackupEngine()
      let known = try PortableBackupEngine.derive(
        password: "passwd", salt: Data("salt".utf8), rounds: 1)
      guard
        known.withUnsafeBytes({ Data($0) })
          == Data([
            0x55, 0xac, 0x04, 0x6e, 0x56, 0xe3, 0x08, 0x9f, 0xec, 0x16, 0x91, 0xc2, 0x25, 0x44,
            0xb6, 0x05, 0xf9, 0x41, 0x85, 0x21, 0x6d, 0xde, 0x04, 0x65, 0xe6, 0x8b, 0x9d, 0x57,
            0xc2, 0x0d, 0xac, 0xbc,
          ])
      else { throw PortableBackupFailure.invalid }
      let key = SymmetricKey(size: .bits256)
      let lease = VaultLease(keyID: UUID().uuidString)
      let snapshot = workspace.url("source.sqlite")
      let liveVault = try VaultRepository(path: snapshot.path)
      defer { withExtendedLifetime(liveVault) {} }
      let file = try VaultBackupFile(path: snapshot.path)
      try file.setState(keyID: lease.keyID, verification: Data(repeating: 1, count: 32))
      let movementID = UUID().uuidString
      var movement = VaultBackupRecord(
        kind: .movement, id: movementID,
        metadata: try JSONEncoder().encode(VaultMovementMetadata(name: "Synthetic backup test")))
      try movement.mapPayloads {
        try VaultCryptography.seal($0, key: key, keyID: lease.keyID, id: $1, role: $2)
      }
      try file.append(movement)
      let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).jpegData(
        withCompressionQuality: 0.8
      ) { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
      }
      let photoID = UUID().uuidString
      var photo = VaultBackupRecord(
        kind: .photo, id: photoID, dayKey: "2026-11-02",
        metadata: try JSONEncoder().encode(
          VaultPhotoMetadata(dayKey: "2026-11-02", type: "public.jpeg", pose: .other)),
        original: image, thumbnail: image)
      try photo.mapPayloads {
        try VaultCryptography.seal($0, key: key, keyID: lease.keyID, id: $1, role: $2)
      }
      try file.append(photo)
      let videoID = UUID().uuidString
      let bytes = Data(repeating: 123, count: 2 * 1024 * 1024 + 13)
      var video = VaultBackupRecord(
        kind: .video, id: videoID, movementID: movementID, byteCount: bytes.count,
        metadata: try JSONEncoder().encode(
          VaultVideoMetadata(
            dayKey: "2026-11-02", movementID: movementID, type: "public.mpeg-4", duration: 4,
            byteCount: bytes.count, importedAt: 0, audioRemoved: true)), thumbnail: image)
      try video.mapPayloads {
        try VaultCryptography.seal($0, key: key, keyID: lease.keyID, id: $1, role: $2)
      }
      try file.append(video)
      for (index, offset) in stride(from: 0, to: bytes.count, by: VaultVideoLimits.chunkBytes)
        .enumerated()
      {
        var chunk = VaultBackupRecord(
          kind: .chunk, id: videoID, position: index,
          payload: bytes.subdata(
            in: offset..<min(offset + VaultVideoLimits.chunkBytes, bytes.count)))
        try chunk.mapPayloads {
          try VaultCryptography.seal($0, key: key, keyID: lease.keyID, id: $1, role: $2)
        }
        try file.append(chunk)
      }
      let training = try RepsRepository(path: workspace.url("training.sqlite").path)
      stage = "capture original vault into coherent snapshot"
      let captured = workspace.url("captured.sqlite")
      let archive = try await training.captureCompleteBackup(
        vaultPath: snapshot.path, snapshotPath: captured.path, lease: lease, now: 1_793_606_400_000)
      let source = PortableBackupAccess(
        key: key, lease: lease, path: snapshot.path,
        stamp: VaultBackupStamp(keyID: lease.keyID, revision: 0))
      let password = "Synthetic backup passphrase"
      let output = workspace.url("test.repsbackup")
      stage = "encrypt source"
      let start = Date()
      try await engine.export(
        archive: archive, snapshot: captured, access: source, password: password, output: output)
      let elapsed = Int(Date().timeIntervalSince(start) * 1000)
      let destinationKey = SymmetricKey(size: .bits256)
      let destinationLease = VaultLease(keyID: UUID().uuidString)
      let destination = PortableBackupAccess(
        key: destinationKey, lease: destinationLease, path: "synthetic",
        stamp: VaultBackupStamp(keyID: destinationLease.keyID, revision: 0))
      let staged = workspace.url("destination.sqlite")
      stage = "authenticate and decrypt archive"
      let restored = try await engine.read(
        url: output, password: password, access: destination, staged: staged)
      guard restored.archive == archive, restored.inventory.photos == 1,
        restored.inventory.movements == 1, restored.inventory.videos == 1
      else { throw PortableBackupFailure.invalid }
      var recovered = Data()
      try VaultBackupFile(path: staged.path).readRecords { record in
        var clear = record
        try clear.mapPayloads {
          try VaultCryptography.open(
            $0, key: destinationKey, keyID: destinationLease.keyID, id: $1, role: $2)
        }
        if clear.kind == .chunk { recovered.append(clear.payload!) }
        if clear.kind == .photo {
          guard clear.original == image else { throw PortableBackupFailure.invalid }
        }
      }
      guard recovered == bytes else { throw PortableBackupFailure.invalid }
      stage = "rekey and publish both databases"
      let publishedPath = workspace.url("published.sqlite").path
      let targetRepo = try VaultRepository(path: publishedPath)
      let targetKey = SymmetricKey(size: .bits256)
      let targetLease = VaultLease(keyID: UUID().uuidString)
      let verification = try VaultCryptography.seal(
        Data("Sport vault v1".utf8), key: targetKey, keyID: targetLease.keyID, id: "vault",
        role: "verification")
      try await targetRepo.initialize(keyID: targetLease.keyID, verification: verification)
      let targetAccess = try await PortableBackupAccess(
        key: targetKey, lease: targetLease, path: publishedPath, stamp: targetRepo.backupStamp())
      let rekeyed = workspace.url("rekeyed.sqlite")
      try await engine.rekey(
        source: staged, from: destination, to: targetAccess, destination: rekeyed)
      let targetTraining = try RepsRepository(path: workspace.url("target-training.sqlite").path)
      try await targetTraining.saveRest(seconds: 99)
      let preview = try await targetTraining.previewArchiveImport(
        restored.archive, now: 1_793_606_400_000)
      try await targetTraining.applyCompleteBackup(
        preview, vaultPath: publishedPath, stagedPath: rekeyed.path, expected: targetAccess.stamp,
        lease: targetLease, now: 1_793_606_400_000)
      guard
        try await targetTraining.snapshot().restSeconds
          == archive.contents.configuration.restSeconds,
        try await targetRepo.backupInventory() == restored.inventory,
        try await VaultCryptography.open(
          targetRepo.content(id: photoID, thumbnail: false, lease: targetLease), key: targetKey,
          keyID: targetLease.keyID, id: photoID, role: "original") == image
      else { throw PortableBackupFailure.invalid }
      stage = "distinct exports and hostile archives"
      let second = workspace.url("second.repsbackup")
      try await engine.export(
        archive: archive, snapshot: captured, access: source, password: password, output: second)
      let original = try Data(contentsOf: output)
      guard original != (try Data(contentsOf: second)) else { throw PortableBackupFailure.invalid }
      var badTag = original
      badTag[badTag.count - 1] ^= 1
      var badHeader = original
      badHeader[12] ^= 1
      let startOffset = PortableBackupHeader.size
      func endOfFrame(_ at: Int) -> Int {
        at + 4 + original.subdata(in: at..<(at + 4)).reduce(0) { $0 * 256 + Int($1) }
      }
      let firstEnd = endOfFrame(startOffset)
      let secondEnd = endOfFrame(firstEnd)
      let reordered =
        original.prefix(startOffset) + original.subdata(in: firstEnd..<secondEnd)
        + original.subdata(in: startOffset..<firstEnd) + original.suffix(from: secondEnd)
      let variants = [
        badTag, badHeader, Data(original.dropLast()), original + Data([0]), reordered,
      ]
      for (index, data) in variants.enumerated() {
        let bad = workspace.url("bad-\(index).repsbackup")
        try data.write(to: bad)
        var rejected = false
        do {
          _ = try await engine.read(
            url: bad, password: password, access: destination,
            staged: workspace.url("bad-\(index).sqlite"))
        } catch { rejected = true }
        guard rejected else { throw PortableBackupFailure.invalid }
      }
      var rejected = false
      do {
        _ = try await engine.read(
          url: output, password: "wrong password", access: destination,
          staged: workspace.url("wrong.sqlite"))
      } catch { rejected = true }
      guard rejected else { throw PortableBackupFailure.invalid }
      lease.invalidate()
      rejected = false
      do {
        try await engine.export(
          archive: archive, snapshot: captured, access: source, password: password,
          output: workspace.url("revoked.repsbackup"))
      } catch { rejected = true }
      guard rejected else { throw PortableBackupFailure.invalid }
      return
        "PASS backup: KDF vector, original-vault snapshot capture, complete encrypted round-trip, different destination key, multiblock video, atomic restore/rekey, random exports, wrong password, tamper/reorder, truncation, appended data, revocation; export \(elapsed) ms."
    }
  }
#endif
