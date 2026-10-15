import Foundation
import XCTest

@testable import SportCore

final class BackupProbeEnvelopeTests: XCTestCase {
  private let salt = Data(0..<16)
  private let sealed = Data(repeating: 7, count: 80)

  func testEnvelopeRoundTripPreservesExactHeaderAndBytes() throws {
    let data = try BackupProbeEnvelope.encode(salt: salt, sealed: sealed)
    let parsed = try BackupProbeEnvelope(data: data)
    XCTAssertEqual(parsed.salt, salt)
    XCTAssertEqual(parsed.sealed, sealed)
    XCTAssertEqual(parsed.header, Data(data.prefix(36)))
    XCTAssertEqual(Array(data.prefix(8)), Array("SPORTP01".utf8))
    XCTAssertEqual(Array(data[8..<16]), [0, 0, 0, 1, 0, 9, 39, 192])
  }
  func testUnsupportedFormatVersionAndKDFRejected() throws {
    let original = try BackupProbeEnvelope.encode(salt: salt, sealed: sealed)
    for index in [0, 11, 15] {
      var changed = original
      changed[index] ^= 1
      XCTAssertThrowsError(try BackupProbeEnvelope(data: changed))
    }
  }
  func testEveryTruncationAndTrailingBytesRejected() throws {
    let original = try BackupProbeEnvelope.encode(salt: salt, sealed: sealed)
    for count in 0..<original.count {
      XCTAssertThrowsError(try BackupProbeEnvelope(data: Data(original.prefix(count))))
    }
    XCTAssertThrowsError(try BackupProbeEnvelope(data: original + Data([0])))
  }
  func testOversizedOrInconsistentLengthRejected() throws {
    var data = try BackupProbeEnvelope.encode(salt: salt, sealed: sealed)
    data.replaceSubrange(32..<36, with: [255, 255, 255, 255])
    XCTAssertThrowsError(try BackupProbeEnvelope(data: data))
    XCTAssertThrowsError(try BackupProbeEnvelope(data: Data(repeating: 0, count: 65_601)))
    XCTAssertThrowsError(try BackupProbeEnvelope.encode(salt: Data(count: 15), sealed: sealed))
    XCTAssertThrowsError(try BackupProbeEnvelope.encode(salt: salt, sealed: Data(count: 28)))
    XCTAssertThrowsError(try BackupProbeEnvelope.encode(salt: salt, sealed: Data(count: 65_565)))
  }
  func testMaximumEnvelopeAndSliceWithNonzeroIndicesAccepted() throws {
    let data = try BackupProbeEnvelope.encode(salt: salt, sealed: Data(count: 65_564))
    XCTAssertEqual(data.count, 65_600)
    _ = try BackupProbeEnvelope(data: data)
    let padded = Data([0, 1, 2]) + data
    let slice = padded.dropFirst(3)
    _ = try BackupProbeEnvelope(data: slice)
  }
}
