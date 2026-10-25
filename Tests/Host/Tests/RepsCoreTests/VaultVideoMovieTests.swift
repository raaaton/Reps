import Foundation
import XCTest

@testable import RepsCore

final class VaultVideoMovieTests: XCTestCase {
  func testFinalIndexPreservesMediaAndBoundsEditWithReorderedFrames() throws {
    var movie = VaultVideoMovie()
    let initial = try VaultVideoTimeline.restore(
      initialization(), duration: 0.03, mediaStart: 110.0 / 600)
    let placeholder = try movie.append(initial, initialization: true)
    XCTAssertEqual(placeholder.count, initial.count)
    XCTAssertNil(placeholder.range(of: Data("moov".utf8)))
    let first = fragment(time: 100, duration: 10, sizes: [3, 4], offsets: [20, 0])
    let second = fragment(time: 120, duration: 4, sizes: [5], offsets: [-5], sync: false)
    let firstWritten = try movie.append(first, initialization: false)
    let secondWritten = try movie.append(second, initialization: false)
    XCTAssertEqual(firstWritten.count, first.count)
    XCTAssertEqual(secondWritten.count, second.count)
    XCTAssertNil(firstWritten.range(of: Data("moof".utf8)))
    XCTAssertEqual(firstWritten.suffix(7), first.suffix(7))
    XCTAssertEqual(secondWritten.suffix(5), second.suffix(5))
    let header = try movie.finish()
    XCTAssertNil(header.range(of: Data("mvex".utf8)))
    XCTAssertEqual(read(header, "elst", 24, 8), 10)
    XCTAssertEqual(read(header, "mdhd", 24, 4), 24)
    XCTAssertEqual(read(header, "mvhd", 24, 4), 18)
    XCTAssertEqual(read(header, "stts", 12, 4), 2)
    XCTAssertEqual(read(header, "stts", 16, 4), 2)
    XCTAssertEqual(read(header, "stts", 20, 4), 10)
    XCTAssertEqual(read(header, "stts", 24, 4), 1)
    XCTAssertEqual(read(header, "stts", 28, 4), 4)
    XCTAssertEqual(read(header, "ctts", 36, 4), UInt64(UInt32(bitPattern: -5)))
    XCTAssertEqual(read(header, "stsz", 16, 4), 3)
    XCTAssertEqual(read(header, "stsz", 20, 4), 3)
    XCTAssertEqual(read(header, "stsz", 24, 4), 4)
    XCTAssertEqual(read(header, "stsz", 28, 4), 5)
    XCTAssertEqual(read(header, "stss", 12, 4), 1)
    XCTAssertEqual(read(header, "stss", 16, 4), 1)
    let firstMedia = initial.count + first.range(of: Data("mdat".utf8))!.lowerBound + 4
    XCTAssertEqual(read(header, "co64", 16, 8), UInt64(firstMedia))
    XCTAssertEqual(read(header, "stsc", 12, 4), 2)
    XCTAssertEqual(read(header, "stsc", 20, 4), 2)
    XCTAssertEqual(read(header, "stsc", 32, 4), 1)
  }

  func testRejectsMissingInitializationAndDiscontinuousDecodeTimeline() throws {
    var movie = VaultVideoMovie()
    XCTAssertThrowsError(try movie.finish())
    XCTAssertThrowsError(try movie.append(fragment(time: 0), initialization: false))
    _ = try movie.append(initialization(), initialization: true)
    XCTAssertThrowsError(try movie.append(initialization(), initialization: true))
    _ = try movie.append(fragment(time: 0), initialization: false)
    XCTAssertThrowsError(try movie.append(fragment(time: 99), initialization: false))
  }

  func testRejectsTruncatedFragmentAndOutOfBoundsSampleData() throws {
    var movie = VaultVideoMovie()
    _ = try movie.append(initialization(), initialization: true)
    var damaged = fragment(time: 0)
    damaged.removeLast()
    XCTAssertThrowsError(try movie.append(damaged, initialization: false))
    var other = VaultVideoMovie()
    _ = try other.append(initialization(), initialization: true)
    var wrongOffset = fragment(time: 0)
    let trun = wrongOffset.range(of: Data("trun".utf8))!.lowerBound - 4
    wrongOffset.replaceSubrange((trun + 16)..<(trun + 20), with: word(0))
    XCTAssertThrowsError(try other.append(wrongOffset, initialization: false))
  }

  private func initialization() -> Data {
    var movie = Data(repeating: 0, count: 100)
    movie.replaceSubrange(12..<16, with: word(600))
    var track = Data(repeating: 0, count: 84)
    track.replaceSubrange(12..<16, with: word(1))
    var media = Data(repeating: 0, count: 24)
    media.replaceSubrange(12..<16, with: word(600))
    let table = box("stbl", box("stsd", Data(repeating: 0, count: 8)))
    let content = box("tkhd", track) + box("mdia", box("mdhd", media) + box("minf", table))
    return box("ftyp", Data())
      + box("moov", box("mvhd", movie) + box("trak", content) + box("mvex", Data()))
  }

  private func fragment(
    time: UInt32, duration: UInt32 = 10, sizes: [UInt32] = [3],
    offsets: [Int32] = [0], sync: Bool = true
  ) -> Data {
    let tfhd = box("tfhd", word(0x020028) + word(1) + word(duration) + word(0x10000))
    let tfdt = box("tfdt", word(0) + word(time))
    var entries = Data()
    for (size, offset) in zip(sizes, offsets) {
      entries += word(size) + word(UInt32(bitPattern: offset))
    }
    func moof(_ offset: UInt32) -> Data {
      let run =
        word(0x0100_0a05) + word(UInt32(sizes.count)) + word(offset)
        + word(sync ? 0 : 0x10000) + entries
      return box("moof", box("traf", tfhd + tfdt + box("trun", run)))
    }
    let header = moof(0)
    return moof(UInt32(header.count + 8))
      + box("mdat", Data(repeating: 0xab, count: Int(sizes.reduce(0, +))))
  }

  private func word(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value.bigEndian) { Data($0) }
  }
  private func box(_ tag: String, _ data: Data) -> Data {
    word(UInt32(data.count + 8)) + Data(tag.utf8) + data
  }
  private func read(_ data: Data, _ tag: String, _ offset: Int, _ count: Int) -> UInt64? {
    guard let location = data.range(of: Data(tag.utf8))?.lowerBound else { return nil }
    let start = location - 4 + offset
    guard start >= 0, start + count <= data.count else { return nil }
    return data[start..<(start + count)].reduce(0) { ($0 << 8) | UInt64($1) }
  }
}
