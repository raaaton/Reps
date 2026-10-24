import AVFoundation
import PhotosUI
import SportCore
import SwiftUI
import UIKit

struct VaultPhotoRoute: Identifiable {
  let id: String
  let session: UUID
}
struct VaultImportRoute: Identifiable {
  let id = UUID()
  let camera: Bool
  let session: UUID
}

struct VaultPrivacySurface<Content: View>: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @ViewBuilder let content: () -> Content
  var body: some View {
    ZStack {
      if vault.gate.covered {
        ContentUnavailableView("Private Vault", systemImage: "lock.fill")
      } else {
        content()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
    .transaction {
      $0.animation = nil
      $0.disablesAnimations = true
    }
  }
}

struct PhotoVaultView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  @State private var section = VaultSection.physique
  @State private var selected: VaultDayRoute?
  @State private var importing: VaultImportRoute?
  @State private var comparing: VaultComparisonRoute?
  @State private var deleteAllSession: UUID?
  @State private var deletingDay: VaultDayDeletion?
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.gate.phase == .unlocked {
          VStack(spacing: 0) {
            Picker("Vault Section", selection: $section) {
              Text("Physique").tag(VaultSection.physique)
              Text("Movements").tag(VaultSection.movements)
            }.pickerStyle(.segmented).padding()
            if section == .physique { photoGallery } else { VaultMovementsView() }
          }
        } else {
          VStack(spacing: 24) {
            ContentUnavailableView(
              "Private Vault Locked", systemImage: "lock.fill",
              description: Text("Unlock with Face ID to view your photos and videos."))
            Button {
              vault.unlock()
            } label: {
              Label(
                vault.gate.phase == .authenticating
                  ? "Unlocking…" : "Unlock with Face ID", systemImage: "faceid")
            }.sportProminentButton().controlSize(.large)
              .disabled(vault.gate.phase == .authenticating || vault.busy)
            Spacer()
          }.padding()
        }
      }
      .navigationTitle("Private Vault").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            vault.lock()
            dismiss()
          }.tint(.white)
        }
        if vault.gate.phase == .unlocked, !vault.gate.covered {
          if section == .physique {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Compare", systemImage: "rectangle.split.2x1") {
                if let session = vault.sessionToken {
                  comparing = VaultComparisonRoute(session: session)
                }
              }.tint(.white).disabled(vault.busy || vault.photos.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
              Menu {
                Button("Import from Photos", systemImage: "photo") { beginImport(camera: false) }
                Button("Take Photo", systemImage: "camera") { beginImport(camera: true) }
              } label: {
                Label("Add Photo", systemImage: "plus")
              }.tint(.white).disabled(vault.busy)
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Lock", systemImage: "lock.fill") { vault.lock() }
              if section == .physique {
                SportDestructiveButton("Delete All Photos", systemImage: "trash") {
                  deleteAllSession = vault.sessionToken
                }
              }
            } label: {
              Label("Options", systemImage: "ellipsis")
            }.tint(.white).disabled(vault.busy)
          }
        }
      }
      .sheet(item: $selected, onDismiss: { vault.clearPreview() }) { route in
        VaultDayView(route: route)
      }
      .sheet(item: $importing) { route in VaultImportView(route: route) }
      .sheet(item: $comparing, onDismiss: { vault.clearComparison() }) { route in
        VaultComparisonView(route: route)
      }
      .sportConfirmation(
        "Delete All Private Photos?",
        isPresented: Binding(
          get: { deleteAllSession != nil }, set: { if !$0 { deleteAllSession = nil } })
      ) {
        Button("Delete", role: .destructive) {
          if let session = deleteAllSession {
            Task { await vault.delete(id: nil, session: session) }
          }
          deleteAllSession = nil
        }
        Button("Cancel", role: .cancel) { deleteAllSession = nil }
      } message: {
        Text(
          "This cannot be undone. Originals in Photos and training data will be kept."
        )
      }
      .sportConfirmation(
        "Delete This Stack?",
        isPresented: Binding(get: { deletingDay != nil }, set: { if !$0 { deletingDay = nil } })
      ) {
        Button("Delete", role: .destructive) {
          if let request = deletingDay {
            Task { await vault.deletePhotos(ids: request.ids, session: request.session) }
          }
          deletingDay = nil
        }
        Button("Cancel", role: .cancel) { deletingDay = nil }
      } message: {
        if let request = deletingDay {
          Text(
            "The \(request.ids.count) private photos from \(WorkoutLabels.day(request.dayKey)) will be permanently deleted from Sport. Originals in Photos will be kept."
          )
        }
      }
      .alert(
        "Unable to Complete Operation",
        isPresented: Binding(
          get: { vault.error != nil && selected == nil && importing == nil && comparing == nil },
          set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          selected = nil
          importing = nil
          comparing = nil
          deleteAllSession = nil
          deletingDay = nil
        }
      }
      .onChange(of: vault.dismissRequest) { _, _ in dismiss() }
    }.interactiveDismissDisabled()
  }
  @ViewBuilder private var photoGallery: some View {
    if vault.photos.isEmpty {
      ContentUnavailableView(
        "No Private Photos", systemImage: "photo",
        description: Text(
          "Add a photo with the + button. It will be encrypted in Sport."))
    } else {
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 16) {
          ForEach(VaultPhotoCollection.days(vault.photos)) { day in
            if let session = vault.sessionToken {
              Button {
                selected = VaultDayRoute(id: day.id, session: session)
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  ZStack {
                    if day.photos.count > 1 {
                      RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                        .padding(.horizontal, 8).offset(y: -8)
                      RoundedRectangle(cornerRadius: 12).fill(.tertiary)
                        .padding(.horizontal, 4).offset(y: -4)
                    }
                    if let photo = day.photos.first {
                      VaultThumbnail(photo: photo, session: session)
                    }
                  }
                  .frame(height: 180).padding(.top, 8)
                  Text(WorkoutLabels.day(day.id)).font(.subheadline).fontWeight(.medium)
                  Text("\(day.photos.count) \(day.photos.count == 1 ? "photo" : "photos")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }.buttonStyle(.plain)
                .contextMenu {
                  SportDestructiveButton("Delete Stack", systemImage: "trash") {
                    deletingDay = VaultDayDeletion(
                      dayKey: day.id, ids: day.photos.map(\.id), session: session)
                  }.disabled(vault.busy)
                } preview: {
                  Label("Private Stack", systemImage: "photo.stack")
                    .font(.headline).padding(24)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                  "\(WorkoutLabels.day(day.id)), \(day.photos.count) photos")
            }
          }
        }.padding()
      }
    }
  }
  private enum VaultSection { case physique, movements }
  private func beginImport(camera: Bool) {
    if let session = vault.sessionToken {
      importing = VaultImportRoute(camera: camera, session: session)
    }
  }
}

private struct VaultDayDeletion {
  let dayKey: String
  let ids: [String]
  let session: UUID
}

struct VaultImportView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultImportRoute
  @State private var day = Date()
  @State private var pose = VaultPhotoPose.frontRelaxed
  @State private var item: PhotosPickerItem?
  @State private var cameraOpen = false
  @State private var cameraError: String?
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session) {
          Form {
            DatePicker(
              "Progress Date", selection: $day, in: ...Date(), displayedComponents: .date)
            Picker("Pose", selection: $pose) {
              ForEach(VaultPhotoPose.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Section {
              if route.camera {
                Button("Take Photo", systemImage: "camera") { requestCamera() }
              } else {
                PhotosPicker(selection: $item, matching: .images, preferredItemEncoding: .current) {
                  Label("Choose a Photo", systemImage: "photo")
                }
              }
              if vault.busy { ProgressView("Encrypting and saving…") }
              if let cameraError { Text(cameraError).foregroundStyle(.secondary) }
            } footer: {
              Text(
                "An encrypted copy will be kept in Sport. Imported photos also stay in Photos. Camera captures are not automatically saved to Photos."
              )
            }
          }.disabled(vault.busy)
        } else {
          ContentUnavailableView("Vault Locked", systemImage: "lock.fill")
        }
      }
      .navigationTitle("Add Photo").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            item = nil
            dismiss()
          }.tint(.white).labelStyle(.iconOnly).disabled(vault.busy)
        }
      }
      .sheet(isPresented: $cameraOpen) {
        VaultPrivacySurface {
          if vault.allows(route.session) {
            VaultCameraView { result in
              cameraOpen = false
              guard vault.allows(route.session) else { return }
              switch result {
              case .success(let data):
                Task {
                  await vault.importCamera(data, day: day, pose: pose, session: route.session)
                  if vault.allows(route.session), vault.error == nil { dismiss() }
                }
              case .failure(let error):
                vault.error = error.localizedDescription
              case nil:
                break
              }
            }.ignoresSafeArea()
          }
        }
      }
      .alert(
        "Unable to Import",
        isPresented: Binding(
          get: { vault.error != nil && !cameraOpen }, set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
      .task(id: item) {
        guard let item, vault.allows(route.session) else { return }
        await vault.importSelection(item, day: day, pose: pose, session: route.session)
        self.item = nil
        if vault.allows(route.session), vault.error == nil { dismiss() }
      }
      .onAppear { selectMissingPose() }
      .onChange(of: day) { _, _ in selectMissingPose() }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          cameraOpen = false
          item = nil
          dismiss()
        }
      }
    }.interactiveDismissDisabled(vault.busy)
  }
  private func selectMissingPose() {
    let dayKey = WorkoutClock.dayKey(Int(day.timeIntervalSince1970 * 1000))
    let used = Set(
      vault.photos.filter { $0.metadata.dayKey == dayKey }.compactMap { $0.metadata.pose })
    pose = VaultPhotoPose.allCases.first { !used.contains($0) } ?? .frontRelaxed
  }
  private func requestCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      cameraError = "Camera unavailable."
      return
    }
    Task {
      let permitted = await AVCaptureDevice.requestAccess(for: .video)
      guard vault.allows(route.session) else { return }
      if permitted {
        cameraOpen = true
      } else {
        cameraError = "Allow camera access in the iOS settings for Sport."
      }
    }
  }
}
