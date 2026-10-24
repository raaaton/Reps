import AVFoundation
import CryptoKit
import Foundation
import LocalAuthentication
import Photos
import PhotosUI
import SportCore
import SwiftUI
import UIKit

@MainActor
final class PhotoVaultStore: ObservableObject {
  @Published private(set) var gate = VaultAccessGate()
  @Published private(set) var photos: [VaultPhotoEntry] = []
  @Published private(set) var photoActivity: VaultPhotoActivity?
  @Published private(set) var photoActivityError: String?
  @Published private(set) var thumbnails: [String: UIImage] = [:]
  @Published private(set) var preview: UIImage?
  @Published private(set) var comparisonImages: [String: UIImage] = [:]
  @Published var busy = false
  @Published var error: String?
  @Published var notice: String?
  @Published private(set) var dismissRequest = UUID()
  var key: SymmetricKey?
  var lease: VaultLease?
  private var context: LAContext?
  private var repository: VaultRepository?
  private var thumbnailOrder: [String] = []
  private var previewID: String?
  private var comparisonRequest: UUID?
  private var resetting = false
  private var activityRequest = UUID()
  @Published var movements: [VaultMovementEntry] = []
  @Published var videos: [VaultVideoEntry] = []
  @Published var videoThumbnails: [String: UIImage] = [:]
  @Published var videoStaging: VaultVideoStaging?
  var videoRequest = UUID()
  var videoPlaybacks: [UUID: VaultVideoPlayback] = [:]
  init() {
    do { try VaultVideoStaging.removeAbandoned() } catch {
      self.error =
        "An interrupted video import could not be cleaned up. Restart Sport and try again."
    }
  }
  var sessionToken: UUID? { gate.phase == .unlocked ? lease?.id : nil }
  func allows(_ session: UUID) -> Bool {
    sessionToken == session && lease.map { current($0) } == true
  }

  func database() throws -> VaultRepository {
    if let repository { return repository }
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var folder = support.appendingPathComponent("PhotoVault-v1", isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)
    let file = folder.appendingPathComponent("vault.sqlite")
    let repository = try VaultRepository(path: file.path)
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
    self.repository = repository
    return repository
  }
  func current(_ lease: VaultLease) -> Bool {
    self.lease === lease && gate.phase == .unlocked && (try? lease.check()) != nil
  }
  func refreshPhotoActivity() async {
    let request = UUID()
    activityRequest = request
    do {
      let activity = try await database().photoActivity()
      guard activityRequest == request else { return }
      photoActivity = activity
      photoActivityError = nil
    } catch {
      guard activityRequest == request else { return }
      photoActivity = nil
      photoActivityError = "Photo activity is unavailable. Try opening Progress again."
    }
  }
  func message(_ error: Error) -> String {
    if let error = error as? VaultFailure { return error.localizedDescription }
    if let error = error as? VaultVideoFailure { return error.localizedDescription }
    if let error = error as? VaultMediaError { return error.localizedDescription }
    return "The operation could not be completed. The vault was not reset. Try again."
  }
  func unlock() {
    guard !resetting, !busy, let token = gate.begin() else { return }
    error = nil
    notice = nil
    let context = LAContext()
    context.localizedFallbackTitle = ""
    self.context = context
    Task {
      var openingLease: VaultLease?
      do {
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil),
          context.biometryType == .faceID
        else { throw VaultMediaError.faceIDUnavailable }
        guard
          try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your private photos and videos in Sport.")
        else { throw VaultFailure.locked }
        guard gate.accepts(token) else { return }
        let repo = try database()
        let state = try await repo.state()
        guard gate.accepts(token) else { return }
        let id: String
        let key: SymmetricKey
        if let state {
          id = state.keyID
          key = try VaultKeychain.load(id: id, context: context)
          try VaultCryptography.verify(key: key, keyID: id, encrypted: state.verification)
        } else {
          id = UUID().uuidString
          key = try VaultKeychain.create(id: id, context: context)
          do {
            let verification = try VaultCryptography.seal(
              Data("Sport vault v1".utf8), key: key, keyID: id, id: "vault", role: "verification")
            try await repo.initialize(keyID: id, verification: verification)
          } catch {
            VaultKeychain.discardNewKey(id: id)
            throw error
          }
        }
        guard gate.accepts(token) else { return }
        let lease = VaultLease(keyID: id)
        openingLease = lease
        self.lease = lease
        let rows = try await repo.metadata(lease: lease)
        let entries = try await Task.detached {
          try rows.map { row in
            try lease.check()
            let data = try VaultCryptography.open(
              row.data, key: key, keyID: id, id: row.id, role: "metadata")
            let meta = try JSONDecoder().decode(VaultPhotoMetadata.self, from: data)
            guard UUID(uuidString: row.id) != nil, VaultDates.date(meta.dayKey) != nil,
              ["public.jpeg", "public.png", "public.heic", "public.heif"].contains(meta.type)
            else { throw VaultFailure.damaged }
            return VaultDecodedEntry(id: row.id, metadata: meta, encryptedMetadata: row.data)
          }
        }.value
        guard gate.accepts(token) else {
          lease.invalidate()
          return
        }
        try await repo.indexPhotoDays(
          entries.map {
            VaultPhotoIndexEntry(
              id: $0.id, dayKey: $0.metadata.dayKey, encryptedMetadata: $0.encryptedMetadata)
          },
          lease: lease)
        await refreshPhotoActivity()
        let videoState = try await readVideoState(key: key, lease: lease)
        guard gate.complete(token) else {
          lease.invalidate()
          return
        }
        self.key = key
        movements = videoState.0
        videos = videoState.1
        photos = entries.map { VaultPhotoEntry(id: $0.id, metadata: $0.metadata) }.sorted {
          $0.metadata.dayKey > $1.metadata.dayKey
        }
        self.context = nil
        context.invalidate()
        SportHaptics.shared.play(.success)
        await removeExistingVideoAudio(session: lease.id)
      } catch {
        openingLease?.invalidate()
        guard gate.accepts(token) else { return }
        gate.fail(token)
        self.key = nil
        self.lease = nil
        self.context = nil
        context.invalidate()
        if let failure = error as? LAError,
          [.userCancel, .appCancel, .systemCancel].contains(failure.code)
        {
          return
        }
        self.error = message(error)
      }
    }
  }
  func lock() {
    lease?.invalidate()
    lease = nil
    key = nil
    gate.lock()
    for playback in videoPlaybacks.values { playback.stop() }
    videoPlaybacks = [:]
    videoRequest = UUID()
    videoStaging = nil
    movements = []
    videos = []
    videoThumbnails = [:]
    photos = []
    thumbnails = [:]
    thumbnailOrder = []
    preview = nil
    previewID = nil
    clearComparison()
    context?.invalidate()
    context = nil
    busy = resetting
    error = nil
    notice = nil
  }
  func cover() {
    if gate.phase != .locked { VaultPrivacyShield.shared.show() }
    for playback in videoPlaybacks.values {
      playback.cover()
    }
    gate.cover()
  }
  func foreground() {
    VaultPrivacyShield.shared.hide()
    gate.foreground()
    for playback in videoPlaybacks.values { playback.foreground() }
  }
  func background() {
    cover()
    lock()
  }
  func leaveVault() {
    lock()
    dismissRequest = UUID()
  }
  func loadThumbnail(id: String) async {
    guard let lease, let key, current(lease), thumbnails[id] == nil else { return }
    do {
      let encrypted = try await database().content(id: id, thumbnail: true, lease: lease)
      guard current(lease), !Task.isCancelled else { return }
      let data = try VaultCryptography.open(
        encrypted, key: key, keyID: lease.keyID, id: id, role: "thumbnail")
      guard current(lease), !Task.isCancelled, let image = UIImage(data: data) else { return }
      thumbnailOrder.removeAll { $0 == id }
      thumbnailOrder.append(id)
      if thumbnailOrder.count > 64 {
        thumbnails[thumbnailOrder.removeFirst()] = nil
      }
      thumbnails[id] = image
    } catch { if current(lease) { self.error = message(error) } }
  }
  func loadPreview(id: String, session: UUID) async {
    guard let lease, let key, current(lease) else { return }
    guard allows(session) else { return }
    previewID = id
    preview = nil
    error = nil
    notice = nil
    do {
      let encrypted = try await database().content(id: id, thumbnail: false, lease: lease)
      let bytes = try await Task.detached {
        try lease.check()
        let original = try VaultCryptography.open(
          encrypted, key: key, keyID: lease.keyID, id: id, role: "original")
        try lease.check()
        return try VaultCryptography.preview(original, pixels: 2400)
      }.value
      guard current(lease), previewID == id, !Task.isCancelled else { return }
      preview = UIImage(data: bytes)
    } catch { if current(lease) { self.error = message(error) } }
  }
  func clearPreview() {
    preview = nil
    previewID = nil
  }
  func importSelection(_ item: PhotosPickerItem, day: Date, pose: VaultPhotoPose, session: UUID)
    async
  {
    guard allows(session) else { return }
    guard let lease, current(lease), !busy else { return }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do {
      guard let transfer = try await item.loadTransferable(type: VaultTransferredImage.self) else {
        throw VaultFailure.invalidPhoto
      }
      guard current(lease), let key else { return }
      try await saveImage(transfer.data, day: day, pose: pose, lease: lease, key: key)
    } catch { if current(lease) { self.error = message(error) } }
  }
  func importCamera(_ bytes: Data, day: Date, pose: VaultPhotoPose, session: UUID) async {
    guard allows(session) else { return }
    guard let lease, let key, current(lease), !busy else { return }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do { try await saveImage(bytes, day: day, pose: pose, lease: lease, key: key) } catch {
      if current(lease) { self.error = message(error) }
    }
  }
  private func saveImage(
    _ bytes: Data, day: Date, pose: VaultPhotoPose, lease: VaultLease, key: SymmetricKey
  )
    async throws
  {
    let dayKey = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000))
    let record = try await Task.detached {
      try lease.check()
      return try VaultCryptography.prepare(
        bytes, day: dayKey, pose: pose, key: key, keyID: lease.keyID)
    }.value
    guard current(lease) else { return }
    try await database().insert(record, dayKey: dayKey, lease: lease)
    await refreshPhotoActivity()
    guard current(lease) else { return }
    let data = try VaultCryptography.open(
      record.metadata, key: key, keyID: lease.keyID, id: record.id, role: "metadata")
    let meta = try JSONDecoder().decode(VaultPhotoMetadata.self, from: data)
    photos.insert(VaultPhotoEntry(id: record.id, metadata: meta), at: 0)
    photos.sort { $0.metadata.dayKey > $1.metadata.dayKey }
    notice = nil
    SportHaptics.shared.play(.success)
  }
  func delete(id: String?, session: UUID) async {
    guard allows(session) else { return }
    guard let lease, current(lease), !busy else { return }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do {
      try await database().delete(id: id, lease: lease)
      await refreshPhotoActivity()
      guard current(lease) else { return }
      if let id {
        photos.removeAll { $0.id == id }
        thumbnails[id] = nil
        thumbnailOrder.removeAll { $0 == id }
      } else {
        photos = []
        thumbnails = [:]
        thumbnailOrder = []
      }
      clearPreview()
      clearComparison()
      notice = nil
    } catch { if current(lease) { self.error = message(error) } }
  }
  func changeMetadata(id: String, day: Date, pose: VaultPhotoPose?, session: UUID) async -> Bool {
    guard allows(session) else { return false }
    guard let lease, let key, current(lease), !busy,
      let entry = photos.first(where: { $0.id == id })
    else { return false }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do {
      var metadata = entry.metadata
      metadata.dayKey = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000))
      metadata.pose = pose
      let encrypted = try VaultCryptography.seal(
        JSONEncoder().encode(metadata), key: key, keyID: lease.keyID, id: id, role: "metadata")
      try await database().changeMetadata(
        id: id, encrypted: encrypted, dayKey: metadata.dayKey, lease: lease)
      await refreshPhotoActivity()
      guard current(lease) else { return false }
      photos.removeAll { $0.id == id }
      photos.append(VaultPhotoEntry(id: id, metadata: metadata))
      photos.sort { $0.metadata.dayKey > $1.metadata.dayKey }
      clearComparison()
      return true
    } catch {
      if current(lease) { self.error = message(error) }
      return false
    }
  }
  func deletePhotos(ids: [String], session: UUID) async {
    guard allows(session), let lease, current(lease), !busy else { return }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do {
      try await database().delete(ids: ids, lease: lease)
      await refreshPhotoActivity()
      guard current(lease) else { return }
      let removed = Set(ids)
      photos.removeAll { removed.contains($0.id) }
      for id in ids { thumbnails[id] = nil }
      thumbnailOrder.removeAll { removed.contains($0) }
      clearPreview()
      clearComparison()
    } catch { if current(lease) { self.error = message(error) } }
  }
  func clearComparison() {
    comparisonRequest = nil
    comparisonImages = [:]
  }
  func loadComparison(firstID: String, secondID: String, session: UUID) async {
    guard allows(session), let lease, let key, current(lease),
      let first = photos.first(where: { $0.id == firstID }),
      let second = photos.first(where: { $0.id == secondID }),
      VaultPhotoCollection.canCompare(first, second)
    else { return }
    clearComparison()
    let request = UUID()
    comparisonRequest = request
    error = nil
    do {
      var images: [String: UIImage] = [:]
      for id in [firstID, secondID] {
        guard current(lease), comparisonRequest == request, !Task.isCancelled else { return }
        let encrypted = try await database().content(id: id, thumbnail: false, lease: lease)
        guard current(lease), comparisonRequest == request, !Task.isCancelled else { return }
        let bytes = try await Task.detached {
          try lease.check()
          let original = try VaultCryptography.open(
            encrypted, key: key, keyID: lease.keyID, id: id, role: "original")
          try lease.check()
          return try VaultCryptography.preview(original, pixels: 2400)
        }.value
        guard current(lease), comparisonRequest == request, !Task.isCancelled else { return }
        guard let image = UIImage(data: bytes) else { throw VaultFailure.invalidPhoto }
        images[id] = image
      }
      guard current(lease), comparisonRequest == request, !Task.isCancelled else { return }
      comparisonImages = images
    } catch {
      if current(lease), comparisonRequest == request, !Task.isCancelled {
        self.error = message(error)
      }
    }
  }
  func export(id: String, session: UUID) async {
    guard allows(session) else { return }
    guard let lease, let key, current(lease), !busy else { return }
    busy = true
    error = nil
    notice = nil
    defer { if current(lease) { busy = false } }
    do {
      var permission = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      if permission == .notDetermined {
        permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      }
      guard current(lease) else { return }
      guard permission == .authorized else { throw VaultMediaError.exportDenied }
      let encrypted = try await database().content(id: id, thumbnail: false, lease: lease)
      guard current(lease) else { return }
      let data = try VaultCryptography.open(
        encrypted, key: key, keyID: lease.keyID, id: id, role: "original")
      try lease.check()
      try await PHPhotoLibrary.shared().performChanges {
        guard (try? lease.check()) != nil else { return }
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
      }
      guard current(lease) else { return }
      notice = "Copy saved to Photos."
      SportHaptics.shared.play(.success)
    } catch { if current(lease) { self.error = message(error) } }
  }
  func reset() async {
    guard !resetting else { return }
    resetting = true
    lock()
    busy = true
    do {
      try VaultKeychain.reset()
      try await database().reset()
      await refreshPhotoActivity()
      notice = "Vault reset."
    } catch { self.error = message(error) }
    resetting = false
    busy = false
  }
}
private struct VaultDecodedEntry: Sendable {
  let id: String
  let metadata: VaultPhotoMetadata
  let encryptedMetadata: Data
}
enum VaultDates {
  static func date(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let date = formatter.date(from: key), formatter.string(from: date) == key else {
      return nil
    }
    return date
  }
}
