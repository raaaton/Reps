import RepsCore
import SwiftUI

struct VaultVideoDayView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let movementID: String
  let route: VaultDayRoute
  @State private var selected: VaultVideoEntry?
  @State private var deleting: VaultVideoEntry?
  private var videos: [VaultVideoEntry] {
    VaultMovementCollection.videos(vault.videos, movementID: movementID)
      .filter { $0.metadata.dayKey == route.id }
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session) {
          if videos.isEmpty {
            ContentUnavailableView("No Videos on This Date", systemImage: "video")
          } else {
            List(videos) { video in
              Button {
                selected = video
              } label: {
                HStack(spacing: 12) {
                  VaultVideoThumbnail(entry: video, session: route.session).frame(
                    width: 80, height: 80)
                  Text(VaultVideoLabels.duration(video.metadata.duration)).foregroundStyle(.primary)
                  Spacer()
                  Image(systemName: "play.circle").foregroundStyle(.tint)
                }
              }.buttonStyle(.plain)
                .accessibilityLabel(
                  "Video \((videos.firstIndex(of: video) ?? 0) + 1), \(VaultVideoLabels.duration(video.metadata.duration))"
                )
                .accessibilityHint("Play private video")
                .contextMenu {
                  RepsDestructiveButton("Delete Video", systemImage: "trash") { deleting = video }
                    .disabled(vault.busy)
                } preview: {
                  Label("Private Video", systemImage: "video").font(.headline).padding(24)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button("Delete", systemImage: "trash", role: .destructive) { deleting = video }
                    .tint(.red)
                    .disabled(vault.busy)
                }
            }
          }
        }
      }
      .navigationTitle(vault.gate.covered ? "Private Videos" : WorkoutLabels.day(route.id))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
      }
      .sheet(item: $selected) { VaultVideoDetailView(videoID: $0.id, session: route.session) }
      .repsConfirmation(
        "Delete This Private Video?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
      ) {
        Button("Delete", role: .destructive) {
          if let entry = deleting {
            Task { _ = await vault.deleteVideo(entry, session: route.session) }
          }
          deleting = nil
        }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: {
        Text("The Reps copy will be permanently deleted. The original in Photos will be kept.")
      }
      .vaultVideoErrorAlert()
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
