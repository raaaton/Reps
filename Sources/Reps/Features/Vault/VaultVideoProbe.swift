import AVFoundation
import CoreTransferable
import CryptoKit
import Foundation
import RepsCore
import UniformTypeIdentifiers

@MainActor
enum VaultVideoProbe {
  static var step = "starting"
  static var patchedContainer = false
  static var timelineDiagnostics = ""
  static func run() async throws -> String {
    guard let url = Bundle.module.url(forResource: "VaultVideoProbe", withExtension: "mp4") else {
      throw VaultFailure.damaged
    }
    guard
      let audioURL = Bundle.module.url(forResource: "VaultVideoAudioProbe", withExtension: "mp4")
    else { throw VaultFailure.damaged }
    step = "trimmed synthetic video timeline"
    if patchedContainer {
      try await verifyPatchedTimeline()
    } else {
      try await verifyTrimmedTimeline()
    }
    step = "provider transfer authorization"
    let provider = NSItemProvider()
    provider.registerFileRepresentation(
      forTypeIdentifier: UTType.mpeg4Movie.identifier,
      fileOptions: [], visibility: .all
    ) { completion in
      completion(audioURL, false, nil)
      return nil
    }
    let importLease = VaultLease(keyID: UUID().uuidString)
    let transferred: VaultTransferredVideo = try await VaultVideoImportContext.$lease.withValue(
      importLease
    ) {
      try await withCheckedThrowingContinuation { continuation in
        _ = provider.loadTransferable(type: VaultTransferredVideo.self) { result in
          continuation.resume(with: result)
        }
      }
    }
    defer {
      importLease.invalidate()
      try? transferred.staging.remove()
    }
    let source = AVURLAsset(url: audioURL)
    guard try await source.loadTracks(withMediaType: .audio).count == 1 else {
      throw VaultFailure.damaged
    }
    step = "provider remux"
    let silent = try await VaultSilentVideo.stage(asset: source, date: Date(), thumbnail: Data())
    let silentLease = VaultLease(keyID: silent.keyID)
    let silentReader = VaultVideoReader(staging: silent, lease: silentLease)
    let silentPlayback = VaultVideoPlayback(
      reader: silentReader, byteCount: silent.byteCount, type: silent.type)
    defer {
      silentPlayback.stop()
      silentLease.invalidate()
      try? silent.remove()
    }
    step = "silent tracks and duration"
    guard try await silentPlayback.asset.loadTracks(withMediaType: .audio).isEmpty,
      try await silentPlayback.asset.loadTracks(withMediaType: .video).count == 1,
      abs((try await silentPlayback.asset.load(.duration)).seconds - 4) < 0.1
    else { throw VaultFailure.damaged }
    step = "candidate validation"
    try await VaultSilentVideo.validate(silent, source: source, lease: silentLease)
    // Also remux an existing encrypted asset through the exact resource loader.
    step = "encrypted remux"
    let repeated = try await VaultSilentVideo.stage(
      asset: silentPlayback.asset, date: Date(), thumbnail: Data(),
      check: { try silentLease.check() })
    defer { try? repeated.remove() }
    step = "encrypted candidate validation"
    try await VaultSilentVideo.validate(repeated, source: silentPlayback.asset, lease: silentLease)
    // Public, generated test pattern only. No training repository, private key or Photos access.
    step = "encrypted playback"
    let bytes = try Data(contentsOf: url)
    let lease = VaultLease(keyID: UUID().uuidString)
    let key = SymmetricKey(size: .bits256)
    let reader = try VaultVideoReader(sample: bytes, key: key, lease: lease)
    let last = try await reader.read(index: 1)
    guard last == bytes.suffix(bytes.count - VaultVideoLimits.chunkBytes) else {
      throw VaultFailure.damaged
    }
    let encrypted = try VaultCryptography.seal(
      Data("synthetic".utf8), key: key,
      keyID: lease.keyID, id: "probe", role: "video-chunk/0")
    var altered = encrypted
    altered[altered.count - 1] ^= 1
    for (data, role) in [(altered, "video-chunk/0"), (encrypted, "video-chunk/1")] {
      do {
        _ = try VaultCryptography.open(data, key: key, keyID: lease.keyID, id: "probe", role: role)
        throw VaultVideoFailure.invalid
      } catch VaultFailure.damaged {}
    }
    let first = VaultVideoPlayback(reader: reader, byteCount: bytes.count, type: "public.mpeg-4")
    let secondReader = try VaultVideoReader(sample: bytes, key: key, lease: lease)
    let second = VaultVideoPlayback(
      reader: secondReader, byteCount: bytes.count, type: "public.mpeg-4")
    defer {
      first.stop()
      second.stop()
      lease.invalidate()
    }
    for playback in [first, second] {
      let duration = try await playback.asset.load(.duration)
      guard duration.seconds > 3.5 else { throw VaultFailure.damaged }
      for _ in 0..<100 {
        if playback.player.currentItem?.status == .readyToPlay { break }
        if playback.failed { throw VaultFailure.damaged }
        try await Task.sleep(for: .milliseconds(100))
      }
      guard playback.player.currentItem?.status == .readyToPlay else { throw VaultFailure.damaged }
      let sought = await playback.player.seek(
        to: CMTime(seconds: 2, preferredTimescale: 600), toleranceBefore: .zero,
        toleranceAfter: .zero)
      guard sought else { throw VaultFailure.damaged }
      playback.player.isMuted = true
      playback.player.playImmediately(atRate: 0.5)
    }
    try await Task.sleep(for: .seconds(1))
    guard first.player.currentTime().seconds > 2.2, second.player.currentTime().seconds > 2.2 else {
      throw VaultFailure.damaged
    }
    step = "paired transport"
    let pair = VaultVideoPairController(first: first, second: second)
    defer { pair.close() }
    await pair.seek(first, to: 0.5)
    await pair.seek(second, to: 1)
    pair.speed = 0.5
    pair.playBoth(firstDuration: 4, secondDuration: 4)
    for _ in 0..<200 {
      if !pair.preparing { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    guard pair.message == nil else { throw VaultFailure.damaged }
    try await Task.sleep(for: .seconds(1))
    step = "paired alignment"
    let delta = second.player.currentTime().seconds - first.player.currentTime().seconds
    guard first.player.currentTime().seconds > 0.7, abs(delta - 0.5) < 0.06 else {
      throw VaultFailure.damaged
    }
    pair.pause()
    step = "quarter speed alignment"
    pair.speed = 0.25
    pair.playBoth(firstDuration: 4, secondDuration: 4)
    for _ in 0..<200 {
      if !pair.preparing { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    guard !pair.preparing, pair.message == nil else { throw VaultFailure.damaged }
    try await Task.sleep(for: .milliseconds(800))
    guard abs(second.player.currentTime().seconds - first.player.currentTime().seconds - 0.5) < 0.06
    else { throw VaultFailure.damaged }
    pair.pause()
    step = "common end and restart"
    await pair.seek(first, to: 3.5)
    await pair.seek(second, to: 3)
    pair.speed = 1
    pair.playBoth(firstDuration: 4, secondDuration: 4)
    for _ in 0..<200 {
      if !pair.preparing { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    try await Task.sleep(for: .seconds(1))
    guard first.player.rate == 0, second.player.rate == 0,
      abs(first.player.currentTime().seconds - 4) < 0.1,
      abs(second.player.currentTime().seconds - 3.5) < 0.1
    else { throw VaultFailure.damaged }
    step = "independent simultaneous playback"
    pair.linked = false
    await pair.seek(first, to: 0)
    await pair.seek(second, to: 0)
    pair.play(first)
    pair.play(second)
    try await Task.sleep(for: .milliseconds(600))
    guard first.player.currentTime().seconds > 0.2, second.player.currentTime().seconds > 0.2 else {
      throw VaultFailure.damaged
    }
    pair.pause()
    step = "inactive preparation cancellation"
    pair.linked = true
    pair.playBoth(firstDuration: 4, secondDuration: 4)
    first.cover()
    second.cover()
    first.foreground()
    second.foreground()
    try await Task.sleep(for: .milliseconds(500))
    guard first.player.rate == 0, second.player.rate == 0 else { throw VaultFailure.damaged }
    pair.pause()
    lease.invalidate()
    do {
      _ = try await reader.read(index: 0)
      throw VaultVideoFailure.invalid
    } catch VaultFailure.locked {}
    return
      "PASS: actual aligned pair transport, validated silent passthrough from provider and encrypted asset, native AES-GCM, altered/reordered chunks rejected, two encrypted players, precise seek, slow playback and revoked session."
  }
}

extension VaultVideoProbe {
  // Reproduce an edit that starts between keyframes, leaving compressed decoding
  // preroll outside the visible selection. This never reads a private asset.
  static func verifyTrimmedTimeline() async throws {
    for name in ["VaultVideoTrimmedProbe", "VaultVideoTrimmedBFrameProbe"] {
      step = "trimmed synthetic timeline: \(name)"
      try await verifyTrimmedAsset(name)
    }
  }

  static func verifyTrimmedAsset(_ name: String) async throws {
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: "mp4")
    else { throw VaultVideoFailure.invalid }
    let source = AVURLAsset(
      url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    if let track = try await source.loadTracks(withMediaType: .video).first {
      let inspection = try AVAssetReader(asset: source)
      let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
      inspection.add(output)
      guard inspection.startReading() else { throw VaultVideoFailure.invalid }
      while let sample = output.copyNextSampleBuffer() {
        if CMSampleBufferGetNumSamples(sample) == 0 { continue }
        timelineDiagnostics =
          "first PTS=\(CMSampleBufferGetPresentationTimeStamp(sample).seconds), output PTS=\(CMSampleBufferGetOutputPresentationTimeStamp(sample).seconds), DTS=\(CMSampleBufferGetDecodeTimeStamp(sample).seconds)"
        break
      }
      inspection.cancelReading()
      for segment in try await track.load(.segments) {
        let mapping = segment.timeMapping
        timelineDiagnostics +=
          " | edit source=\(mapping.source.start.seconds)/\(mapping.source.duration.seconds), target=\(mapping.target.start.seconds)/\(mapping.target.duration.seconds)"
      }
    }
    let staging = try await VaultSilentVideo.stage(
      asset: source, date: Date(), thumbnail: Data())
    let lease = VaultLease(keyID: staging.keyID)
    defer {
      lease.invalidate()
      try? staging.remove()
    }
    // Fixed bundled synthetic input only. Export its small prepared output for
    // container/timestamp inspection without ever opening the private vault.
    guard staging.byteCount < 4 * 1024 * 1024 else { throw VaultVideoFailure.invalid }
    let reader = VaultVideoReader(staging: staging, lease: lease)
    var bytes = Data()
    for index
      in 0..<((staging.byteCount + VaultVideoLimits.chunkBytes - 1) / VaultVideoLimits.chunkBytes)
    {
      bytes.append(try await reader.read(index: index))
    }
    let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("RepsSyntheticTrimmedOutput.mp4")
    try bytes.write(to: output, options: .atomic)
    await reader.close()
    try await VaultSilentVideo.validate(staging, source: source, lease: lease)
    try await verifyFrames(sourceURL: url, candidateURL: output)
  }

  static func verifyPatchedTimeline() async throws {
    guard
      let sourceURL = Bundle.module.url(forResource: "VaultVideoTrimmedProbe", withExtension: "mp4")
    else { throw VaultVideoFailure.invalid }
    let candidateURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("RepsSyntheticPatchedTrim.mp4")
    let source = AVURLAsset(
      url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let candidate = AVURLAsset(
      url: candidateURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let expected = try await source.load(.duration).seconds
    let actual = try await candidate.load(.duration).seconds
    timelineDiagnostics = "patched source=\(expected), candidate=\(actual)"
    guard abs(actual - expected) < 0.02 else { throw VaultVideoFailure.invalid }
    try await verifyFrames(sourceURL: sourceURL, candidateURL: candidateURL)
  }

  static func verifyFrames(sourceURL: URL, candidateURL: URL) async throws {
    let source = AVURLAsset(
      url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let candidate = AVURLAsset(
      url: candidateURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let expected = try await source.load(.duration).seconds
    let originalGenerator = AVAssetImageGenerator(asset: source)
    let candidateGenerator = AVAssetImageGenerator(asset: candidate)
    originalGenerator.appliesPreferredTrackTransform = true
    candidateGenerator.appliesPreferredTrackTransform = true
    originalGenerator.requestedTimeToleranceBefore = .zero
    originalGenerator.requestedTimeToleranceAfter = .zero
    candidateGenerator.requestedTimeToleranceBefore = .zero
    candidateGenerator.requestedTimeToleranceAfter = .zero
    for time in [0.0, expected / 2, max(0, expected - 0.05)] {
      step = "patched synthetic frame at \(time)"
      let point = CMTime(seconds: time, preferredTimescale: 60_000)
      let first = try await originalGenerator.image(at: point).image
      let second = try await candidateGenerator.image(at: point).image
      guard let firstBytes = first.dataProvider?.data as Data?,
        let secondBytes = second.dataProvider?.data as Data?,
        first.width == second.width, first.height == second.height,
        SHA256.hash(data: firstBytes) == SHA256.hash(data: secondBytes)
      else { throw VaultVideoFailure.invalid }
    }
  }
}

#if DEBUG
  import SwiftUI

  enum VaultVideoProbeLaunch {
    static let requestURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("RepsSyntheticVideoProbeRequest.txt")
    static func readToken() -> String? {
      guard let token = try? String(contentsOf: requestURL, encoding: .utf8),
        token.count <= 100, token.hasPrefix("timeline-")
      else { return nil }
      return token
    }
    static let requestedToken: String? = {
      if let token = readToken() { return token }
      let args = ProcessInfo.processInfo.arguments
      guard args.contains("--vault-video-probe") else { return nil }
      if let index = args.firstIndex(of: "--probe-token"), args.indices.contains(index + 1) {
        return args[index + 1]
      }
      return "timeline-cli-missing"
    }()
    static var enabled: Bool {
      requestedToken != nil || ProcessInfo.processInfo.arguments.contains("--vault-video-probe")
    }
  }

  struct VaultVideoProbeScreen: View {
    @State private var result = "Testing synthetic encrypted video…"
    var body: some View {
      Text(result).padding().task {
        var previous: String?
        while !Task.isCancelled {
          if let token = VaultVideoProbeLaunch.readToken()
            ?? (previous == nil ? VaultVideoProbeLaunch.requestedToken : nil), token != previous
          {
            previous = token
            await execute(token: token)
          }
          do { try await Task.sleep(for: .seconds(1)) } catch { break }
        }
      }
    }
    private func execute(token: String) async {
      VaultVideoProbe.patchedContainer = token.contains("-patched-")
      VaultVideoProbe.timelineDiagnostics = ""
      do { result = try await VaultVideoProbe.run() } catch let diagnostic
        as VaultSilentVideoDiagnostic
      {
        result =
          "FAIL: synthetic \(VaultVideoProbe.step). \(diagnostic.localizedDescription)"
      } catch {
        result = "FAIL: synthetic video validation at \(VaultVideoProbe.step)."
      }
      // Only this fixed synthetic test report is emitted; never private data or native error descriptions.
      let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RepsSyntheticVideoProbeResult.txt")
      let report = [
        "result": result, "run": token,
        "timeline": VaultVideoProbe.timelineDiagnostics,
        "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
      ]
      try? FileManager.default.createDirectory(
        at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
      if let data = try? JSONSerialization.data(withJSONObject: report) {
        try? data.write(to: output, options: .atomic)
      }
      if VaultVideoProbeLaunch.requestedToken != nil {
        try? FileManager.default.removeItem(at: VaultVideoProbeLaunch.requestURL)
      }
      print("REPS_VIDEO_PROBE \(result)")
    }
  }
#endif
