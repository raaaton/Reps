import AVFoundation
import CryptoKit
import Foundation
import RepsCore
import UniformTypeIdentifiers

// AVAssetWriter emits fragmented MP4 into this encrypted sink, never a clear output URL.
// The lock protects delegate callbacks and finalization; no lock spans an await.
private final class VaultVideoSegmentSink: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
  let key = SymmetricKey(size: .bits256)
  let keyID = UUID().uuidString
  let url: URL
  private let lock = NSLock()
  private let handle: FileHandle
  private var pending = Data()
  private var count = 0
  private var failure: (any Error)?
  private let check: @Sendable () throws -> Void
  init(check: @escaping @Sendable () throws -> Void) throws {
    self.check = check
    url = try VaultVideoStaging.folder().appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sealed")
    guard
      FileManager.default.createFile(
        atPath: url.path, contents: nil,
        attributes: [.protectionKey: FileProtectionType.complete])
    else { throw VaultVideoFailure.storage }
    handle = try FileHandle(forWritingTo: url)
  }
  func assetWriter(
    _ writer: AVAssetWriter, didOutputSegmentData data: Data,
    segmentType: AVAssetSegmentType
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard failure == nil else { return }
    do {
      try check()
      guard data.count <= 16 * 1024 * 1024,
        count + pending.count + data.count <= VaultVideoLimits.maximumBytes
      else {
        throw VaultVideoFailure.tooLarge
      }
      var offset = 0
      while offset < data.count {
        try check()
        let length = min(VaultVideoLimits.chunkBytes - pending.count, data.count - offset)
        pending.append(data.subdata(in: offset..<(offset + length)))
        offset += length
        if pending.count == VaultVideoLimits.chunkBytes { try flush() }
      }
    } catch {
      failure = error
      writer.cancelWriting()
    }
  }
  private func flush() throws {
    guard !pending.isEmpty else { return }
    try handle.write(
      contentsOf: VaultCryptography.seal(
        pending, key: key, keyID: keyID,
        id: "transfer", role: "video-chunk/\(count / VaultVideoLimits.chunkBytes)"))
    count += pending.count
    pending.removeAll(keepingCapacity: true)
  }
  func finish() throws -> Int {
    lock.lock()
    defer { lock.unlock() }
    if let failure { throw failure }
    try check()
    try flush()
    try handle.synchronize()
    try handle.close()
    guard count > 0 else { throw VaultVideoFailure.invalid }
    return count
  }
  deinit { try? handle.close() }
}

struct VaultSilentVideoDiagnostic: Error {
  let phase: Int
  let code: Int
}

enum VaultSilentVideo {
  // Passthrough preserves compressed video samples and their transform; audio and other
  // tracks are never supplied to the writer. Unsupported formats fail without a clear fallback.
  static func stage(
    asset: AVAsset, date: Date, thumbnail: Data,
    check: @escaping @Sendable () throws -> Void = {}
  ) async throws -> VaultVideoStaging {
    let duration = try await asset.load(.duration).seconds
    guard duration.isFinite, duration > 0, duration <= VaultVideoLimits.maximumSeconds,
      let track = try await asset.loadTracks(withMediaType: .video).first
    else {
      throw VaultVideoFailure.invalid
    }
    let formats = try await track.load(.formatDescriptions)
    guard let format = formats.first else { throw VaultVideoFailure.invalid }
    let transform = try await track.load(.preferredTransform)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw VaultVideoFailure.invalid }
    reader.add(output)
    let sink = try VaultVideoSegmentSink(check: check)
    var keep = false
    defer { if !keep { try? FileManager.default.removeItem(at: sink.url) } }
    let writer = AVAssetWriter(contentType: .mpeg4Movie)
    writer.delegate = sink
    writer.outputFileTypeProfile = .mpeg4AppleHLS
    writer.preferredOutputSegmentInterval = .indefinite
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: format)
    input.transform = transform
    guard writer.canAdd(input) else { throw VaultVideoFailure.invalid }
    writer.add(input)
    var phase = 0
    do {
      try check()
      guard writer.startWriting(), reader.startReading() else { throw VaultVideoFailure.invalid }
      phase = 1
      var started = false
      var segmentBytes = 0
      while let sample = output.copyNextSampleBuffer() {
        try Task.checkCancellation()
        try check()
        // Passthrough readers also emit marker-only buffers (documented by AVFoundation).
        // They contain no media sample and must not be appended as a video frame.
        if CMSampleBufferGetNumSamples(sample) == 0 { continue }
        let size = CMSampleBufferGetTotalSampleSize(sample)
        let attachments =
          CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
          as? [[CFString: Any]]
        let sync = (attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) != true
        if !started {
          writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
          started = true
        } else if sync, segmentBytes > 0 {
          writer.flushSegment()
          segmentBytes = 0
        }
        // Bound long-GOP segments before AVFoundation accumulates an entire large clip.
        guard size > 0, size <= 8 * 1024 * 1024 - segmentBytes else {
          throw VaultVideoFailure.invalid
        }
        segmentBytes += size
        while !input.isReadyForMoreMediaData {
          try check()
          try Task.checkCancellation()
          guard writer.status == .writing else { throw VaultVideoFailure.invalid }
          try await Task.sleep(for: .milliseconds(2))
        }
        phase = 2
        guard input.append(sample) else { throw VaultVideoFailure.invalid }
      }
      phase = 3
      guard started, reader.status == .completed else { throw VaultVideoFailure.invalid }
      input.markAsFinished()
      phase = 4
      await writer.finishWriting()
      try check()
      guard writer.status == .completed else { throw VaultVideoFailure.invalid }
      phase = 5
      let count = try sink.finish()
      let sealed = try VaultCryptography.seal(
        thumbnail, key: sink.key, keyID: sink.keyID,
        id: "transfer", role: "thumbnail")
      let staging = VaultVideoStaging(
        url: sink.url, key: sink.key, keyID: sink.keyID,
        byteCount: count, duration: duration, type: UTType.mpeg4Movie.identifier,
        date: date, thumbnail: sealed)
      keep = true
      return staging
    } catch {
      let code = (writer.error ?? reader.error).map { ($0 as NSError).code } ?? 0
      reader.cancelReading()
      writer.cancelWriting()
      if error is VaultVideoFailure { throw VaultSilentVideoDiagnostic(phase: phase, code: code) }
      throw error
    }
  }
}

extension VaultSilentVideo {
  @MainActor
  static func validate(_ staging: VaultVideoStaging, source: AVAsset, lease: VaultLease)
    async throws
  {
    let reader = VaultVideoReader(staging: staging, lease: lease)
    let playback = VaultVideoPlayback(
      reader: reader, byteCount: staging.byteCount, type: staging.type)
    defer { playback.stop() }
    try lease.check()
    guard try await playback.asset.loadTracks(withMediaType: .audio).isEmpty,
      let video = try await playback.asset.loadTracks(withMediaType: .video).first,
      let original = try await source.loadTracks(withMediaType: .video).first,
      abs((try await playback.asset.load(.duration)).seconds - staging.duration) < 0.1,
      try await video.load(.preferredTransform) == original.load(.preferredTransform),
      try await video.load(.naturalSize) == original.load(.naturalSize)
    else { throw VaultVideoFailure.invalid }
    for _ in 0..<200 {
      try lease.check()
      try Task.checkCancellation()
      if playback.player.currentItem?.status == .readyToPlay { break }
      guard !playback.failed else { throw VaultVideoFailure.invalid }
      try await Task.sleep(for: .milliseconds(50))
    }
    guard playback.player.currentItem?.status == .readyToPlay,
      await playback.player.seek(
        to: CMTime(seconds: staging.duration / 2, preferredTimescale: 600_000),
        toleranceBefore: .zero, toleranceAfter: .zero)
    else { throw VaultVideoFailure.invalid }
    try lease.check()
    try Task.checkCancellation()
  }
}
