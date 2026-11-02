import CommonCrypto
import CryptoKit
import Foundation
import RepsCore
import Security

struct PortableBackupAccess: Sendable {
  let key: SymmetricKey
  let lease: VaultLease
  let path: String
  let stamp: VaultBackupStamp
  func check() throws {
    try Task.checkCancellation()
    try lease.check()
  }
}
struct PortableBackupContents: Sendable {
  let archive: TrainingArchive
  let inventory: VaultBackupInventory
}
private struct PortableBackupEnd: Codable {
  let records: Int
  let inventory: VaultBackupInventory
}

actor PortableBackupEngine {
  static func derive(password: String, salt: Data, rounds: UInt32 = PortableBackupHeader.rounds)
    throws -> SymmetricKey
  {
    let bytes = Data(password.utf8)
    guard (1...1024).contains(bytes.count), salt.count > 0 else {
      throw PortableBackupFailure.password
    }
    var output = Data(count: 32)
    let status = bytes.withUnsafeBytes { pass in
      salt.withUnsafeBytes { saltBytes in
        output.withUnsafeMutableBytes { derived in
          CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), pass.baseAddress!.assumingMemoryBound(to: CChar.self),
            bytes.count,
            saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
            derived.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
        }
      }
    }
    guard status == kCCSuccess else { throw PortableBackupFailure.invalid }
    return SymmetricKey(data: output)
  }
  private static func random(_ count: Int) throws -> Data {
    var value = Data(count: count)
    guard
      value.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
      ) == errSecSuccess
    else { throw PortableBackupFailure.invalid }
    return value
  }
  func export(
    archive: TrainingArchive, snapshot: URL, access: PortableBackupAccess, password: String,
    output: URL
  ) throws {
    try access.check()
    let file = try VaultBackupFile(path: snapshot.path)
    try file.validate()
    let sourceID = try file.keyID()
    guard sourceID == access.lease.keyID else { throw PortableBackupFailure.invalid }
    let salt = try Self.random(16)
    let wrappingKey = try Self.derive(password: password, salt: salt)
    try access.check()
    let archiveKey = SymmetricKey(size: .bits256)
    let prefix = try PortableBackupHeader(salt: salt, wrappedKey: Data(repeating: 0, count: 60))
      .authenticatedPrefix
    guard
      let wrapped = try AES.GCM.seal(
        archiveKey.withUnsafeBytes { Data($0) }, using: wrappingKey, authenticating: prefix
      ).combined
    else { throw PortableBackupFailure.invalid }
    let header = try PortableBackupHeader(salt: salt, wrappedKey: wrapped).encoded
    guard
      FileManager.default.createFile(
        atPath: output.path, contents: nil,
        attributes: [.protectionKey: FileProtectionType.complete])
    else { throw PortableBackupFailure.invalid }
    let handle = try FileHandle(forWritingTo: output)
    defer { try? handle.close() }
    try handle.write(contentsOf: header)
    let stream = PortableBackupStream(handle: handle, header: header, key: archiveKey)
    try stream.write(type: 1, data: archive.encoded(), check: access.check)
    var count = 0
    try file.readRecords { encrypted in
      try access.check()
      var record = encrypted
      try record.mapPayloads { data, id, role in
        try VaultCryptography.open(data, key: access.key, keyID: sourceID, id: id, role: role)
      }
      try Self.validateClear(&record)
      try stream.write(type: 2, data: JSONEncoder().encode(record), check: access.check)
      count += 1
    }
    try stream.write(
      type: 0,
      data: JSONEncoder().encode(PortableBackupEnd(records: count, inventory: file.inventory())),
      check: access.check)
    try access.check()
    try handle.synchronize()
  }
  func read(url: URL, password: String, access: PortableBackupAccess, staged: URL) throws
    -> PortableBackupContents
  {
    try access.check()
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let header = try PortableBackupHeader(
      data: PortableBackupStream.readExactly(PortableBackupHeader.size, from: handle))
    let wrappingKey = try Self.derive(password: password, salt: header.salt)
    try access.check()
    let key: SymmetricKey
    do {
      let bytes = try AES.GCM.open(
        AES.GCM.SealedBox(combined: header.wrappedKey), using: wrappingKey,
        authenticating: header.authenticatedPrefix)
      guard bytes.count == 32 else { throw PortableBackupFailure.invalid }
      key = SymmetricKey(data: bytes)
    } catch { throw PortableBackupFailure.password }
    let file = try VaultBackupFile(path: staged.path)
    let verification = try VaultCryptography.seal(
      Data("Sport vault v1".utf8), key: access.key, keyID: access.lease.keyID, id: "vault",
      role: "verification")
    try file.setState(keyID: access.lease.keyID, verification: verification)
    let stream = PortableBackupStream(handle: handle, header: header.encoded, key: key)
    let first = try stream.read(check: access.check)
    guard first.0 == 1 else { throw PortableBackupFailure.invalid }
    let archive = try TrainingArchive.decode(first.1)
    var count = 0
    while true {
      let completed: PortableBackupContents? = try BackupAutoreleasePool.withPool {
        let (type, bytes) = try stream.read(check: access.check)
        if type == 0 {
          let end = try JSONDecoder().decode(PortableBackupEnd.self, from: bytes)
          try file.validate()
          let inventory = try file.inventory()
          guard end.records == count, end.inventory == inventory, !inventory.isEmpty else {
            throw PortableBackupFailure.invalid
          }
          try stream.requireEOF()
          try access.check()
          return PortableBackupContents(archive: archive, inventory: inventory)
        }
        guard type == 2, count < 2_508_000,
          let shape = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
          Set(shape.keys).isSubset(of: [
            "kind", "id", "movementID", "byteCount", "position", "dayKey", "metadata", "original",
            "thumbnail", "payload",
          ])
        else { throw PortableBackupFailure.invalid }
        var record = try JSONDecoder().decode(VaultBackupRecord.self, from: bytes)
        try Self.validateClear(&record)
        try record.mapPayloads { data, id, role in
          try VaultCryptography.seal(
            data, key: access.key, keyID: access.lease.keyID, id: id, role: role)
        }
        try file.append(record)
        _ = try file.inventory()
        count += 1
        return nil
      }
      if let completed { return completed }
    }
  }
  func rekey(source: URL, from: PortableBackupAccess, to: PortableBackupAccess, destination: URL)
    throws
  {
    try from.check()
    try to.check()
    let input = try VaultBackupFile(path: source.path)
    let output = try VaultBackupFile(path: destination.path)
    let verification = try VaultCryptography.seal(
      Data("Sport vault v1".utf8), key: to.key, keyID: to.lease.keyID, id: "vault",
      role: "verification")
    try output.setState(keyID: to.lease.keyID, verification: verification)
    try input.readRecords { encrypted in
      try from.check()
      try to.check()
      var record = encrypted
      try record.mapPayloads { data, id, role in
        let clear = try VaultCryptography.open(
          data, key: from.key, keyID: from.lease.keyID, id: id, role: role)
        return try VaultCryptography.seal(
          clear, key: to.key, keyID: to.lease.keyID, id: id, role: role)
      }
      try output.append(record)
    }
    try output.validate()
    try from.check()
    try to.check()
  }
  private static func validateClear(_ r: inout VaultBackupRecord) throws {
    guard UUID(uuidString: r.id) != nil else { throw PortableBackupFailure.invalid }
    switch r.kind {
    case .movement:
      guard let data = r.metadata else { throw PortableBackupFailure.invalid }
      try JSONDecoder().decode(VaultMovementMetadata.self, from: data).validate()
    case .photo:
      guard let data = r.metadata, let original = r.original, let thumbnail = r.thumbnail else {
        throw PortableBackupFailure.invalid
      }
      let meta = try JSONDecoder().decode(VaultPhotoMetadata.self, from: data)
      guard meta.dayKey.utf8.count == 10,
        TrainingAnalytics.date(for: meta.dayKey, calendar: Calendar(identifier: .gregorian)) != nil,
        ["public.jpeg", "public.png", "public.heic", "public.heif"].contains(meta.type),
        r.dayKey == nil || r.dayKey == meta.dayKey
      else { throw PortableBackupFailure.invalid }
      _ = try VaultCryptography.imageSource(original)
      _ = try VaultCryptography.imageSource(thumbnail)
      r.dayKey = meta.dayKey
    case .video:
      guard let data = r.metadata, let thumbnail = r.thumbnail else {
        throw PortableBackupFailure.invalid
      }
      let meta = try JSONDecoder().decode(VaultVideoMetadata.self, from: data)
      try meta.validate()
      guard meta.movementID == r.movementID, meta.byteCount == r.byteCount else {
        throw PortableBackupFailure.invalid
      }
      _ = try VaultCryptography.imageSource(thumbnail)
    case .chunk:
      guard let data = r.payload, !data.isEmpty, data.count <= VaultVideoLimits.chunkBytes else {
        throw PortableBackupFailure.invalid
      }
    }
  }
}
