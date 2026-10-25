import AVFoundation
import CoreTransferable
import CryptoKit
import Foundation
import RepsCore
import UniformTypeIdentifiers

@MainActor
enum VaultVideoProbe {
  static var step = "starting"
  static func run() async throws -> String {
    guard let url = Bundle.module.url(forResource: "VaultVideoProbe", withExtension: "mp4") else {
      throw VaultFailure.damaged
    }
    guard
      let audioURL = Bundle.module.url(forResource: "VaultVideoAudioProbe", withExtension: "mp4")
    else { throw VaultFailure.damaged }
    step = "trimmed synthetic video timeline"
    try await verifyTrimmedTimeline()
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
    guard
      let url = Bundle.module.url(
        forResource: "VaultVideoTrimmedProbe", withExtension: "mp4")
    else { throw VaultVideoFailure.invalid }
    let source = AVURLAsset(
      url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let staging = try await VaultSilentVideo.stage(
      asset: source, date: Date(), thumbnail: Data())
    let lease = VaultLease(keyID: staging.keyID)
    defer {
      lease.invalidate()
      try? staging.remove()
    }
    try await VaultSilentVideo.validate(staging, source: source, lease: lease)
  }
}

#if DEBUG
  import SwiftUI

  struct VaultVideoProbeScreen: View {
    @State private var result = "Testing synthetic encrypted video…"
    var body: some View {
      Text(result).padding().task {
        do { result = try await VaultVideoProbe.run() } catch let diagnostic
          as VaultSilentVideoDiagnostic
        {
          result =
            "FAIL: synthetic \(VaultVideoProbe.step), phase \(diagnostic.phase), code \(diagnostic.code)."
        } catch {
          result = "FAIL: synthetic video validation at \(VaultVideoProbe.step)."
        }
        // Only this fixed synthetic test report is emitted; never private data or native error descriptions.
        let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("RepsSyntheticVideoProbeResult.txt")
        let arguments = ProcessInfo.processInfo.arguments
        let tokenIndex = arguments.firstIndex(of: "--probe-token")
        let token =
          tokenIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
          ?? "missing"
        let report = [
          "result": result, "run": token,
          "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
        ]
        try? FileManager.default.createDirectory(
          at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: report) {
          try? data.write(to: output, options: .atomic)
        }
        print("REPS_VIDEO_PROBE \(result)")
      }
    }
  }
#endif
