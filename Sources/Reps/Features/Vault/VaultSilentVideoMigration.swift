import AVFoundation
import CryptoKit
import Foundation
import RepsCore

extension PhotoVaultStore {
  func removeExistingVideoAudio(session: UUID) async {
    guard VaultVideoFeature.silentImportsEnabled, allows(session), !busy,
      let lease, let key
    else { return }
    let remaining = videos.filter { $0.metadata.audioRemoved != true }
    guard !remaining.isEmpty else { return }
    busy = true
    defer {
      if allows(session) {
        busy = false
        notice = nil
      }
    }
    do {
      let repo = try database()
      for (index, entry) in remaining.enumerated() {
        try lease.check()
        try Task.checkCancellation()
        notice = "Removing audio… \(index + 1) of \(remaining.count)"
        guard
          let original = try await repo.videoMetadata(lease: lease).first(where: {
            $0.id == entry.id
          })
        else { throw VaultFailure.damaged }
        let reader = VaultVideoReader(
          id: entry.id, byteCount: entry.metadata.byteCount,
          key: key, lease: lease, repository: repo)
        let playback = VaultVideoPlayback(
          reader: reader, byteCount: entry.metadata.byteCount, type: entry.metadata.type)
        videoPlaybacks[playback.id] = playback
        defer {
          videoPlaybacks[playback.id] = nil
          playback.stop()
        }
        // Always close the old loader before moving to another clip or returning on failure.
        do {
          let thumb = try await repo.videoThumbnail(id: entry.id, lease: lease)
          try lease.check()
          let thumbnail = try VaultCryptography.open(
            thumb, key: key, keyID: lease.keyID,
            id: entry.id, role: "video-thumbnail")
          let staging = try await VaultSilentVideo.stage(
            asset: playback.asset,
            date: VaultDates.date(entry.metadata.dayKey) ?? Date(), thumbnail: thumbnail,
            check: { try lease.check() })
          defer { try? staging.remove() }
          try await VaultSilentVideo.validate(staging, source: playback.asset, lease: lease)
          playback.stop()
          let id = UUID().uuidString
          let metadata = VaultVideoMetadata(
            dayKey: entry.metadata.dayKey,
            movementID: entry.metadata.movementID, type: staging.type, duration: staging.duration,
            byteCount: staging.byteCount, importedAt: entry.metadata.importedAt, audioRemoved: true)
          try await Task.detached {
            try await VaultVideoPersistence.write(
              staging: staging, metadata: metadata, id: id,
              key: key, lease: lease, repository: repo, replacing: entry.id,
              expectedMetadata: original.metadata)
          }.value
          guard allows(session) else { return }
          videos = videos.map {
            $0.id == entry.id ? VaultVideoEntry(id: id, metadata: metadata) : $0
          }
          videoThumbnails[entry.id] = nil
        } catch {
          playback.stop()
          throw error
        }
      }
    } catch {
      if allows(session), !Task.isCancelled {
        self.error =
          "Audio removal could not finish. Unconverted videos are still encrypted and play muted. Free some storage and reopen the vault to retry."
      }
    }
  }
}
