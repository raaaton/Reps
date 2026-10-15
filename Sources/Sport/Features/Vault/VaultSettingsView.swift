import LocalAuthentication
import SwiftUI

struct VaultSettingsView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @State private var confirmReset = false
  @State private var faceIDAvailable = false
  var body: some View {
    List {
      Section {
        LabeledContent("Face ID", value: faceIDAvailable ? "Available" : "Unavailable")
        LabeledContent("Locking", value: "Immediate")
        LabeledContent("App Switcher Preview", value: "Hidden")
      } footer: {
        Text("The vault locks when you leave it or put Sport in the background.")
      }
      Section {
        Text(
          "Originals and thumbnails are encrypted on this iPhone. Training CSV and JSON exports exclude private photos."
        )
        .foregroundStyle(.secondary)
      }
      Section {
        SportDestructiveButton("Reset Vault", systemImage: "arrow.counterclockwise") {
          confirmReset = true
        }.foregroundStyle(.red).disabled(vault.busy)
      } footer: {
        Text(
          "Sport never replaces an inaccessible key after biometric changes. Reset permanently deletes all private photos in the vault."
        )
      }
    }
    .navigationTitle("Photo Vault").navigationBarTitleDisplayMode(.inline)
    .task {
      let context = LAContext()
      faceIDAvailable =
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        && context.biometryType == .faceID
      context.invalidate()
    }
    .sportConfirmation("Reset Photo Vault?", isPresented: $confirmReset) {
      Button("Delete Everything", role: .destructive) { Task { await vault.reset() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "All private Sport photos and their key will be permanently deleted. Originals in Photos and training data will be kept."
      )
    }
    .alert(
      "Unable to Complete Operation",
      isPresented: Binding(get: { vault.error != nil }, set: { if !$0 { vault.error = nil } })
    ) {
      Button("OK", role: .cancel) { vault.error = nil }
    } message: {
      Text(vault.error ?? "")
    }
    .safeAreaInset(edge: .bottom) {
      if let notice = vault.notice { Text(notice).font(.footnote).padding().background(.bar) }
    }
  }
}
