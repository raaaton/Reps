import SwiftUI
import UniformTypeIdentifiers

struct BackupProbeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model = BackupProbeStore()
  var body: some View {
    Form {
      Section {
        Button("Run Encryption Checks", systemImage: "checkmark.shield") { model.runChecks() }
          .disabled(model.busy)
        if model.checksPassed {
          Label("Native encryption checks passed", systemImage: "checkmark.circle")
          Text(
            "Key derivation, round trip, unique encryption, wrong password, altered file and altered context were checked on this iPhone."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
      } header: {
        Text("Compatibility")
      } footer: {
        Text(
          "This test uses sample data only. Full backup is not available yet; workouts and private photos are never read or replaced here."
        )
      }
      Section {
        SecureField("Password", text: $model.password)
          .textContentType(.newPassword).textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        SecureField("Confirm Password for Export", text: $model.confirmation)
          .textContentType(.newPassword).textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      } header: {
        Text("Test Password")
      } footer: {
        Text(
          "Use a test password with at least 12 characters for export. Passwords are cleared when work starts or Sport becomes inactive. Re-enter the file password to verify it; confirmation is only needed for export."
        )
      }
      Section {
        Button("Export Sample File", systemImage: "square.and.arrow.up") { model.prepareExport() }
          .disabled(!model.canExport)
        Button("Choose Test File", systemImage: "square.and.arrow.down") { model.chooseFile() }
          .disabled(model.busy)
        if model.selectedData != nil {
          Label("Test File Selected", systemImage: "doc")
          Button("Verify Selected File", systemImage: "checkmark") { model.verifySelected() }
            .disabled(!model.canVerify)
        }
      } header: {
        Text("Files")
      } footer: {
        Text(
          "Save the .sporttest file, leave this screen, then return and select it. A wrong password must fail; the original password must verify the sample without changing your data."
        )
      }
      if model.busy { Section { ProgressView("Checking…") } }
      if let message = model.message { Section { Text(message).foregroundStyle(.secondary) } }
    }
    .navigationTitle("Encrypted Backup Test").navigationBarTitleDisplayMode(.inline)
    .onAppear { model.open(active: scenePhase == .active) }
    .onDisappear { model.close() }
    .onChange(of: scenePhase) { _, phase in
      model.setActive(phase == .active)
    }
    .background {
      if let request = model.transfer {
        BackupProbeTransferView(request: request) { [id = request.id] result in
          model.transferCompleted(id: id, result: result)
        }.id(request.id)
      }
    }
    .alert(
      "Test Not Completed",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK", role: .cancel) { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
  }
}
