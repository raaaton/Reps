import Foundation
import XCTest

@testable import RepsCore

final class VaultVideoTimelineTests: XCTestCase {
  func testRestoresTrimWithoutChangingCompressedMediaOrCodecDescription() throws {
    let original = initialization()
    let result = try VaultVideoTimeline.restore(original, duration: 47.53, mediaStart: 0.338333)
    XCTAssertEqual(read(result, tag: "mvhd", offset: 24, count: 4), 28_518)
    XCTAssertEqual(read(result, tag: "tkhd", offset: 28, count: 4), 28_518)
    XCTAssertEqual(read(result, tag: "elst", offset: 16, count: 8), 28_518)
    XCTAssertEqual(read(result, tag: "elst", offset: 24, count: 8), 203)
    XCTAssertEqual(result.range(of: Data("codec-description".utf8))?.count, 17)
    XCTAssertTrue(result.suffix(12) == original.suffix(12))
  }

  func testTailOnlyTrimHasZeroMediaStartAndExactVisibleDuration() throws {
    let result = try VaultVideoTimeline.restore(initialization(), duration: 3.2, mediaStart: 0)
    XCTAssertEqual(read(result, tag: "elst", offset: 16, count: 8), 1_920)
    XCTAssertEqual(read(result, tag: "elst", offset: 24, count: 8), 0)
  }

  func testRejectsInvalidTimingAndMalformedContainer() {
    for timing in [Double.nan, .infinity, -1, 0] {
      XCTAssertThrowsError(
        try VaultVideoTimeline.restore(initialization(), duration: timing, mediaStart: 0))
    }
    XCTAssertThrowsError(
      try VaultVideoTimeline.restore(initialization(), duration: 4, mediaStart: -0.1))
    XCTAssertThrowsError(
      try VaultVideoTimeline.restore(Data([0, 0, 0, 255]), duration: 4, mediaStart: 0))
    XCTAssertThrowsError(
      try VaultVideoTimeline.restore(box("ftyp", Data()), duration: 4, mediaStart: 0))
  }

  func testReplacingAnEditDoesNotAccumulateEditLists() throws {
    let first = try VaultVideoTimeline.restore(initialization(), duration: 4, mediaStart: 0.3)
    let second = try VaultVideoTimeline.restore(first, duration: 2, mediaStart: 0.5)
    XCTAssertEqual(first.count, second.count)
    XCTAssertEqual(read(second, tag: "elst", offset: 24, count: 8), 300)
  }

  func testVersionOneHeadersUseIndependentMovieAndMediaTimescales() throws {
    let result = try VaultVideoTimeline.restore(
      initialization(version: 1, mediaScale: 60_000), duration: 3.2, mediaStart: 0.338333)
    XCTAssertEqual(read(result, tag: "mvhd", offset: 32, count: 8), 1_920)
    XCTAssertEqual(read(result, tag: "tkhd", offset: 36, count: 8), 1_920)
    XCTAssertEqual(read(result, tag: "elst", offset: 16, count: 8), 1_920)
    XCTAssertEqual(read(result, tag: "elst", offset: 24, count: 8), 20_300)
  }

  private func initialization(version: UInt8 = 0, mediaScale: UInt32 = 600) -> Data {
    var movie = Data(repeating: 0, count: 100)
    movie[0] = version
    let scaleOffset = version == 1 ? 20 : 12
    movie.replaceSubrange(scaleOffset..<(scaleOffset + 4), with: word(600))
    var media = Data(repeating: 0, count: 36)
    media[0] = version
    media.replaceSubrange(scaleOffset..<(scaleOffset + 4), with: word(mediaScale))
    var trackHeader = Data(repeating: 0, count: 100)
    trackHeader[0] = version
    let track =
      box("tkhd", trackHeader)
      + box("mdia", box("mdhd", media) + box("stsd", Data("codec-description".utf8)))
    return box("ftyp", Data()) + box("moov", box("mvhd", movie) + box("trak", track))
      + box("free", Data([1, 2, 3, 4]))
  }

  private func box(_ tag: String, _ payload: Data) -> Data {
    word(UInt32(payload.count + 8)) + Data(tag.utf8) + payload
  }

  private func word(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value.bigEndian) { Data($0) }
  }

  private func read(_ data: Data, tag: String, offset: Int, count: Int) -> UInt64? {
    guard let location = data.range(of: Data(tag.utf8))?.lowerBound else { return nil }
    let start = location - 4 + offset
    return data[start..<(start + count)].reduce(0) { ($0 << 8) | UInt64($1) }
  }
}
