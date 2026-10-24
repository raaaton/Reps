import CryptoKit
import Foundation
import PhotosUI
import SportCore
import SwiftUI
import UIKit

extension PhotoVaultStore {
  func readVideoState(key: SymmetricKey, lease: VaultLease) async throws -> (
    [VaultMovementEntry], [VaultVideoEntry]
  ) {
    let repo = try database()
    let rows = try await repo.movements(lease: lease)
    let videoRows = try await repo.videoMetadata(lease: lease)
    return try await Task.detached {
      try lease.check()
      let movements = try rows.map { row in
        let bytes = try VaultCryptography.open(
          row.data, key: key, keyID: lease.keyID, id: row.id, role: "movement-metadata")
        let meta = try JSONDecoder().decode(VaultMovementMetadata.self, from: bytes)
        try meta.validate()
        return VaultMovementEntry(id: row.id, metadata: meta)
      }
      let movementIDs = Set(movements.map(\.id))
      let videos = try videoRows.map { row in
        let bytes = try VaultCryptography.open(
          row.metadata, key: key, keyID: lease.keyID, id: row.id, role: "video-metadata")
        let meta = try JSONDecoder().decode(VaultVideoMetadata.self, from: bytes)
        try meta.validate()
        guard meta.movementID == row.movementID, meta.byteCount == row.byteCount,
          movementIDs.contains(meta.movementID)
        else { throw VaultFailure.damaged }
        return VaultVideoEntry(id: row.id, metadata: meta)
      }
      try lease.check()
      return (movements, videos)
    }.value
  }
  func syncVideoMovements(skills: [SkillDefinition], progress: [SkillProgress], session: UUID) async
  {
    guard allows(session), !busy, let lease, let key else { return }
    let following = VaultMovementCollection.following(
      skills, progress: progress, movements: movements)
    let changed = following.filter { entry in movements.first(where: { $0.id == entry.id }) != entry
    }
    guard !changed.isEmpty else { return }
    busy = true
    defer { if allows(session) { busy = false } }
    do {
      for entry in changed {
        try entry.metadata.validate()
        guard allows(session) else { return }
        let bytes = try JSONEncoder().encode(entry.metadata)
        let encrypted = try VaultCryptography.seal(
          bytes, key: key, keyID: lease.keyID, id: entry.id, role: "movement-metadata")
        try await database().saveMovement(id: entry.id, encrypted: encrypted, lease: lease)
        guard allows(session) else { return }
        movements.removeAll { $0.id == entry.id }
        movements.append(entry)
      }
    } catch { if allows(session) { self.error = message(error) } }
  }
  func saveCustomMovement(original: VaultMovementEntry?, name: String, session: UUID) async -> Bool
  {
    guard allows(session), !busy, let lease, let key, original?.metadata.skillID == nil else {
      return false
    }
    busy = true
    defer { if allows(session) { busy = false } }
    do {
      let entry = VaultMovementEntry(
        id: original?.id ?? UUID().uuidString,
        metadata: .init(name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
      try entry.metadata.validate()
      if let original { guard movements.contains(original) else { throw VaultFailure.damaged } }
      let encrypted = try VaultCryptography.seal(
        JSONEncoder().encode(entry.metadata), key: key,
        keyID: lease.keyID, id: entry.id, role: "movement-metadata")
      try await database().saveMovement(id: entry.id, encrypted: encrypted, lease: lease)
      guard allows(session) else { return false }
      movements.removeAll { $0.id == entry.id }
      movements.append(entry)
      return true
    } catch {
      if allows(session) { self.error = message(error) }
      return false
    }
  }
  func deleteVideoMovement(_ entry: VaultMovementEntry, session: UUID) async {
    guard allows(session), !busy, entry.metadata.skillID == nil, movements.contains(entry),
      let lease
    else { return }
    busy = true
    defer { if allows(session) { busy = false } }
    do {
      try await database().deleteMovement(id: entry.id, lease: lease)
      guard allows(session) else { return }
      movements.removeAll { $0.id == entry.id }
      let removed = Set(videos.filter { $0.metadata.movementID == entry.id }.map(\.id))
      videos.removeAll { removed.contains($0.id) }
      for id in removed { videoThumbnails[id] = nil }
    } catch { if allows(session) { self.error = message(error) } }
  }
  func stageVideo(_ item: PhotosPickerItem, session: UUID) async {
    guard allows(session), !busy else { return }
    let request = UUID()
    videoRequest = request
    videoStaging = nil
    busy = true
    error = nil
    defer { if allows(session), videoRequest == request { busy = false } }
    do {
      guard let transferred = try await item.loadTransferable(type: VaultTransferredVideo.self)
      else { throw VaultVideoFailure.invalid }
      guard allows(session), videoRequest == request, !Task.isCancelled else {
        try transferred.staging.remove()
        return
      }
      videoStaging = transferred.staging
    } catch {
      if allows(session), videoRequest == request, !Task.isCancelled { self.error = message(error) }
    }
  }
  func clearVideoImport() {
    videoRequest = UUID()
    do { try videoStaging?.remove() } catch {
      self.error = "The encrypted import file could not be removed. Restart Sport to retry cleanup."
    }
    videoStaging = nil
  }
  func importStagedVideo(movement: VaultMovementEntry, day: Date, session: UUID) async -> Bool {
    guard allows(session), !busy, let lease, let key, let staging = videoStaging,
      movements.contains(where: { $0.id == movement.id })
    else { return false }
    busy = true
    defer { if allows(session) { busy = false } }
    let repo: VaultRepository
    do { repo = try database() } catch {
      self.error = message(error)
      return false
    }
    let id = UUID().uuidString
    let meta = VaultVideoMetadata(
      dayKey: WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000)),
      movementID: movement.id, type: staging.type, duration: staging.duration,
      byteCount: staging.byteCount, importedAt: WorkoutClock.now)
    do {
      try meta.validate()
      try await Task.detached {
        try lease.check()
        let thumbnail = try VaultCryptography.open(
          staging.thumbnail, key: staging.key, keyID: staging.keyID, id: "transfer",
          role: "thumbnail")
        let value = try VaultEncryptedVideo(
          id: id, movementID: movement.id,
          metadata: VaultCryptography.seal(
            JSONEncoder().encode(meta), key: key, keyID: lease.keyID, id: id, role: "video-metadata"
          ),
          thumbnail: VaultCryptography.seal(
            thumbnail, key: key, keyID: lease.keyID, id: id, role: "video-thumbnail"),
          byteCount: staging.byteCount)
        try await repo.beginVideo(value, lease: lease)
        let input = try FileHandle(forReadingFrom: staging.url)
        defer { try? input.close() }
        for offset in stride(from: 0, to: staging.byteCount, by: VaultVideoLimits.chunkBytes) {
          try lease.check()
          try Task.checkCancellation()
          let index = offset / VaultVideoLimits.chunkBytes
          let size = min(VaultVideoLimits.chunkBytes, staging.byteCount - offset)
          guard let encrypted = try input.read(upToCount: size + 28), encrypted.count == size + 28
          else { throw VaultFailure.damaged }
          let clear = try VaultCryptography.open(
            encrypted, key: staging.key, keyID: staging.keyID, id: "transfer",
            role: "video-chunk/\(index)")
          guard clear.count == size else { throw VaultFailure.damaged }
          let sealed = try VaultCryptography.seal(
            clear, key: key, keyID: lease.keyID, id: id, role: "video-chunk/\(index)")
          try lease.check()
          try await repo.appendVideoChunk(id: id, index: index, encrypted: sealed, lease: lease)
        }
        guard (try input.read(upToCount: 1))?.isEmpty != false else { throw VaultFailure.damaged }
        try lease.check()
        try await repo.finishVideo(id: id, lease: lease)
      }.value
      guard allows(session) else { return false }
      videos.append(VaultVideoEntry(id: id, metadata: meta))
      clearVideoImport()
      SportHaptics.shared.play(.success)
      return true
    } catch {
      // Cleanup is allowed only for this session's incomplete import, never another session's rows.
      try? await repo.cancelVideo(id: id, lease: lease)
      if allows(session) { self.error = message(error) }
      return false
    }
  }
  func loadVideoThumbnail(_ entry: VaultVideoEntry, session: UUID) async {
    guard allows(session), let lease, let key, videoThumbnails[entry.id] == nil else { return }
    do {
      let encrypted = try await database().videoThumbnail(id: entry.id, lease: lease)
      guard allows(session), !Task.isCancelled else { return }
      let bytes = try VaultCryptography.open(
        encrypted, key: key, keyID: lease.keyID, id: entry.id, role: "video-thumbnail")
      guard bytes.count <= 1024 * 1024, allows(session), let image = UIImage(data: bytes) else {
        throw VaultFailure.damaged
      }
      if videoThumbnails.count >= 32 { videoThumbnails = [:] }
      videoThumbnails[entry.id] = image
    } catch { if allows(session), !Task.isCancelled { self.error = message(error) } }
  }
  func makeVideoPlayback(_ entry: VaultVideoEntry, session: UUID) throws -> VaultVideoPlayback {
    guard allows(session), let lease, let key, videos.contains(entry) else {
      throw VaultFailure.locked
    }
    let reader = VaultVideoReader(
      id: entry.id, byteCount: entry.metadata.byteCount, key: key, lease: lease,
      repository: try database())
    let playback = VaultVideoPlayback(
      reader: reader, byteCount: entry.metadata.byteCount, type: entry.metadata.type)
    videoPlaybacks[playback.id] = playback
    return playback
  }
  func releaseVideoPlayback(_ playback: VaultVideoPlayback) {
    playback.stop()
    videoPlaybacks[playback.id] = nil
  }
  func changeVideoDate(_ entry: VaultVideoEntry, day: Date, session: UUID) async -> Bool {
    guard allows(session), !busy, let lease, let key, videos.contains(entry) else { return false }
    busy = true
    defer { if allows(session) { busy = false } }
    do {
      var updated = entry
      updated.metadata.dayKey = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000))
      try updated.metadata.validate()
      let encrypted = try VaultCryptography.seal(
        JSONEncoder().encode(updated.metadata), key: key, keyID: lease.keyID, id: entry.id,
        role: "video-metadata")
      try await database().updateVideo(id: entry.id, encrypted: encrypted, lease: lease)
      guard allows(session) else { return false }
      videos = videos.map { $0.id == entry.id ? updated : $0 }
      return true
    } catch {
      if allows(session) { self.error = message(error) }
      return false
    }
  }
  func deleteVideo(_ entry: VaultVideoEntry, session: UUID) async -> Bool {
    guard allows(session), !busy, let lease else { return false }
    busy = true
    defer { if allows(session) { busy = false } }
    do {
      try await database().deleteVideo(id: entry.id, lease: lease)
      guard allows(session) else { return false }
      videos.removeAll { $0.id == entry.id }
      videoThumbnails[entry.id] = nil
      return true
    } catch {
      if allows(session) { self.error = message(error) }
      return false
    }
  }
}
