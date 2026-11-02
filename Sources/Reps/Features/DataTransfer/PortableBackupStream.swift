import CryptoKit
import Foundation
import RepsCore

// Every frame authenticates the entire header, its absolute sequence number and size.
// A distinct authenticated terminal record is mandatory; EOF can never mean success.
final class PortableBackupStream {
  private let handle: FileHandle
  private let header: Data
  private let key: SymmetricKey
  private var sequence: UInt64 = 0
  private var total: UInt64 = 0
  init(handle: FileHandle, header: Data, key: SymmetricKey) {
    self.handle = handle
    self.header = header
    self.key = key
  }
  private func integer(_ number: UInt64, bytes: Int) -> Data {
    Data((0..<bytes).reversed().map { UInt8(truncatingIfNeeded: number >> ($0 * 8)) })
  }
  static func readExactly(_ count: Int, from handle: FileHandle) throws -> Data {
    guard count >= 0, count <= PortableBackupHeader.maximumRecordBytes else {
      throw PortableBackupFailure.invalid
    }
    var data = Data()
    while data.count < count {
      guard let part = try handle.read(upToCount: count - data.count), !part.isEmpty else {
        throw PortableBackupFailure.invalid
      }
      data.append(part)
    }
    return data
  }
  private func nonce() throws -> AES.GCM.Nonce {
    try AES.GCM.Nonce(data: Data(repeating: 0, count: 4) + integer(sequence, bytes: 8))
  }
  func write(type: UInt8, data: Data, check: () throws -> Void) throws {
    guard data.count <= PortableBackupHeader.maximumRecordBytes else {
      throw PortableBackupFailure.invalid
    }
    var offset = 0
    repeat {
      try check()
      let end = min(data.count, offset + PortableBackupHeader.blockBytes)
      let plain = Data([type, end == data.count ? 1 : 0]) + data.subdata(in: offset..<end)
      let size = integer(UInt64(plain.count + 28), bytes: 4)
      guard
        let sealed = try AES.GCM.seal(
          plain, using: key, nonce: nonce(),
          authenticating: header + integer(sequence, bytes: 8) + size
        ).combined
      else { throw PortableBackupFailure.invalid }
      try handle.write(contentsOf: size)
      try handle.write(contentsOf: sealed)
      sequence += 1
      offset = end
    } while offset < data.count
  }
  func read(check: () throws -> Void) throws -> (UInt8, Data) {
    var result = Data()
    var recordType: UInt8?
    while true {
      try check()
      let size = try Self.readExactly(4, from: handle)
      let count = size.reduce(0) { $0 * 256 + Int($1) }
      guard (30...(PortableBackupHeader.blockBytes + 30)).contains(count), sequence < 6_000_000
      else { throw PortableBackupFailure.invalid }
      total += UInt64(count + 4)
      guard total <= 5_000_000_000_000 else { throw PortableBackupFailure.invalid }
      let sealed = try Self.readExactly(count, from: handle)
      let plain = try AES.GCM.open(
        AES.GCM.SealedBox(combined: sealed), using: key,
        authenticating: header + integer(sequence, bytes: 8) + size)
      guard sealed.prefix(12) == Data(try nonce()), plain.count >= 2, plain[1] <= 1,
        recordType == nil || recordType == plain[0],
        result.count <= PortableBackupHeader.maximumRecordBytes - (plain.count - 2),
        plain.count > 2 || plain[1] == 1
      else { throw PortableBackupFailure.invalid }
      recordType = plain[0]
      result.append(plain.dropFirst(2))
      sequence += 1
      if plain[1] == 1 { return (plain[0], result) }
    }
  }
  func requireEOF() throws {
    guard (try handle.read(upToCount: 1))?.isEmpty != false else {
      throw PortableBackupFailure.invalid
    }
  }
}
