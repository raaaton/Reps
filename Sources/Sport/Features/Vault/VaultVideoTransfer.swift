import AVFoundation
import CoreTransferable
import CryptoKit
import Foundation
import ImageIO
import SportCore
import UniformTypeIdentifiers

// The Photos provider owns its clear copy. Sport receives it only inside FileRepresentation.
// The only Sport-owned transfer file contains independently authenticated encrypted chunks.
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
}

struct VaultTransferredVideo: Transferable, Sendable {
  let staging: VaultVideoStaging
  static var transferRepresentation: some TransferRepresentation {
    // Capture when the representation is requested, before provider callbacks hop tasks.
    let authorization = VaultVideoImportContext.lease
    return FileRepresentation(importedContentType: .movie, shouldAttemptToOpenInPlace: false) {
      file in
      guard let lease = authorization else { throw VaultFailure.locked }
      try lease.check()
      let values = try file.file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      guard values.isRegularFile == true, let size = values.fileSize,
        (1...VaultVideoLimits.maximumBytes).contains(size)
      else { throw VaultVideoFailure.tooLarge }
      let ext = file.file.pathExtension.lowercased()
      guard ["mov", "mp4", "m4v"].contains(ext) else { throw VaultVideoFailure.invalid }
      let asset = AVURLAsset(url: file.file)
      let duration = try await asset.load(.duration).seconds
      guard duration.isFinite, duration > 0, duration <= VaultVideoLimits.maximumSeconds else {
        throw VaultVideoFailure.tooLarge
      }
      guard try await asset.load(.isPlayable),
        !(try await asset.loadTracks(withMediaType: .video)).isEmpty
      else { throw VaultVideoFailure.invalid }
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
      var date = Date()
      if let creation = try? await asset.load(.creationDate),
        let string = try? await creation.load(.stringValue),
        let parsed = ISO8601DateFormatter().date(from: string)
      {
        date = min(parsed, Date())
      }
      let staging = try await VaultSilentVideo.stage(
        asset: asset, date: date, thumbnail: thumbnail as Data, check: { try lease.check() })
      var keep = false
      defer { if !keep { try? staging.remove() } }
      try await VaultSilentVideo.validate(staging, source: asset, lease: lease)
      try Task.checkCancellation()
      keep = true
      return VaultTransferredVideo(staging: staging)
    }
  }
}
