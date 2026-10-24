import CryptoKit
import Foundation
import RepsCore

// Shared publication path: an incomplete record stays invisible until all chunks
// are authenticated and the final repository transaction succeeds.
enum VaultVideoPersistence {
  static func write(
    staging: VaultVideoStaging, metadata: VaultVideoMetadata, id: String,
    key: SymmetricKey, lease: VaultLease, repository: VaultRepository,
    replacing sourceID: String? = nil, expectedMetadata: Data? = nil
  ) async throws {
    do {
      try lease.check()
      try metadata.validate()
      let thumbnail = try VaultCryptography.open(
        staging.thumbnail, key: staging.key,
        keyID: staging.keyID, id: "transfer", role: "thumbnail")
      let value = try VaultEncryptedVideo(
        id: id, movementID: metadata.movementID,
        metadata: VaultCryptography.seal(
          JSONEncoder().encode(metadata), key: key,
          keyID: lease.keyID, id: id, role: "video-metadata"),
        thumbnail: VaultCryptography.seal(
          thumbnail, key: key, keyID: lease.keyID,
          id: id, role: "video-thumbnail"), byteCount: staging.byteCount)
      try await repository.beginVideo(
        value, replacing: sourceID, expectedMetadata: expectedMetadata, lease: lease)
      let input = try FileHandle(forReadingFrom: staging.url)
      defer { try? input.close() }
      for offset in stride(from: 0, to: staging.byteCount, by: VaultVideoLimits.chunkBytes) {
        try lease.check()
        try Task.checkCancellation()
        let index = offset / VaultVideoLimits.chunkBytes
        let size = min(VaultVideoLimits.chunkBytes, staging.byteCount - offset)
        guard let encrypted = try input.read(upToCount: size + 28), encrypted.count == size + 28
        else { throw VaultFailure.damaged }
        let clear = try VaultCryptography.open(
          encrypted, key: staging.key, keyID: staging.keyID,
          id: "transfer", role: "video-chunk/\(index)")
        guard clear.count == size else { throw VaultFailure.damaged }
        let sealed = try VaultCryptography.seal(
          clear, key: key, keyID: lease.keyID,
          id: id, role: "video-chunk/\(index)")
        try lease.check()
        try await repository.appendVideoChunk(id: id, index: index, encrypted: sealed, lease: lease)
      }
      guard (try input.read(upToCount: 1))?.isEmpty != false else { throw VaultFailure.damaged }
      try lease.check()
      try Task.checkCancellation()
      try await repository.finishVideo(
        id: id, replacing: sourceID, expectedMetadata: expectedMetadata, lease: lease)
    } catch {
      try? await repository.cancelVideo(id: id, lease: lease)
      throw error
    }
  }
}
