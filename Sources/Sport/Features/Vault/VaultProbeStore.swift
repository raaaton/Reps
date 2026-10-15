import LocalAuthentication
import SportCore
import SwiftUI
import UIKit

@MainActor
final class VaultProbeStore: ObservableObject {
  @Published private(set) var gate = VaultAccessGate()
  @Published private(set) var result: VaultProbeStorage.Result?
  @Published private(set) var error: String?
  private var context: LAContext?

  func unlock() {
    guard let token = gate.begin() else { return }
    error = nil
    let context = LAContext()
    context.localizedFallbackTitle = ""
    self.context = context
    Task {
      do {
        var failure: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &failure),
          context.biometryType == .faceID
        else {
          throw NSError(
            domain: "SportVault", code: 1,
            userInfo: [
              NSLocalizedDescriptionKey: "Face ID must be set up and available on this iPhone."
            ])
        }
        let authenticated = try await context.evaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          localizedReason: "Unlock Sport vault test data.")
        guard authenticated else { throw LAError(.authenticationFailed) }
        guard gate.accepts(token) else { return }
        let result = try VaultProbeStorage.validate(context: context)
        guard gate.complete(token) else { return }
        self.result = result
        self.context = nil
        context.invalidate()
        SportHaptics.shared.play(.success)
      } catch {
        guard gate.accepts(token) else { return }
        gate.fail(token)
        self.context = nil
        context.invalidate()
        if let failure = error as? LAError,
          [.userCancel, .appCancel, .systemCancel].contains(failure.code)
        {
          return
        }
        self.error = error.localizedDescription
      }
    }
  }
  func cover() { gate.cover() }
  func foreground() { gate.foreground() }
  func lock() {
    gate.lock()
    result = nil
    error = nil
    context?.invalidate()
    context = nil
  }
  func background() {
    cover()
    lock()
  }
  func resetSyntheticData() {
    lock()
    do { try VaultProbeStorage.resetSyntheticData() } catch {
      self.error = error.localizedDescription
    }
  }
}
