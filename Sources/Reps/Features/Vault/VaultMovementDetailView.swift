import PhotosUI
import RepsCore
import SwiftUI

private struct VaultVideoRoute: Identifiable {
  let id: String
  let session: UUID
}

struct VaultMovementDetailView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let movementID: String
  let session: UUID
  @State private var importing = false
  @State private var comparing = false
  @State private var selectedDay: VaultDayRoute?
  private var movement: VaultMovementEntry? { vault.movements.first { $0.id == movementID } }
  private var videos: [VaultVideoEntry] {
    VaultMovementCollection.videos(vault.videos, movementID: movementID)
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(session), movement != nil {
          if videos.isEmpty {
            ContentUnavailableView(
              "No Videos", systemImage: "video",
              description: Text("Import a video to follow your movement technique over time."))
          } else {
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 16) {
                ForEach(VaultVideoDay.grouped(videos, movementID: movementID)) { day in
                  Button {
                    selectedDay = VaultDayRoute(id: day.id, session: session)
                  } label: {
                    VStack(alignment: .leading, spacing: 6) {
                      ZStack {
                        if day.videos.count > 1 {
                          RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                            .padding(.horizontal, 8).offset(y: -8)
                          RoundedRectangle(cornerRadius: 12).fill(.tertiary)
                            .padding(.horizontal, 4).offset(y: -4)
                        }
                        if let video = day.videos.first {
                          VaultVideoThumbnail(entry: video, session: session)
                        }
                      }.frame(height: 180).padding(.top, 8)
                      Text(WorkoutLabels.day(day.id)).font(.subheadline).fontWeight(.medium)
                      Text("\(day.videos.count) \(day.videos.count == 1 ? "video" : "videos")")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                  }.buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(WorkoutLabels.day(day.id)), \(day.videos.count) videos")
                }
              }.padding()
            }
          }
        }
      }
      .navigationTitle(
        vault.gate.covered || !vault.allows(session)
          ? "Movement" : (movement?.metadata.name ?? "Movement")
      ).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Compare Videos", systemImage: "rectangle.split.2x1") { comparing = true }
            .tint(.white).disabled(videos.count < 2 || vault.busy)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Import Video", systemImage: "plus") { importing = true }
            .tint(.white).disabled(vault.busy || !VaultVideoFeature.importsEnabled)
        }
      }
      .sheet(isPresented: $importing, onDismiss: { vault.clearVideoImport() }) {
        if let movement { VaultVideoImportView(movement: movement, session: session) }
      }
      .sheet(isPresented: $comparing) {
        VaultVideoComparisonView(movementID: movementID, session: session)
      }
      .sheet(item: $selectedDay) { route in
        VaultVideoDayView(movementID: movementID, route: route)
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          importing = false
          comparing = false
          selectedDay = nil
          dismiss()
        }
      }
    }
  }
}

enum VaultVideoFeature {
  static let importsEnabled = true
  static let silentImportsEnabled = true
}

enum VaultVideoLabels {
  static func duration(_ seconds: Double) -> String {
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", value / 60, value % 60)
  }
}

struct VaultVideoThumbnail: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  let entry: VaultVideoEntry
  let session: UUID
  var body: some View {
    ZStack {
      Color(uiColor: .secondarySystemBackground)
      if vault.allows(session), let image = vault.videoThumbnails[entry.id] {
        Image(uiImage: image).resizable().scaledToFit()
      } else {
        Image(systemName: "video").foregroundStyle(.secondary)
      }
    }.clipShape(RoundedRectangle(cornerRadius: 8))
      .task(id: entry.id) { await vault.loadVideoThumbnail(entry, session: session) }
      .accessibilityHidden(true)
  }
}

private struct VaultVideoImportView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let movement: VaultMovementEntry
  let session: UUID
  @State private var item: PhotosPickerItem?
  @State private var day = Date()
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(session) {
          Form {
            LabeledContent("Movement", value: movement.metadata.name)
            if let staging = vault.videoStaging {
              DatePicker(
                "Progress Date", selection: $day, in: ...Date(), displayedComponents: .date)
              LabeledContent("Duration", value: VaultVideoLabels.duration(staging.duration))
              LabeledContent(
                "Size",
                value: ByteCountFormatter.string(
                  fromByteCount: Int64(staging.byteCount), countStyle: .file))
            }
            Section {
              let pickerTitle =
                vault.videoStaging == nil ? "Choose a Video" : "Choose Another Video"
              PhotosPicker(selection: $item, matching: .videos, preferredItemEncoding: .current) {
                Label(
                  pickerTitle,
                  systemImage: "video.badge.plus")
              }
              if vault.busy { ProgressView("Encrypting video…") }
            } footer: {
              Text(
                "Reps keeps an encrypted copy. The original stays in Photos. Limit: 5 minutes and 500 MiB."
              )
            }
          }.disabled(vault.busy)
        }
      }
      .navigationTitle("Import Video").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") {
            vault.clearVideoImport()
            dismiss()
          }.tint(.white).disabled(vault.busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", systemImage: "checkmark") {
            Task {
              if await vault.importStagedVideo(movement: movement, day: day, session: session) {
                dismiss()
              }
            }
          }.disabled(vault.videoStaging == nil || vault.busy)
        }
      }
      .task(id: item) {
        guard let item else { return }
        await vault.stageVideo(item, session: session)
        if vault.allows(session), let staging = vault.videoStaging { day = staging.date }
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          item = nil
          dismiss()
        }
      }
      .vaultVideoErrorAlert()
    }.interactiveDismissDisabled(vault.busy)
  }
}
