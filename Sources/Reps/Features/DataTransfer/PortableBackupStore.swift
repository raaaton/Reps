import CryptoKit
import Foundation
import RepsCore
import SwiftUI

@MainActor
final class PortableBackupStore: ObservableObject {
  enum Step { case exportPassword, importPassword, preparing, preview, saved }
  @Published var presented = false
  @Published var saving = false
  @Published var step: Step = .exportPassword
  @Published var password = ""
  @Published var confirmation = ""
  @Published var error: String?
  @Published var output: URL?
  @Published var contents: PortableBackupContents?
  @Published var preview: TrainingImportPreview?
  @Published var currentInventory: VaultBackupInventory?
  private var targetStamp: VaultBackupStamp?
  private var input: URL?
  private var access: PortableBackupAccess?
  private var workspace: PortableBackupWorkspace?
  private var task: Task<Void, Never>?
  private var generation = UUID()
  private let engine = PortableBackupEngine()
  var busy: Bool { step == .preparing }
  var validPassword: Bool {
    step == .importPassword
      ? !password.isEmpty && password.utf8.count <= 1024
      : password.count >= 12 && password.utf8.count <= 1024 && password == confirmation
  }
  func beginExport() {
    clear()
    step = .exportPassword
    presented = true
  }
  func beginImport(_ url: URL) {
    clear()
    input = url
    step = .importPassword
    presented = true
  }
  func prepare(training: TrainingStore, vault: PhotoVaultStore) {
    guard !busy, validPassword, let repository = training.repository else { return }
    let importing = step == .importPassword
    let secret = password
    password = ""
    confirmation = ""
    error = nil
    step = .preparing
    let request = generation
    let selected = input
    task = Task {
      var stage = "vault.authentication"
      do {
        let access: PortableBackupAccess
        if importing {
          let lease = VaultLease(keyID: UUID().uuidString)
          access = PortableBackupAccess(
            key: SymmetricKey(size: .bits256), lease: lease, path: "",
            stamp: VaultBackupStamp(keyID: lease.keyID, revision: 0))
        } else {
          access = try await vault.authenticateBackup()
        }
        guard generation == request else {
          access.lease.invalidate()
          return
        }
        self.access = access
        stage = "workspace.create"
        let workspace = try PortableBackupWorkspace()
        self.workspace = workspace
        defer { withExtendedLifetime(workspace) {} }
        if importing {
          guard let selected else { throw PortableBackupFailure.invalid }
          stage = "archive.read"
          let contents = try await engine.read(
            url: selected, password: secret, access: access, staged: workspace.url("vault.sqlite"))
          let preview = try await repository.previewArchiveImport(
            contents.archive, now: WorkoutClock.now)
          let vaultRepository = try vault.database()
          let stamp = try await vaultRepository.backupStamp()
          let inventory = try await vaultRepository.backupInventory()
          try access.check()
          guard generation == request else { return }
          self.targetStamp = stamp
          self.currentInventory = inventory
          self.contents = contents
          self.preview = preview
          step = .preview
        } else {
          let snapshot = workspace.url("snapshot.sqlite")
          stage = "snapshot.capture"
          let archive = try await repository.captureCompleteBackup(
            vaultPath: access.path, snapshotPath: snapshot.path, lease: access.lease,
            now: WorkoutClock.now)
          let output = workspace.url("Reps-\(WorkoutClock.dayKey(WorkoutClock.now)).repsbackup")
          stage = "archive.encrypt"
          try await engine.export(
            archive: archive, snapshot: snapshot, access: access, password: secret, output: output)
          try access.check()
          guard generation == request else { return }
          self.output = output
          step = .saved
          saving = true
        }
      } catch {
        guard generation == request else { return }
        if case TrainingError.storage = error {
          self.error = PortableBackupStorageFailure(stage: stage).localizedDescription
        } else {
          self.error = Self.message(error)
        }
        self.workspace = nil
        self.access = nil
        vault.lock()
        step = importing ? .importPassword : .exportPassword
      }
    }
  }
  func restore(training: TrainingStore, vault: PhotoVaultStore) {
    guard step == .preview, let preview, let access, let workspace, let targetStamp,
      let repository = training.repository
    else { return }
    step = .preparing
    error = nil
    let request = generation
    task = Task {
      do {
        defer { withExtendedLifetime(workspace) {} }
        try access.check()
        let vaultRepository = try vault.database()
        guard try await vaultRepository.backupStamp() == targetStamp else {
          throw PortableBackupFailure.changed
        }
        let destination = try await vault.authenticateBackup()
        guard generation == request else {
          destination.lease.invalidate()
          return
        }
        if targetStamp.keyID.isEmpty {
          guard destination.stamp.revision == targetStamp.revision + 1 else {
            throw PortableBackupFailure.changed
          }
        } else {
          guard destination.stamp == targetStamp else { throw PortableBackupFailure.changed }
        }
        self.targetStamp = destination.stamp
        let restoredFile = workspace.url("restored.sqlite")
        if FileManager.default.fileExists(atPath: restoredFile.path) {
          try FileManager.default.removeItem(at: restoredFile)
        }
        try await engine.rekey(
          source: workspace.url("vault.sqlite"), from: access, to: destination,
          destination: restoredFile)
        try destination.check()
        try await repository.applyCompleteBackup(
          preview, vaultPath: destination.path, stagedPath: workspace.url("restored.sqlite").path,
          expected: destination.stamp, lease: destination.lease, now: WorkoutClock.now)
        vault.lock()
        await vault.refreshPhotoActivity()
        await training.reload()
        guard generation == request else { return }
        clear()
        presented = false
      } catch {
        guard generation == request else { return }
        self.error = Self.message(error)
        vault.lock()
        step = .preview
      }
    }
  }
  func cancel(vault: PhotoVaultStore) {
    clear()
    presented = false
    vault.lock()
  }
  private func clear() {
    generation = UUID()
    task?.cancel()
    task = nil
    access?.lease.invalidate()
    access = nil
    password = ""
    confirmation = ""
    input = nil
    output = nil
    contents = nil
    preview = nil
    workspace = nil
    currentInventory = nil
    targetStamp = nil
    saving = false
    error = nil
  }
  private static func message(_ error: Error) -> String {
    if let failure = error as? PortableBackupStorageFailure { return failure.localizedDescription }
    if let failure = error as? PortableBackupFailure { return failure.localizedDescription }
    if let failure = error as? VaultFailure { return failure.localizedDescription }
    if let failure = error as? TrainingError { return failure.localizedDescription }
    return
      "The transfer could not be completed. Check the password, file and available storage, then try again."
  }
}
