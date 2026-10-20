import Foundation
import SportCore
import SwiftUI
import UniformTypeIdentifiers

private enum ParsedTrainingFile: Sendable {
  case csv([WorkoutSession])
  case archive(TrainingArchive)
}

struct TrainingTransferView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var importing = false
  @State private var exporting = false
  @State private var document = TrainingFileDocument(data: Data())
  @State private var filename = "Sport"
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
          prepareExport()
        }
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          Text(
            "Exports include all workout history, exercises, schedule, inventory, goals and training settings. Private photos are excluded."
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
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText]) {
      result in
      switch result {
      case .success(let url): read(url)
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
        filename = "Sport-\(WorkoutClock.dayKey(WorkoutClock.now))"
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
            LabeledContent(
              "Body Weight Measurements", value: String(preview.incoming.bodyWeights.count))
            Text(
              preview.preservesBodyWeight
                ? "This older backup replaces training history and settings. Your body weight measurements and weight reminder will be kept. A recovery copy will be kept in Sport. Private photos and iOS permissions are unaffected."
                : "This restoration replaces training history, settings, body weight measurements and the weight reminder. A recovery copy will be kept in Sport. Private photos and iOS permissions are unaffected."
            ).foregroundStyle(.secondary)
          } else {
            Text(
              "This CSV will replace all workout history. Schedule, catalogue, inventory, goals and settings will be kept. A recovery copy will be kept in Sport. Private photos are excluded."
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
            ? "Current training data will be replaced. A recovery copy will be kept in Sport. Private photos are excluded."
            : "The \(preview.replacedCount) current workouts will be replaced by \(preview.workoutCount) workouts from the CSV. Settings stay unchanged. A recovery copy will be kept in Sport. Private photos are excluded."
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
            ? "Training data restored. A recovery copy is kept in Sport."
            : "History replaced by \(preview.workoutCount) workouts from the CSV. Settings kept; a recovery copy is kept in Sport."
        )
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
