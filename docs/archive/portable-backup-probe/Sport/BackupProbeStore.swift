import Foundation
import SportCore
import SwiftUI

@MainActor
final class BackupProbeStore: ObservableObject {
  @Published var password = ""
  @Published var confirmation = ""
  @Published private(set) var transfer: BackupProbeTransfer?
  @Published private(set) var selectedData: Data?
  @Published private(set) var checksPassed = false
  @Published private(set) var busy = false
  @Published private(set) var message: String?
  @Published var error: String?
  private let engine = BackupProbeEngine()
  private var ticket = UUID()
  private var visible = false
  private var active = false
  private var transferGate = BackupProbeTransferGate()
  private var job: Task<Void, Never>?
  var canExport: Bool {
    (12...1024).contains(password.count) && password.utf8.count <= 1024
      && password.utf8.elementsEqual(confirmation.utf8) && !busy
  }
  var canVerify: Bool {
    selectedData != nil && !password.isEmpty && password.utf8.count <= 1024 && !busy
  }
  func open(active: Bool) {
    visible = true
    self.active = active
    transferGate.open(active: active)
  }
  func setActive(_ value: Bool) {
    active = value
    transferGate.setActive(value)
    if !value {
      clearSecrets()
      transfer = nil
    }
  }
  func chooseFile() {
    guard !busy, transfer == nil, let id = transferGate.begin() else { return }
    clearSecrets()
    transfer = BackupProbeTransfer(id: id, kind: .importFile)
  }
  func clearSecrets() {
    password = ""
    confirmation = ""
    ticket = UUID()
    job?.cancel()
    job = nil
    busy = false
  }
  func close() {
    visible = false
    transferGate.close()
    clearSecrets()
    checksPassed = false
    selectedData = nil
    transfer = nil
    message = nil
    error = nil
  }
  func runChecks() {
    guard !busy else { return }
    checksPassed = false
    start {
      try await self.engine.runChecks()
      return .checked
    }
  }
  func prepareExport() {
    guard canExport else { return }
    let secret = password
    clearSecrets()
    start { .encrypted(try await self.engine.encrypt(password: secret)) }
  }
  private func select(_ url: URL) {
    selectedData = nil
    clearSecrets()
    start { .selected(try await self.engine.read(url: url)) }
  }
  func verifySelected() {
    guard canVerify, let data = selectedData else { return }
    let secret = password
    clearSecrets()
    start {
      try await self.engine.verify(data: data, password: secret)
      return .verified
    }
  }
  func transferCompleted(id: UUID, result: Result<URL, Error>) {
    guard let request = transfer, request.id == id, transferGate.finish(id) else { return }
    transfer = nil
    switch result {
    case .success(let url):
      switch request.kind {
      case .importFile: select(url)
      case .exportFile: message = "Sample file saved. It contains no workouts or private photos."
      }
    case .failure(let failure):
      if (failure as NSError).code != NSUserCancelledError {
        error = "Unable to transfer the test file. Try again in Files."
      }
    }
  }
  private enum ResultValue: Sendable {
    case checked
    case encrypted(Data)
    case selected(Data)
    case verified
  }
  private func start(_ operation: @escaping @MainActor () async throws -> ResultValue) {
    guard visible, active, !busy, transfer == nil else { return }
    password = ""
    confirmation = ""
    error = nil
    message = nil
    busy = true
    let current = UUID()
    ticket = current
    job = Task {
      defer {
        if ticket == current {
          busy = false
          job = nil
        }
      }
      do {
        let result = try await operation()
        try Task.checkCancellation()
        guard visible, active, ticket == current else { return }
        switch result {
        case .checked: checksPassed = true
        case .encrypted(let data):
          guard let id = transferGate.begin() else { return }
          transfer = BackupProbeTransfer(id: id, kind: .exportFile(data))
        case .selected(let data): selectedData = data
        case .verified:
          message = "Sample file verified. No personal data were imported or replaced."
        }
        SportHaptics.shared.play(.success)
      } catch is CancellationError {
      } catch {
        guard visible, active, ticket == current, !Task.isCancelled else { return }
        self.error =
          (error as? BackupProbeFailure)?.localizedDescription
          ?? "The test could not finish. No personal data were accessed."
      }
    }
  }
}
