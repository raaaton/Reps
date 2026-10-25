import AVFoundation
import CoreTransferable
import CryptoKit
import Foundation
import ImageIO
import OSLog
import RepsCore
import UniformTypeIdentifiers

// The Photos provider owns its clear copy. Reps receives it only inside FileRepresentation.
// The only Reps-owned transfer file contains independently authenticated encrypted chunks.
final class VaultVideoStaging: Sendable {
  let url: URL
  let key: SymmetricKey
  let keyID: String
  let byteCount: Int
  let duration: Double
  let type: String
  let date: Date
  let thumbnail: Data
  init(
    url: URL, key: SymmetricKey, keyID: String, byteCount: Int, duration: Double,
    type: String, date: Date, thumbnail: Data
  ) {
    self.url = url
    self.key = key
    self.keyID = keyID
    self.byteCount = byteCount
    self.duration = duration
    self.type = type
    self.date = date
    self.thumbnail = thumbnail
  }
  func remove() throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
  deinit { try? remove() }
  static func folder() throws -> URL {
    var folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SportEncryptedVideoImports-v1", isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)
    return folder
  }
  // Called once when the vault store is created, before any import can start.
  static func removeAbandoned() throws {
    let folder = try folder()
    for file in try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil)
    {
      if file.pathExtension == "sealed",
        UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil
      {
        try FileManager.default.removeItem(at: file)
      }
    }
  }
}

enum VaultVideoImportContext {
  @TaskLocal static var lease: VaultLease?
  @TaskLocal static var diagnostics: VaultVideoImportDiagnostics?
}

struct VaultTransferredVideo: Transferable, Sendable {
  let staging: VaultVideoStaging
  static var transferRepresentation: some TransferRepresentation {
    // Capture when the representation is requested, before provider callbacks hop tasks.
    let authorization = VaultVideoImportContext.lease
    let diagnostics = VaultVideoImportContext.diagnostics
    return FileRepresentation(importedContentType: .movie, shouldAttemptToOpenInPlace: false) {
      file in
      var phase = 0
      do {
        guard let lease = authorization else { throw VaultFailure.locked }
        try lease.check()
        phase = 1
        let values = try file.file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize,
          (1...VaultVideoLimits.maximumBytes).contains(size)
        else { throw VaultVideoFailure.tooLarge }
        let ext = file.file.pathExtension.lowercased()
        guard ["mov", "mp4", "m4v"].contains(ext) else { throw VaultVideoFailure.invalid }
        let asset = AVURLAsset(
          url: file.file, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        phase = 2
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= VaultVideoLimits.maximumSeconds else {
          throw VaultVideoFailure.tooLarge
        }
        phase = 3
        guard try await asset.load(.isPlayable),
          !(try await asset.loadTracks(withMediaType: .video)).isEmpty
        else { throw VaultVideoFailure.invalid }
        phase = 4
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 500, height: 500)
        let generated = try await generator.image(at: .zero)
        let thumbnail = NSMutableData()
        guard
          let destination = CGImageDestinationCreateWithData(
            thumbnail, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw VaultVideoFailure.invalid }
        CGImageDestinationAddImage(
          destination, generated.image,
          [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination), thumbnail.length <= 1024 * 1024 else {
          throw VaultVideoFailure.invalid
        }
        phase = 5
        var date = Date()
        if let creation = try? await asset.load(.creationDate),
          let string = try? await creation.load(.stringValue),
          let parsed = ISO8601DateFormatter().date(from: string)
        {
          date = min(parsed, Date())
        }
        phase = 6
        let staging = try await VaultSilentVideo.stage(
          asset: asset, date: date, thumbnail: thumbnail as Data, check: { try lease.check() })
        var keep = false
        defer { if !keep { try? staging.remove() } }
        phase = 7
        try await VaultSilentVideo.validate(staging, source: asset, lease: lease)
        try Task.checkCancellation()
        keep = true
        return VaultTransferredVideo(staging: staging)
      } catch {
        await diagnostics?.record(VaultVideoImportError.describe(error, phase: phase))
        // Only pipeline identifiers and numeric codes; no media or error descriptions.
        let failure = error as NSError
        Logger(subsystem: "com.raaaton.sport", category: "VideoImport").error(
          "Video transfer failed: phase \(phase), domain \(failure.domain, privacy: .public), code \(failure.code)"
        )
        if let diagnostic = error as? VaultSilentVideoDiagnostic {
          Logger(subsystem: "com.raaaton.sport", category: "VideoImport").error(
            "Video preparation failed: phase \(diagnostic.phase), media code \(diagnostic.code)")
        }
        throw error
      }
    }
  }
}
