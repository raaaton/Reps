import SportCore
import SwiftUI

extension VaultPhotoPose {
  var label: String {
    switch self {
    case .frontRelaxed: "Front Relaxed"
    case .frontFlexed: "Front Flexed"
    case .back: "Back"
    case .other: "Other"
    }
  }
}

struct VaultDayRoute: Identifiable {
  let id: String
  let session: UUID
}

struct VaultThumbnail: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  let photo: VaultPhotoEntry
  let session: UUID
  var body: some View {
    GeometryReader { geometry in
      if let image = vault.thumbnails[photo.id] {
        Image(uiImage: image).resizable().scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height).clipped()
      } else {
        Rectangle().fill(.quaternary).overlay { ProgressView() }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityHidden(true)
    .task(id: photo.id) {
      if vault.allows(session) { await vault.loadThumbnail(id: photo.id) }
    }
  }
}

struct VaultDayView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultDayRoute
  @State private var selected: VaultPhotoRoute?
  @State private var deleting: VaultPhotoRoute?
  private var photos: [VaultPhotoEntry] {
    VaultPhotoCollection.days(vault.photos).first { $0.id == route.id }?.photos ?? []
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session) {
          if photos.isEmpty {
            ContentUnavailableView("No Photos on This Date", systemImage: "photo")
          } else {
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 20) {
                ForEach(photos) { photo in
                  Button {
                    selected = VaultPhotoRoute(id: photo.id, session: route.session)
                  } label: {
                    VStack(alignment: .leading, spacing: 8) {
                      VaultThumbnail(photo: photo, session: route.session).frame(height: 220)
                      Text(photo.metadata.pose?.label ?? "Pose not assigned")
                        .font(.subheadline).foregroundStyle(.primary)
                    }
                  }.buttonStyle(.plain)
                    .contextMenu {
                      SportDestructiveButton("Delete Photo", systemImage: "trash") {
                        deleting = VaultPhotoRoute(id: photo.id, session: route.session)
                      }.disabled(vault.busy)
                    } preview: {
                      Label("Private Photo", systemImage: "photo")
                        .font(.headline).padding(24)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(photo.metadata.pose?.label ?? "Unassigned Photo")
                    .accessibilityHint("Open, edit pose or compare")
                }
              }.padding()
            }
          }
        } else {
          ContentUnavailableView("Vault Locked", systemImage: "lock.fill")
        }
      }
      .navigationTitle(vault.gate.covered ? "Private Photos" : WorkoutLabels.day(route.id))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
      }
      .sheet(item: $selected, onDismiss: { vault.clearPreview() }) { VaultPhotoDetail(route: $0) }
      .sportConfirmation(
        "Delete This Private Photo?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
      ) {
        Button("Delete", role: .destructive) {
          if let photo = deleting {
            Task { await vault.delete(id: photo.id, session: photo.session) }
          }
          deleting = nil
        }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: {
        Text(
          "The Sport copy will be permanently deleted. The original in Photos will be kept.")
      }
      .alert(
        "Unable to Complete Operation",
        isPresented: Binding(
          get: { vault.error != nil && selected == nil }, set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          selected = nil
          deleting = nil
          dismiss()
        }
      }
    }
  }
}
