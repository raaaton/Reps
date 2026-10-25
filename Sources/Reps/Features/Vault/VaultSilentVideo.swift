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
  private var mediaStart = 0.0
  private let duration: Double
  private let check: @Sendable () throws -> Void
  init(duration: Double, check: @escaping @Sendable () throws -> Void) throws {
    self.duration = duration
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
  func setMediaStart(_ value: Double) {
    lock.lock()
    defer { lock.unlock() }
    mediaStart = value
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
      guard data.count <= 16 * 1024 * 1024 else { throw VaultVideoFailure.tooLarge }
      let data =
        segmentType == .initialization
        ? try VaultVideoTimeline.restore(data, duration: duration, mediaStart: mediaStart) : data
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

struct VaultSilentVideoDiagnostic: LocalizedError {
  let phase: Int
  let code: Int
  var detail: String? = nil

  var errorDescription: String? {
    let stage: String
    switch phase {
    case 0: stage = "Starting video preparation"
    case 1: stage = "Reading compressed video samples"
    case 2: stage = "Writing compressed video samples"
    case 3: stage = "Finishing the source video read"
    case 4: stage = "Finishing the prepared video"
    case 5: stage = "Finishing encrypted storage"
    case 71: stage = "Checking that audio was removed"
    case 72: stage = "Finding the prepared video track"
    case 73: stage = "Finding the source video track"
    case 74: stage = "Checking the prepared video duration"
    case 75: stage = "Checking the video orientation"
    case 76: stage = "Checking the video dimensions"
    case 77: stage = "Preparing video playback"
    case 78: stage = "Waiting for video playback readiness"
    case 79: stage = "Seeking within the prepared video"
    default: stage = "Preparing the video"
    }
    return
      "\(stage) failed.\n\n\(detail.map { $0 + "\n\n" } ?? "")Reference: V\(phase). Code: \(code)."
  }
}

enum VaultSilentVideo {
  // Passthrough preserves compressed video samples and their transform; audio and other
  // tracks are never supplied to the writer. Unsupported formats fail without a clear fallback.
  static func stage(
    asset: AVAsset, date: Date, thumbnail: Data,
    check: @escaping @Sendable () throws -> Void = {}
  ) async throws -> VaultVideoStaging {
    let sourceDuration = try await asset.load(.duration)
    let duration = sourceDuration.seconds
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
    let sink = try VaultVideoSegmentSink(duration: duration, check: check)
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
      guard reader.startReading() else { throw VaultVideoFailure.invalid }
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
          // Compressed buffers retain their original timestamps; the output PTS
          // includes Photos' visible edit. Preserve that mapping in the MP4 edit
          // list instead of exposing the preroll or modifying compressed bytes.
          let mediaStart = CMTimeSubtract(
            CMSampleBufferGetPresentationTimeStamp(sample),
            CMSampleBufferGetOutputPresentationTimeStamp(sample)
          ).seconds
          sink.setMediaStart(mediaStart)
          guard writer.startWriting() else { throw VaultVideoFailure.invalid }
          writer.startSession(atSourceTime: .zero)
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
      // Readers may also emit dependency samples beyond a cropped asset's end.
      // Keep them decodable without extending the visible session to their end.
      writer.endSession(atSourceTime: sourceDuration)
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
    guard try await playback.asset.loadTracks(withMediaType: .audio).isEmpty else {
      throw VaultSilentVideoDiagnostic(phase: 71, code: 0)
    }
    guard let video = try await playback.asset.loadTracks(withMediaType: .video).first else {
      throw VaultSilentVideoDiagnostic(phase: 72, code: 0)
    }
    guard let original = try await source.loadTracks(withMediaType: .video).first else {
      throw VaultSilentVideoDiagnostic(phase: 73, code: 0)
    }
    let outputDuration = try await playback.asset.load(.duration).seconds
    guard abs(outputDuration - staging.duration) < 0.1 else {
      let videoDuration = try await original.load(.timeRange).duration.seconds
      throw VaultSilentVideoDiagnostic(
        phase: 74, code: abs(outputDuration - videoDuration) < 0.1 ? 1 : 0,
        detail: String(
          format:
            "Source duration: %.6f s\nPrepared duration: %.6f s\nSource video track: %.6f s\nDifference: %.6f s\nAllowed difference: less than 0.100000 s",
          locale: Locale(identifier: "en_US_POSIX"),
          staging.duration, outputDuration, videoDuration, abs(outputDuration - staging.duration)))
    }
    guard try await video.load(.preferredTransform) == original.load(.preferredTransform) else {
      throw VaultSilentVideoDiagnostic(phase: 75, code: 0)
    }
    guard try await video.load(.naturalSize) == original.load(.naturalSize) else {
      throw VaultSilentVideoDiagnostic(phase: 76, code: 0)
    }
    for _ in 0..<200 {
      try lease.check()
      try Task.checkCancellation()
      if playback.player.currentItem?.status == .readyToPlay { break }
      guard !playback.failed else { throw VaultSilentVideoDiagnostic(phase: 77, code: 0) }
      try await Task.sleep(for: .milliseconds(50))
    }
    guard playback.player.currentItem?.status == .readyToPlay else {
      throw VaultSilentVideoDiagnostic(phase: 78, code: 0)
    }
    guard
      await playback.player.seek(
        to: CMTime(seconds: staging.duration / 2, preferredTimescale: 600_000),
        toleranceBefore: .zero, toleranceAfter: .zero)
    else { throw VaultSilentVideoDiagnostic(phase: 79, code: 0) }
    try lease.check()
    try Task.checkCancellation()
  }
}
