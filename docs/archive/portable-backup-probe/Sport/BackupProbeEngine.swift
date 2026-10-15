import CommonCrypto
import CryptoKit
import Foundation
import Security
import SportCore

// Native crypto proof only. No repository, biometric key or private media dependency.
actor BackupProbeEngine {
  private static let sample = Data("Sport portable encryption probe v1; synthetic data only.".utf8)

  func encrypt(password: String) throws -> Data {
    try Task.checkCancellation()
    var salt = Data(count: 16)
    let status = salt.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
    }
    guard status == errSecSuccess else { throw BackupProbeFailure.unavailable }
    let key = try Self.key(password: password, salt: salt)
    try Task.checkCancellation()
    let header = try BackupProbeEnvelope.header(salt: salt, sealedCount: Self.sample.count + 28)
    guard let sealed = try AES.GCM.seal(Self.sample, using: key, authenticating: header).combined
    else {
      throw BackupProbeFailure.unavailable
    }
    return try BackupProbeEnvelope.encode(salt: salt, sealed: sealed)
  }

  func verify(data: Data, password: String) throws {
    try Task.checkCancellation()
    let envelope = try BackupProbeEnvelope(data: data)
    let key = try Self.key(password: password, salt: envelope.salt)
    try Task.checkCancellation()
    do {
      let plaintext = try AES.GCM.open(
        AES.GCM.SealedBox(combined: envelope.sealed), using: key, authenticating: envelope.header)
      guard plaintext == Self.sample else { throw BackupProbeFailure.password }
    } catch { throw BackupProbeFailure.password }
    try Task.checkCancellation()
  }

  func runChecks() throws {
    try Task.checkCancellation()
    // RFC7914 section11: first32bytes of PBKDF2-HMAC-SHA256(passwd,salt,1,64).
    let vector = try Self.derive(password: "passwd", salt: Data("salt".utf8), rounds: 1)
    let expected =
      [
        0x55, 0xac, 0x04, 0x6e, 0x56, 0xe3, 0x08, 0x9f, 0xec, 0x16, 0x91, 0xc2, 0x25, 0x44, 0xb6,
        0x05, 0xf9, 0x41, 0x85, 0x21, 0x6d, 0xde, 0x04, 0x65, 0xe6, 0x8b, 0x9d, 0x57, 0xc2, 0x0d,
        0xac, 0xbc,
      ] as [UInt8]
    guard vector == Data(expected) else { throw BackupProbeFailure.verification }
    let password = "Sport synthetic test passphrase"
    let one = try encrypt(password: password)
    try verify(data: one, password: password)
    let two = try encrypt(password: password)
    guard one != two else { throw BackupProbeFailure.verification }
    try requireRejection(data: one, password: "Sport wrong synthetic passphrase")
    var changed = one
    changed[changed.count - 1] ^= 1
    try requireRejection(data: changed, password: password)
    // Check AAD authentication independently, without changing the derived key.
    let envelope = try BackupProbeEnvelope(data: one)
    let key = try Self.key(password: password, salt: envelope.salt)
    try Task.checkCancellation()
    do {
      _ = try AES.GCM.open(
        AES.GCM.SealedBox(combined: envelope.sealed), using: key,
        authenticating: Data("different context".utf8))
      throw BackupProbeFailure.verification
    } catch CryptoKitError.authenticationFailure {}
    try Task.checkCancellation()
  }
  private func requireRejection(data: Data, password: String) throws {
    do {
      try verify(data: data, password: password)
      throw BackupProbeFailure.verification
    } catch BackupProbeFailure.password {}
  }
  private static func key(password: String, salt: Data) throws -> SymmetricKey {
    SymmetricKey(
      data: try derive(password: password, salt: salt, rounds: BackupProbeEnvelope.rounds))
  }
  private static func derive(password: String, salt: Data, rounds: UInt32) throws -> Data {
    let bytes = Data(password.utf8)
    guard (1...1024).contains(bytes.count) else { throw BackupProbeFailure.password }
    var output = Data(count: 32)
    let status = bytes.withUnsafeBytes { passwordBytes in
      salt.withUnsafeBytes { saltBytes in
        output.withUnsafeMutableBytes { derivedBytes in
          CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes.baseAddress!.assumingMemoryBound(to: CChar.self),
            bytes.count, saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
            derivedBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
        }
      }
    }
    guard status == kCCSuccess else { throw BackupProbeFailure.unavailable }
    return output
  }
}

extension BackupProbeEngine {
  func read(url: URL) throws -> Data {
    try Task.checkCancellation()
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var data = Data()
    while true {
      try Task.checkCancellation()
      guard
        let part = try handle.read(
          upToCount: min(4096, BackupProbeEnvelope.maximumBytes + 1 - data.count)), !part.isEmpty
      else { break }
      data.append(part)
      guard data.count <= BackupProbeEnvelope.maximumBytes else { throw BackupProbeFailure.invalid }
    }
    _ = try BackupProbeEnvelope(data: data)
    try Task.checkCancellation()
    return data
  }
}
