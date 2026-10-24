import CryptoKit
import Foundation
import SportCore

actor VaultVideoReader {
  let id: String
  let byteCount: Int
  private var key: SymmetricKey?
  private let lease: VaultLease
  private let repository: VaultRepository?
  private var synthetic: [Data]?
  private var staging: VaultVideoStaging?

  init(
    id: String, byteCount: Int, key: SymmetricKey, lease: VaultLease, repository: VaultRepository
  ) {
    self.id = id
    self.byteCount = byteCount
    self.key = key
    self.lease = lease
    self.repository = repository
  }
  // Only bundled synthetic video uses this initializer; it cannot access the private vault.
  init(sample: Data, key: SymmetricKey, lease: VaultLease) throws {
    id = UUID().uuidString
    byteCount = sample.count
    self.key = key
    self.lease = lease
    repository = nil
    var chunks: [Data] = []
    for offset in stride(from: 0, to: sample.count, by: VaultVideoLimits.chunkBytes) {
      let index = offset / VaultVideoLimits.chunkBytes
      chunks.append(
        try VaultCryptography.seal(
          sample.subdata(in: offset..<min(sample.count, offset + VaultVideoLimits.chunkBytes)),
          key: key, keyID: lease.keyID, id: id, role: "video-chunk/\(index)"))
    }
    synthetic = chunks
  }
  init(staging: VaultVideoStaging, lease: VaultLease) {
    id = "transfer"
    byteCount = staging.byteCount
    key = staging.key
    self.lease = lease
    repository = nil
    self.staging = staging
  }
  func read(index: Int) async throws -> Data {
    try lease.check()
    try Task.checkCancellation()
    guard let key, index >= 0,
      index < (byteCount + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes
    else { throw VaultFailure.locked }
    let encrypted: Data
    if let repository {
      encrypted = try await repository.videoChunk(id: id, index: index, lease: lease)
    } else if let staging {
      let handle = try FileHandle(forReadingFrom: staging.url)
      defer { try? handle.close() }
      try handle.seek(toOffset: UInt64(index * (VaultVideoLimits.chunkBytes + 28)))
      let length =
        min(VaultVideoLimits.chunkBytes, byteCount - index * VaultVideoLimits.chunkBytes) + 28
      guard let data = try handle.read(upToCount: length), data.count == length else {
        throw VaultFailure.damaged
      }
      encrypted = data
    } else if let synthetic, synthetic.indices.contains(index) {
      encrypted = synthetic[index]
    } else {
      throw VaultFailure.locked
    }
    try lease.check()
    try Task.checkCancellation()
    let expected = min(VaultVideoLimits.chunkBytes, byteCount - index * VaultVideoLimits.chunkBytes)
    guard encrypted.count == expected + 28 else { throw VaultFailure.damaged }
    let bytes = try VaultCryptography.open(
      encrypted, key: key, keyID: staging?.keyID ?? lease.keyID, id: id,
      role: "video-chunk/\(index)")
    try lease.check()
    try Task.checkCancellation()
    guard bytes.count == expected, self.key != nil else { throw VaultFailure.locked }
    return bytes
  }
  func close() {
    key = nil
    synthetic = nil
    staging = nil
  }
}
