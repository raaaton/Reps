#if DEBUG
  import CryptoKit
  import Darwin
  import Foundation
  import RepsCore
  import UIKit

  // A bounded, fixed synthetic archive; never uses the real repositories or biometric keys.
  @MainActor
  enum PortableBackupMemoryProbe {
    static func peakBytes() -> Int {
      var usage = rusage()
      guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
      return Int(usage.ru_maxrss)
    }
    static func run(chunkCount: Int = 32) async throws -> String {
      let workspace = try PortableBackupWorkspace()
      defer { withExtendedLifetime(workspace) {} }
      let available =
        (try FileManager.default.attributesOfFileSystem(forPath: workspace.folder.path)[
          .systemFreeSize] as? NSNumber)?.int64Value ?? 0
      let required = Int64(chunkCount) * Int64(VaultVideoLimits.chunkBytes) * 3 + 128 * 1024 * 1024
      guard available >= required else {
        return
          "SKIP backup memory: synthetic test needs \(required / 1_048_576) MiB free, available \(available / 1_048_576) MiB."
      }
      let training = try RepsRepository(path: workspace.url("training.sqlite").path)
      let archive = try await training.exportTraining(now: 1_793_606_400_000)
      let password = "Synthetic memory test password"
      let salt = Data(repeating: 7, count: 16)
      let archiveKey = SymmetricKey(size: .bits256)
      let wrappingKey = try PortableBackupEngine.derive(password: password, salt: salt)
      let prefix = try PortableBackupHeader(salt: salt, wrappedKey: Data(repeating: 0, count: 60))
        .authenticatedPrefix
      guard
        let wrapped = try AES.GCM.seal(
          archiveKey.withUnsafeBytes { Data($0) }, using: wrappingKey, authenticating: prefix
        ).combined
      else { throw PortableBackupFailure.invalid }
      let header = try PortableBackupHeader(salt: salt, wrappedKey: wrapped).encoded
      let input = workspace.url("memory.repsbackup")
      guard
        FileManager.default.createFile(
          atPath: input.path, contents: nil,
          attributes: [.protectionKey: FileProtectionType.complete])
      else { throw PortableBackupFailure.invalid }
      let handle = try FileHandle(forWritingTo: input)
      try handle.write(contentsOf: header)
      let stream = PortableBackupStream(handle: handle, header: header, key: archiveKey)
      try stream.write(type: 1, data: archive.encoded(), check: {})
      let movement = UUID().uuidString
      let video = UUID().uuidString
      let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).jpegData(
        withCompressionQuality: 0.8
      ) { c in
        UIColor.blue.setFill()
        c.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
      }
      try autoreleasepool {
        try stream.write(
          type: 2,
          data: JSONEncoder().encode(
            VaultBackupRecord(
              kind: .movement, id: movement,
              metadata: JSONEncoder().encode(
                VaultMovementMetadata(name: "Synthetic memory fixture")))), check: {})
        try stream.write(
          type: 2,
          data: JSONEncoder().encode(
            VaultBackupRecord(
              kind: .video, id: video, movementID: movement,
              byteCount: chunkCount * VaultVideoLimits.chunkBytes,
              metadata: JSONEncoder().encode(
                VaultVideoMetadata(
                  dayKey: "2026-11-02", movementID: movement, type: "public.mpeg-4", duration: 4,
                  byteCount: chunkCount * VaultVideoLimits.chunkBytes, importedAt: 0,
                  audioRemoved: true)), thumbnail: image)), check: {})
      }
      for index in 0..<chunkCount {
        try autoreleasepool {
          let record = VaultBackupRecord(
            kind: .chunk, id: video, position: index,
            payload: Data(
              repeating: UInt8(truncatingIfNeeded: index), count: VaultVideoLimits.chunkBytes))
          try stream.write(type: 2, data: JSONEncoder().encode(record), check: {})
        }
      }
      try stream.write(
        type: 0,
        data: JSONSerialization.data(withJSONObject: [
          "records": chunkCount + 2, "inventory": ["photos": 0, "movements": 1, "videos": 1],
        ]), check: {})
      try handle.synchronize()
      try handle.close()
      let lease = VaultLease(keyID: UUID().uuidString)
      let access = PortableBackupAccess(
        key: SymmetricKey(size: .bits256), lease: lease, path: "",
        stamp: VaultBackupStamp(keyID: lease.keyID, revision: 0))
      let before = peakBytes()
      let result = try await PortableBackupEngine().read(
        url: input, password: password, access: access, staged: workspace.url("staged.sqlite"))
      let after = peakBytes()
      guard result.inventory.videos == 1, result.inventory.movements == 1 else {
        throw PortableBackupFailure.invalid
      }
      let growth = max(0, after - before)
      let pass = before > 0 && after > 0 && growth < 96 * 1024 * 1024
      return
        "\(pass ? "PASS" : "FAIL") backup memory: \(chunkCount) MiB streaming import; peak before \(before / 1_048_576) MiB, after \(after / 1_048_576) MiB, growth \(growth / 1_048_576) MiB; limit 96 MiB."
    }
  }
#endif
