import Foundation

// A synthetic compatibility probe, deliberately distinct from a full Sport backup.
public struct BackupProbeEnvelope: Sendable {
  public static let maximumBytes = 65_600
  public static let rounds: UInt32 = 600_000
  public let header: Data
  public let salt: Data
  public let sealed: Data
  private static let magic = Array("SPORTP01".utf8)
  public init(data: Data) throws {
    guard (65...Self.maximumBytes).contains(data.count) else { throw BackupProbeFailure.invalid }
    let bytes = Array(data.prefix(36))
    guard Array(bytes.prefix(8)) == Self.magic, Self.integer(bytes, at: 8) == 1,
      Self.integer(bytes, at: 12) == Self.rounds,
      Self.integer(bytes, at: 32) == UInt32(data.count - 36)
    else { throw BackupProbeFailure.invalid }
    header = Data(bytes)
    salt = Data(bytes[16..<32])
    sealed = Data(data.dropFirst(36))
  }
  public static func header(salt: Data, sealedCount: Int) throws -> Data {
    guard salt.count == 16, (29...65_564).contains(sealedCount) else {
      throw BackupProbeFailure.invalid
    }
    var value = Data(magic)
    append(1, to: &value)
    append(rounds, to: &value)
    value.append(salt)
    append(UInt32(sealedCount), to: &value)
    return value
  }
  public static func encode(salt: Data, sealed: Data) throws -> Data {
    try header(salt: salt, sealedCount: sealed.count) + sealed
  }
  private static func append(_ value: UInt32, to data: inout Data) {
    for shift in [24, 16, 8, 0] { data.append(UInt8(truncatingIfNeeded: value >> shift)) }
  }
  private static func integer(_ data: [UInt8], at offset: Int) -> UInt32 {
    data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
  }
}

public enum BackupProbeFailure: Error, LocalizedError, Sendable {
  case invalid, password, verification, unavailable
  public var errorDescription: String? {
    switch self {
    case .invalid: "Not a supported Sport test file, or file is too large. Nothing was imported."
    case .password: "Incorrect password or damaged test file. Nothing was imported."
    case .verification: "The encryption check failed. No personal data were accessed."
    case .unavailable: "Unable to prepare the test file. Try again."
    }
  }
}
