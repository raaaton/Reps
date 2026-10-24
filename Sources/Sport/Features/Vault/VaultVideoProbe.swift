import AVFoundation
import CryptoKit
import Foundation
import SportCore

@MainActor
enum VaultVideoProbe {
  static func run() async throws -> String {
    guard let url = Bundle.module.url(forResource: "VaultVideoProbe", withExtension: "mp4") else {
      throw VaultFailure.damaged
    }
    // Public, generated test pattern only. No training repository, private key or Photos access.
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
    lease.invalidate()
    do {
      _ = try await reader.read(index: 0)
      throw VaultVideoFailure.invalid
    } catch VaultFailure.locked {}
    return
      "PASS: native AES-GCM, altered/reordered chunks rejected, two encrypted players, precise seek, slow playback and revoked session."
  }
}

#if DEBUG
  import SwiftUI

  struct VaultVideoProbeScreen: View {
    @State private var result = "Testing synthetic encrypted video…"
    var body: some View {
      Text(result).padding().task {
        do { result = try await VaultVideoProbe.run() } catch {
          result = "FAIL: synthetic video validation."
        }
        // Only this fixed synthetic test report is emitted; never private data or native error descriptions.
        let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("SportSyntheticVideoProbeResult.txt")
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
        print("SPORT_VIDEO_PROBE \(result)")
      }
    }
  }
#endif
