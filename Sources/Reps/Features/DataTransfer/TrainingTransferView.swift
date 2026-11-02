import Foundation
import RepsCore
import SwiftUI
import UniformTypeIdentifiers

private enum ParsedTrainingFile: Sendable {
  case csv([WorkoutSession])
  case archive(TrainingArchive)
  case encrypted(URL)
}

struct TrainingTransferView: View {
  @EnvironmentObject private var store: TrainingStore
  @EnvironmentObject private var vault: PhotoVaultStore
  @StateObject private var backup = PortableBackupStore()
  @State private var includeVault = false
  @State private var importing = false
  @State private var exporting = false
  @State private var document = TrainingFileDocument(data: Data())
  @State private var filename = "Reps"
  @State private var preview: TrainingImportPreview?
  @State private var busy = false
  @State private var error: String?
  @State private var message: String?

  var body: some View {
    List {
      Section {
        Button("Import from Files", systemImage: "square.and.arrow.down") {
          importing = true
        }
        Button("Export to Files", systemImage: "square.and.arrow.up") {
          chooseExport()
        }
        Toggle("Include Private Vault", systemImage: "lock.fill", isOn: $includeVault)
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text(
            includeVault
              ? "Includes all training data and your entire Private Vault. A nonempty vault requires Face ID and an export password. An empty vault exports without a password."
              : "Includes all training data and settings, without a password. Private Vault photos, videos and movements are excluded."
          )
          if let message { Text(message) }
        }
      }
    }
    .disabled(busy)
    .overlay {
      if busy { ProgressView("Preparing…") }
    }
    .navigationTitle("Import and Export").navigationBarTitleDisplayMode(.inline)
    .fileImporter(
      isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText, .data]
    ) {
      result in
      switch result {
      case .success(let url):
        if url.pathExtension.lowercased() == "repsbackup" {
          backup.beginImport(url)
        } else {
          read(url)
        }
      case .failure(let failure):
        if !isCancellation(failure) { error = "Unable to open the selected file." }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: filename
    ) { result in
      switch result {
      case .success: message = "File saved. Private photos are excluded."
      case .failure(let failure):
        if !isCancellation(failure) {
          error = "Unable to save the file. Try again in Files."
        }
      }
      document = TrainingFileDocument(data: Data())
    }
    .sheet(item: $preview) { value in
      TrainingImportPreviewView(preview: value) { message = $0 }
    }
    .sheet(isPresented: $backup.presented, onDismiss: { backup.cancel(vault: vault) }) {
      PortableBackupFlowView(backup: backup)
    }
    .alert(
      "Unable to Transfer",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func isCancellation(_ error: Error) -> Bool {
    (error as NSError).code == NSUserCancelledError
  }
  private func chooseExport() {
    guard includeVault else {
      prepareExport()
      return
    }
    guard !busy else { return }
    guard !vault.busy else {
      error = "Finish the vault operation before exporting."
      return
    }
    busy = true
    Task {
      do {
        let inventory = try await vault.database().backupInventory()
        guard !vault.busy else { throw PortableBackupFailure.interrupted }
        if inventory.isEmpty {
          if try await vault.database().state() != nil {
            _ = try await vault.authenticateBackup()
            vault.lock()
          }
          busy = false
          prepareExport()
        } else {
          busy = false
          backup.beginExport()
        }
      } catch {
        busy = false
        self.error = "The vault could not be read. No partial backup was exported."
      }
    }
  }
  private func prepareExport() {
    guard !busy else { return }
    busy = true
    message = nil
    Task {
      defer { busy = false }
      do {
        let archive = try await store.exportTraining()
        let data = try await Task.detached(priority: .userInitiated) {
          try archive.encoded()
        }.value
        document = TrainingFileDocument(data: data)
        filename = "Reps-\(WorkoutClock.dayKey(WorkoutClock.now))"
        exporting = true
      } catch { self.error = error.localizedDescription }
    }
  }
  private func read(_ url: URL) {
    guard !busy else { return }
    busy = true
    message = nil
    Task {
      defer { busy = false }
      do {
        let parsed = try await Task.detached(priority: .userInitiated) {
          () throws -> ParsedTrainingFile in
          let scoped = url.startAccessingSecurityScopedResource()
          defer { if scoped { url.stopAccessingSecurityScopedResource() } }
          let handle: FileHandle
          do { handle = try FileHandle(forReadingFrom: url) } catch {
            throw TrainingError.invalid(
              "Unable to read this file. Check its availability in Files.")
          }
          defer { try? handle.close() }
          if try handle.read(upToCount: 8) == PortableBackupHeader.prefix { return .encrypted(url) }
          try handle.seek(toOffset: 0)
          guard let data = try handle.read(upToCount: TrainingTransfer.maximumBytes + 1),
            data.count <= TrainingTransfer.maximumBytes
          else {
            throw TrainingError.invalid(
              "The file exceeds 10 MB or cannot be read.")
          }
          return url.pathExtension.lowercased() == "csv"
            ? .csv(try TrainingCSV.decode(data)) : .archive(try TrainingArchive.decode(data))
        }.value
        switch parsed {
        case .csv(let records): preview = try await store.previewCSVImport(records)
        case .archive(let archive): preview = try await store.previewArchiveImport(archive)
        case .encrypted(let url): backup.beginImport(url)
        }
      } catch {
        self.error =
          (error as? TrainingError)?.localizedDescription
          ?? "The file could not be read. Nothing was imported."
      }
    }
  }
}

private struct TrainingImportPreviewView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let preview: TrainingImportPreview
  let completed: (String) -> Void
  @State private var confirmRestore = false
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      List {
        Section {
          LabeledContent(
            "Workouts in File", value: String(preview.workoutCount))
          LabeledContent("Current Workouts to Replace", value: String(preview.replacedCount))
          LabeledContent("Sets", value: String(preview.setCount))
          if !preview.isRestoration {
            LabeledContent(
              "Matching Workouts Already Present", value: String(preview.identicalCount))
          }
          if preview.isRestoration {
            LabeledContent(
              "Exercises", value: String(preview.incoming.configuration.exercises.count))
            LabeledContent(
              "Scheduled Workouts", value: String(preview.incoming.configuration.schedules.count))
            LabeledContent(
              "Body Weight Measurements", value: String(preview.incoming.bodyWeights.count))
            Text(
              preview.preservesBodyWeight
                ? "This older backup replaces training history and settings. Your body weight measurements and weight reminder will be kept. A recovery copy will be kept in Reps. Private photos and iOS permissions are unaffected."
                : "This restoration replaces training history, settings, body weight measurements and the weight reminder. A recovery copy will be kept in Reps. Private photos and iOS permissions are unaffected."
            ).foregroundStyle(.secondary)
          } else {
            Text(
              "This CSV will replace all workout history. Schedule, catalog, inventory, goals and settings will be kept. A recovery copy will be kept in Reps. Private photos are excluded."
            ).foregroundStyle(.secondary)
          }
        }
        if preview.isUnchanged {
          Section {
            Text("The file already matches your data. No replacement needed.")
              .foregroundStyle(.secondary)
          }
        } else if preview.workoutCount == 0 {
          Section {
            Text(
              "The file contains no workouts. Confirming replacement will empty your history."
            )
            .foregroundStyle(.secondary)
          }
        }
        Section("Workout Preview") {
          ForEach(Array(preview.incoming.workouts.prefix(12))) { workout in
            VStack(alignment: .leading, spacing: 4) {
              Text(workout.name)
              Text(
                "\(WorkoutLabels.day(workout.dayKey)) · \(workout.status == .completed ? "Completed" : "Canceled")"
              ).font(.subheadline).foregroundStyle(.secondary)
            }
          }
          if preview.incoming.workouts.count > 12 {
            Text("And \(preview.incoming.workouts.count - 12) other workouts.").foregroundStyle(
              .secondary)
          }
        }
      }
      .disabled(busy).interactiveDismissDisabled(busy)
      .navigationTitle("Review Import").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly
          ).disabled(busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(preview.isRestoration ? "Restore" : "Replace") {
            confirmRestore = true
          }.disabled(busy || preview.isUnchanged)
        }
      }
      .repsConfirmation(
        preview.isRestoration
          ? "Replace Training Data?" : "Replace All History?",
        isPresented: $confirmRestore
      ) {
        Button(
          preview.isRestoration ? "Restore Backup" : "Replace History",
          role: .destructive
        ) { apply() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          preview.isRestoration
            ? "Current training data will be replaced. A recovery copy will be kept in Reps. Private photos are excluded."
            : "The \(preview.replacedCount) current workouts will be replaced by \(preview.workoutCount) workouts from the CSV. Settings stay unchanged. A recovery copy will be kept in Reps. Private photos are excluded."
        )
      }
      .alert(
        "Import Not Completed",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }
  private func apply() {
    guard !busy else { return }
    busy = true
    Task {
      defer { busy = false }
      do {
        try await store.applyTrainingImport(preview)
        completed(
          preview.isRestoration
            ? "Training data restored. A recovery copy is kept in Reps."
            : "History replaced by \(preview.workoutCount) workouts from the CSV. Settings kept; a recovery copy is kept in Reps."
        )
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
