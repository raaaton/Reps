import Foundation

/// Builds a completed movie index over streaming writer fragments. Only index
/// metadata is retained; compressed media passes through unchanged for sealing.
public struct VaultVideoMovie: Sendable {
  public enum Failure: LocalizedError {
    case invalidFragment, invalidInitialization, limit
    public var errorDescription: String? {
      switch self {
      case .invalidFragment:
        "A compressed video fragment has inconsistent sample timing or byte offsets."
      case .invalidInitialization:
        "The video metadata cannot produce a completed movie index."
      case .limit:
        "The compressed video index exceeds the supported size or sample limits."
      }
    }
  }
  private struct Sample: Sendable {
    let duration: UInt32
    let size: UInt32
    let offset: Int32
    let sync: Bool
  }
  private struct Chunk: Sendable {
    let offset: UInt64
    let count: UInt32
  }
  private var movie: Data?
  private var samples: [Sample] = []
  private var chunks: [Chunk] = []
  private var written: UInt64 = 0
  private var firstDecode: UInt64?
  private var nextDecode: UInt64?
  private var trackID: UInt32 = 0
  private var finished = false
  public init() {}

  public mutating func append(_ data: Data, initialization: Bool) throws -> Data {
    guard !finished, data.count <= 16 * 1024 * 1024,
      written + UInt64(data.count) <= 500 * 1024 * 1024
    else { throw Failure.limit }
    let boxes = try Box.parse(data)
    var result = data
    if initialization {
      guard movie == nil, let header = boxes.first(where: { $0.tag == "moov" }),
        boxes.filter({ $0.tag == "moov" }).count == 1,
        let track = try Box.parse(header.payload).first(where: { $0.tag == "trak" }),
        let trackHeader = try Box.parse(track.payload).first(where: { $0.tag == "tkhd" })
      else { throw Failure.invalidInitialization }
      let version = try number(trackHeader.payload, 0, 1)
      guard version <= 1 else { throw Failure.invalidInitialization }
      trackID = UInt32(try number(trackHeader.payload, version == 1 ? 20 : 12, 4))
      movie = header.bytes
      // Retain layout/byte offsets, but prevent the provisional empty movie
      // from being interpreted instead of the completed index appended last.
      result.replaceSubrange((header.start + 4)..<(header.start + 8), with: Data("free".utf8))
    } else {
      guard movie != nil, let fragment = boxes.first(where: { $0.tag == "moof" }),
        let media = boxes.first(where: { $0.tag == "mdat" }),
        boxes.filter({ $0.tag == "moof" }).count == 1,
        boxes.filter({ $0.tag == "mdat" }).count == 1
      else { throw Failure.invalidFragment }
      try consume(fragment, media: media)
      // Fragment tables must not be interpreted alongside the final flat index.
      // Changing only the box type keeps every compressed byte/offset intact.
      result.replaceSubrange((fragment.start + 4)..<(fragment.start + 8), with: Data("free".utf8))
    }
    written += UInt64(data.count)
    return result
  }

  public mutating func finish() throws -> Data {
    guard !finished, let movie, !samples.isEmpty, firstDecode != nil else {
      throw Failure.invalidInitialization
    }
    let result = try rewrite(movie, tag: "moov")
    guard result.count <= 16 * 1024 * 1024 else { throw Failure.limit }
    finished = true
    return result
  }

  private mutating func consume(_ fragment: Box, media: Box) throws {
    let children = try Box.parse(fragment.payload)
    guard children.filter({ $0.tag == "traf" }).count == 1,
      let track = children.first(where: { $0.tag == "traf" })
    else { throw Failure.invalidFragment }
    let boxes = try Box.parse(track.payload)
    guard let header = boxes.first(where: { $0.tag == "tfhd" }),
      let time = boxes.first(where: { $0.tag == "tfdt" })
    else { throw Failure.invalidFragment }
    var settings = try Cursor(header.payload)
    guard settings.version == 0, try settings.word() == trackID else {
      throw Failure.invalidFragment
    }
    let base =
      settings.flags & 1 != 0 ? try settings.long() : written + UInt64(fragment.start)
    if settings.flags & 2 != 0, try settings.word() != 1 { throw Failure.invalidFragment }
    let duration = settings.flags & 8 != 0 ? try settings.word() : nil
    let size = settings.flags & 16 != 0 ? try settings.word() : nil
    let flags = settings.flags & 32 != 0 ? try settings.word() : 0
    guard settings.flags & 0x010000 == 0, settings.done else { throw Failure.invalidFragment }
    var timing = try Cursor(time.payload)
    guard timing.version <= 1 else { throw Failure.invalidFragment }
    let decode = timing.version == 1 ? try timing.long() : UInt64(try timing.word())
    guard timing.done, nextDecode == nil || nextDecode == decode else {
      throw Failure.invalidFragment
    }
    if firstDecode == nil { firstDecode = decode }
    nextDecode = decode
    let lower = written + UInt64(media.start + 8)
    let upper = written + UInt64(media.start + media.bytes.count)
    var end: UInt64?
    for run in boxes where run.tag == "trun" {
      var cursor = try Cursor(run.payload)
      guard cursor.version <= 1 else { throw Failure.invalidFragment }
      let count = try cursor.word()
      guard count > 0, count <= 100_000, samples.count <= 100_000 - Int(count) else {
        throw Failure.limit
      }
      let start: UInt64
      if cursor.flags & 1 != 0 {
        let displacement = Int64(Int32(bitPattern: try cursor.word()))
        guard base <= 500 * 1024 * 1024, Int64(base) + displacement >= 0 else {
          throw Failure.invalidFragment
        }
        start = UInt64(Int64(base) + displacement)
      } else if let end {
        start = end
      } else {
        throw Failure.invalidFragment
      }
      let firstFlags = cursor.flags & 4 != 0 ? try cursor.word() : flags
      var bytes: UInt64 = 0
      for index in 0..<count {
        guard let sampleDuration = cursor.flags & 0x100 != 0 ? try cursor.word() : duration,
          let sampleSize = cursor.flags & 0x200 != 0 ? try cursor.word() : size,
          sampleSize > 0, sampleSize <= 8 * 1024 * 1024
        else { throw Failure.invalidFragment }
        let sampleFlags =
          cursor.flags & 0x400 != 0 ? try cursor.word() : (index == 0 ? firstFlags : flags)
        let composition = cursor.flags & 0x800 != 0 ? try cursor.word() : 0
        guard cursor.version == 1 || composition <= Int32.max else { throw Failure.invalidFragment }
        samples.append(
          Sample(
            duration: sampleDuration, size: sampleSize,
            offset: Int32(bitPattern: composition), sync: sampleFlags & 0x10000 == 0))
        bytes += UInt64(sampleSize)
        guard let current = nextDecode, current <= UInt64.max - UInt64(sampleDuration) else {
          throw Failure.invalidFragment
        }
        nextDecode = current + UInt64(sampleDuration)
      }
      guard cursor.done, start >= lower, start <= upper, bytes <= upper - start,
        end.map({ start >= $0 }) ?? true
      else { throw Failure.invalidFragment }
      chunks.append(Chunk(offset: start, count: count))
      end = start + bytes
    }
    guard end != nil else { throw Failure.invalidFragment }
  }

  private func rewrite(_ bytes: Data, tag: String) throws -> Data {
    guard let box = try Box.parse(bytes).first else { throw Failure.invalidInitialization }
    var result = Data()
    for child in try Box.parse(box.payload) {
      switch child.tag {
      case "mvex": continue
      case "trak", "mdia", "minf", "edts":
        result.append(try rewrite(child.bytes, tag: child.tag))
      case "stbl": result.append(try sampleTable(child))
      case "mdhd":
        var payload = child.payload
        let version = try number(payload, 0, 1)
        guard version <= 1, let firstDecode, let nextDecode else {
          throw Failure.invalidInitialization
        }
        let offset = version == 1 ? 24 : 16
        let width = version == 1 ? 8 : 4
        guard payload.count >= offset + width, width == 8 || nextDecode - firstDecode <= UInt32.max
        else {
          throw Failure.invalidInitialization
        }
        payload.replaceSubrange(
          offset..<(offset + width), with: integer(nextDecode - firstDecode, width))
        result.append(makeBox(child.tag, payload))
      case "elst":
        var payload = child.payload
        let version = try number(payload, 0, 1)
        guard version <= 1, try number(payload, 4, 4) == 1, let firstDecode else {
          throw Failure.invalidInitialization
        }
        let width = version == 1 ? 8 : 4
        let offset = 8 + width
        let start = try number(payload, offset, width)
        guard start >= firstDecode, start <= Int64.max else { throw Failure.invalidInitialization }
        payload.replaceSubrange(
          offset..<(offset + width), with: integer(start - firstDecode, width))
        result.append(makeBox(child.tag, payload))
      default: result.append(child.bytes)
      }
    }
    return makeBox(tag, result)
  }

  private func sampleTable(_ original: Box) throws -> Data {
    guard let description = try Box.parse(original.payload).first(where: { $0.tag == "stsd" })
    else {
      throw Failure.invalidInitialization
    }
    var result = description.bytes
    result.append(makeBox("stts", pairs(samples.map(\.duration))))
    if samples.contains(where: { $0.offset != 0 }) {
      var composition = pairs(samples.map { UInt32(bitPattern: $0.offset) })
      composition[0] = 1
      result.append(makeBox("ctts", composition))
    }
    var mapping: [UInt64] = []
    var previous: UInt32?
    for (index, chunk) in chunks.enumerated() where chunk.count != previous {
      mapping += [UInt64(index + 1), UInt64(chunk.count), 1]
      previous = chunk.count
    }
    result.append(makeBox("stsc", words([0, UInt64(mapping.count / 3)] + mapping)))
    result.append(
      makeBox("stsz", words([0, 0, UInt64(samples.count)] + samples.map { UInt64($0.size) })))
    var offsets = words([0, UInt64(chunks.count)])
    for chunk in chunks { offsets.append(integer(chunk.offset, 8)) }
    result.append(makeBox("co64", offsets))
    let sync = samples.enumerated().filter { $0.element.sync }.map { UInt64($0.offset + 1) }
    result.append(makeBox("stss", words([0, UInt64(sync.count)] + sync)))
    return makeBox("stbl", result)
  }

  private func pairs(_ values: [UInt32]) -> Data {
    var entries: [UInt64] = []
    var count: UInt64 = 0
    var previous: UInt32?
    for value in values {
      if let previous, previous != value {
        entries += [count, UInt64(previous)]
        count = 0
      }
      count += 1
      previous = value
    }
    if let previous { entries += [count, UInt64(previous)] }
    return words([0, UInt64(entries.count / 2)] + entries)
  }
}

extension VaultVideoMovie {
  private struct Box {
    let start: Int
    let tag: String
    let bytes: Data
    var payload: Data { bytes.subdata(in: 8..<bytes.count) }
    static func parse(_ data: Data) throws -> [Box] {
      var offset = 0
      var result: [Box] = []
      while offset < data.count {
        let size = Int(try number(data, offset, 4))
        guard size >= 8, size <= data.count - offset,
          let tag = String(data: data.subdata(in: (offset + 4)..<(offset + 8)), encoding: .ascii)
        else { throw Failure.invalidFragment }
        result.append(
          Box(start: offset, tag: tag, bytes: data.subdata(in: offset..<(offset + size))))
        offset += size
      }
      return result
    }
  }
  private struct Cursor {
    let data: Data
    let version: UInt8
    let flags: UInt64
    var offset = 4
    var done: Bool { offset == data.count }
    init(_ data: Data) throws {
      let full = try number(data, 0, 4)
      self.data = data
      version = UInt8(full >> 24)
      flags = full & 0xffffff
    }
    mutating func word() throws -> UInt32 {
      defer { offset += 4 }
      return UInt32(try number(data, offset, 4))
    }
    mutating func long() throws -> UInt64 {
      defer { offset += 8 }
      return try number(data, offset, 8)
    }
  }
}

private func number(_ data: Data, _ offset: Int, _ count: Int) throws -> UInt64 {
  guard offset >= 0, offset <= data.count, count <= data.count - offset else {
    throw VaultVideoMovie.Failure.invalidFragment
  }
  return data[offset..<(offset + count)].reduce(0) { ($0 << 8) | UInt64($1) }
}
private func integer(_ value: UInt64, _ count: Int) -> Data {
  Data((0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
}
private func words(_ values: [UInt64]) -> Data {
  var result = Data()
  for value in values { result.append(integer(value, 4)) }
  return result
}
private func makeBox(_ tag: String, _ payload: Data) -> Data {
  integer(UInt64(payload.count + 8), 4) + Data(tag.utf8) + payload
}
