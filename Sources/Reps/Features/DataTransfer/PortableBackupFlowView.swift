import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PortableBackupFlowView: View {
  @ObservedObject var backup: PortableBackupStore
  @EnvironmentObject private var training: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var confirmRestore = false
  var body: some View {
    NavigationStack {
      Form {
        if backup.step == .preparing {
          ProgressView("Preparing secure backup…")
        } else if backup.step == .preview, let contents = backup.contents {
          Section("Backup Contents") {
            LabeledContent("Workouts", value: String(contents.archive.contents.workouts.count))
            LabeledContent("Photos", value: String(contents.inventory.photos))
            LabeledContent("Videos", value: String(contents.inventory.videos))
            LabeledContent("Movements", value: String(contents.inventory.movements))
          }
          if let current = backup.currentInventory, let preview = backup.preview {
            Section("Current Data to Replace") {
              LabeledContent("Workouts", value: String(preview.replacedCount))
              LabeledContent("Photos", value: String(current.photos))
              LabeledContent("Videos", value: String(current.videos))
              LabeledContent("Movements", value: String(current.movements))
            }
          }
          Section {
            Text(
              "Restoring replaces your current training data and your entire Private Vault. An encrypted local recovery copy will be kept."
            )
            Button("Restore Backup", role: .destructive) { confirmRestore = true }
          }
        } else if backup.step == .saved {
          Section {
            Text("Your encrypted backup is ready.")
            Button("Save to Files", systemImage: "square.and.arrow.up") { backup.saving = true }
          }
        } else {
          Section {
            SecureField("Password", text: $backup.password)
              .textContentType(backup.step == .exportPassword ? .newPassword : .password)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
            if backup.step == .exportPassword {
              SecureField("Confirm Password", text: $backup.confirmation)
                .textContentType(.newPassword).textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
          } footer: {
            Text(
              backup.step == .exportPassword
                ? "Use a strong password of at least 12 characters. This encrypts training data and your entire Private Vault. If you lose the password, the backup cannot be recovered."
                : "Enter the password chosen when this backup was exported. Face ID protects the vault on this iPhone."
            )
          }
          Button(backup.step == .exportPassword ? "Export Encrypted Backup" : "Unlock Backup") {
            backup.prepare(training: training, vault: vault)
          }.disabled(!backup.validPassword)
        }
        if let error = backup.error {
          Section { Text(error).foregroundStyle(.red).textSelection(.enabled) }
        }
      }
      .navigationTitle(
        backup.step == .importPassword || backup.step == .preview
          ? "Import Backup" : "Encrypted Backup"
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { backup.cancel(vault: vault) }.labelStyle(
            .iconOnly)
        }
      }
      .interactiveDismissDisabled(backup.busy)
      .repsConfirmation("Replace Training and Private Vault?", isPresented: $confirmRestore) {
        Button("Restore Backup", role: .destructive) {
          backup.restore(training: training, vault: vault)
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "All current training data, photos, videos and movements will be replaced by this backup."
        )
      }
      .sheet(isPresented: $backup.saving) {
        if let output = backup.output {
          PortableBackupFileExporter(url: output) { backup.cancel(vault: vault) }
        }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .inactive { VaultPrivacyShield.shared.show() }
        if phase == .active { VaultPrivacyShield.shared.hide() }
        if phase == .background { backup.cancel(vault: vault) }
      }
    }
  }
}

private struct PortableBackupFileExporter: UIViewControllerRepresentable {
  let url: URL
  let completed: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
  final class Coordinator: NSObject, UIDocumentPickerDelegate {
    let completed: () -> Void
    init(completed: @escaping () -> Void) { self.completed = completed }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completed() }
    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) { completed() }
  }
}
