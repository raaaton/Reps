import Foundation
import SportCore
import SwiftUI
import UniformTypeIdentifiers

private enum TransferFile: Sendable { case csv, archive, recovery }
private enum ParsedTrainingFile: Sendable {
  case csv([WorkoutSession])
  case archive(TrainingArchive)
}

struct TrainingTransferView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var importing = false
  @State private var exporting = false
  @State private var document = TrainingFileDocument(data: Data())
  @State private var contentType = UTType.json
  @State private var filename = "Sport"
  @State private var preview: TrainingImportPreview?
  @State private var recoveryAvailable = false
  @State private var busy = false
  @State private var error: String?
  @State private var message: String?

  var body: some View {
    List {
      Section {
        Button("Import from Files", systemImage: "square.and.arrow.down") {
          importing = true
        }
        Menu("Export to Files", systemImage: "square.and.arrow.up") {
          Button("Workout History (CSV)", systemImage: "tablecells") { prepare(.csv) }
          Button("Training Backup (JSON)", systemImage: "doc") { prepare(.archive) }
          if recoveryAvailable {
            Button("Before Last Import (JSON)", systemImage: "clock.arrow.circlepath") {
              prepare(.recovery)
            }
          }
        }
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text("Private photos are excluded from exports.")
          if let message { Text(message) }
        }
      }
    }
    .disabled(busy)
    .overlay {
      if busy { ProgressView("Preparing…") }
    }
    .navigationTitle("Import and Export").navigationBarTitleDisplayMode(.inline)
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText]) {
      result in
      switch result {
      case .success(let url): read(url)
      case .failure(let failure):
        if !isCancellation(failure) { error = "Unable to open the selected file." }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: document, contentType: contentType,
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
    .sheet(item: $preview, onDismiss: { Task { await refreshRecovery() } }) { value in
      TrainingImportPreviewView(preview: value) { message = $0 }
    }
    .alert(
      "Unable to Transfer",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
    .task(id: store.historyRevision) { await refreshRecovery() }
  }
  private func isCancellation(_ error: Error) -> Bool {
    (error as NSError).code == NSUserCancelledError
  }
  private func refreshRecovery() async {
    do { recoveryAvailable = try await store.recoveryArchive() != nil } catch {
      self.error = error.localizedDescription
    }
  }
  private func prepare(_ type: TransferFile) {
    guard !busy else { return }
    busy = true
    message = nil
    Task {
      defer { busy = false }
      do {
        let data: Data
        switch type {
        case .archive, .csv:
          let archive = try await store.exportTraining()
          data = try await Task.detached(priority: .userInitiated) {
            try type == .csv ? TrainingCSV.encode(archive.contents.workouts) : archive.encoded()
          }.value
        case .recovery:
          guard let archive = try await store.recoveryArchive() else { throw TrainingError.storage }
          data = try await Task.detached(priority: .userInitiated) { try archive.encoded() }.value
        }
        document = TrainingFileDocument(data: data)
        contentType = type == .csv ? .commaSeparatedText : .json
        filename =
          "Sport-\(type == .recovery ? "before-import-" : "")\(WorkoutClock.dayKey(WorkoutClock.now))"
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
            Text(
              "This restoration replaces your history, schedule, inventory, goals and training settings. An exportable copy of the previous state will be kept. Private photos and iOS permissions are unaffected."
            ).foregroundStyle(.secondary)
          } else {
            Text(
              "This CSV will replace all workout history. Schedule, catalogue, inventory, goals and settings will be kept. A recovery copy will be available. Private photos are excluded."
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
                "\(WorkoutLabels.day(workout.dayKey)) · \(workout.status == .completed ? "Completed" : "Cancelled")"
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
      .sportConfirmation(
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
            ? "Current training data will be replaced. A recovery copy will be kept in Sport and can be exported. Private photos are excluded."
            : "The \(preview.replacedCount) current workouts will be replaced by \(preview.workoutCount) workouts from the CSV. Settings stay unchanged. An exportable recovery copy will be kept in Sport. Private photos are excluded."
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
            ? "Training data restored. The recovery copy is available in Export to Files."
            : "History replaced by \(preview.workoutCount) workouts from the CSV. Settings kept; recovery copy available in Export to Files."
        )
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
