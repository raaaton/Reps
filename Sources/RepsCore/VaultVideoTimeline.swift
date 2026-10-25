import Foundation

/// Restores the visible edit in AVAssetWriter's fragmented MP4 initialization.
/// Media fragments stay byte-for-byte intact, including decoding dependencies.
public enum VaultVideoTimeline {
  public enum Failure: Error { case invalidInitialization }

  public static func restore(_ data: Data, duration: Double, mediaStart: Double) throws -> Data {
    guard duration.isFinite, duration > 0, duration <= 300,
      mediaStart.isFinite, mediaStart >= 0, mediaStart < Double(Int32.max)
    else { throw Failure.invalidInitialization }
    let boxes = try parse(data)
    guard boxes.filter({ $0.tag == "moov" }).count == 1 else {
      throw Failure.invalidInitialization
    }
    var result = Data()
    for box in boxes {
      if box.tag == "moov" {
        result.append(try movie(box.payload, duration: duration, mediaStart: mediaStart))
      } else {
        result.append(box.bytes)
      }
    }
    return result
  }

  private struct Box {
    let tag: String
    let bytes: Data
    var payload: Data { bytes.subdata(in: 8..<bytes.count) }
  }

  private static func parse(_ data: Data) throws -> [Box] {
    var offset = 0
    var boxes: [Box] = []
    while offset < data.count {
      guard data.count - offset >= 8 else { throw Failure.invalidInitialization }
      let size = Int(read(data, at: offset, count: 4))
      // The bounded writer initialization uses ordinary 32-bit box headers.
      guard size >= 8, size <= data.count - offset,
        let tag = String(data: data.subdata(in: (offset + 4)..<(offset + 8)), encoding: .ascii)
      else { throw Failure.invalidInitialization }
      boxes.append(Box(tag: tag, bytes: data.subdata(in: offset..<(offset + size))))
      offset += size
    }
    return boxes
  }

  private static func movie(_ data: Data, duration: Double, mediaStart: Double) throws -> Data {
    let boxes = try parse(data)
    guard let header = boxes.first(where: { $0.tag == "mvhd" }),
      boxes.filter({ $0.tag == "mvhd" }).count == 1,
      boxes.filter({ $0.tag == "trak" }).count == 1
    else { throw Failure.invalidInitialization }
    let scale = try timescale(header.payload)
    let ticks = try scaled(duration, by: scale)
    var result = Data()
    for box in boxes {
      switch box.tag {
      case "mvhd":
        result.append(try settingDuration(box, ticks: ticks, track: false))
      case "trak":
        result.append(try track(box.payload, ticks: ticks, mediaStart: mediaStart))
      default: result.append(box.bytes)
      }
    }
    return makeBox("moov", result)
  }

  private static func track(_ data: Data, ticks: UInt64, mediaStart: Double) throws -> Data {
    let boxes = try parse(data)
    guard let media = boxes.first(where: { $0.tag == "mdia" }),
      let header = try parse(media.payload).first(where: { $0.tag == "mdhd" }),
      boxes.filter({ $0.tag == "tkhd" }).count == 1
    else { throw Failure.invalidInitialization }
    let start = try scaled(mediaStart, by: timescale(header.payload))
    guard start <= UInt64(Int64.max) else { throw Failure.invalidInitialization }
    var result = Data()
    for box in boxes where box.tag != "edts" {
      result.append(
        box.tag == "tkhd" ? try settingDuration(box, ticks: ticks, track: true) : box.bytes)
    }
    // Version 1 uses 64-bit movie duration and signed media time. Playback starts
    // at mediaStart while earlier compressed samples remain available to decode.
    let edit =
      Data([1, 0, 0, 0]) + integer(1, count: 4)
      + integer(ticks, count: 8) + integer(start, count: 8) + Data([0, 1, 0, 0])
    result.append(makeBox("edts", makeBox("elst", edit)))
    return makeBox("trak", result)
  }

  private static func timescale(_ data: Data) throws -> UInt64 {
    guard let version = data.first, version <= 1 else { throw Failure.invalidInitialization }
    let offset = version == 1 ? 20 : 12
    guard data.count >= offset + 4 else { throw Failure.invalidInitialization }
    let scale = read(data, at: offset, count: 4)
    guard scale > 0 else { throw Failure.invalidInitialization }
    return scale
  }

  private static func scaled(_ seconds: Double, by scale: UInt64) throws -> UInt64 {
    let value = (seconds * Double(scale)).rounded()
    guard value.isFinite, value >= 0, value < Double(Int64.max) else {
      throw Failure.invalidInitialization
    }
    return UInt64(value)
  }

  private static func settingDuration(_ box: Box, ticks: UInt64, track: Bool) throws -> Data {
    var data = box.payload
    guard let version = data.first, version <= 1 else { throw Failure.invalidInitialization }
    let offset = (version == 1 ? 24 : 16) + (track ? 4 : 0)
    let count = version == 1 ? 8 : 4
    guard data.count >= offset + count, count == 8 || ticks <= UInt32.max else {
      throw Failure.invalidInitialization
    }
    data.replaceSubrange(offset..<(offset + count), with: integer(ticks, count: count))
    return makeBox(box.tag, data)
  }

  private static func read(_ data: Data, at offset: Int, count: Int) -> UInt64 {
    data[offset..<(offset + count)].reduce(0) { ($0 << 8) | UInt64($1) }
  }

  private static func integer(_ value: UInt64, count: Int) -> Data {
    Data((0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
  }

  private static func makeBox(_ tag: String, _ payload: Data) -> Data {
    integer(UInt64(payload.count + 8), count: 4) + Data(tag.utf8) + payload
  }
}
