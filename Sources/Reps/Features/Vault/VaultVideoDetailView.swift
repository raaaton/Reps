import AVFoundation
import RepsCore
import SwiftUI

struct VaultVideoDetailView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let videoID: String
  let session: UUID
  @State private var playback: VaultVideoPlayback?
  @State private var rate: Float = 1
  @State private var deleting = false
  @State private var editingDate = false
  @State private var day = Date()
  private var video: VaultVideoEntry? { vault.videos.first { $0.id == videoID } }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(session), let video {
          ScrollView {
            VStack(spacing: 20) {
              if let playback {
                VaultNativeVideoPlayer(playback: playback).frame(height: 360)
                if playback.failed {
                  Text("This private video could not be played.").foregroundStyle(.secondary)
                }
              } else {
                ProgressView().frame(height: 240)
              }
              Picker("Playback Speed", selection: $rate) {
                Text("1×").tag(Float(1))
                Text("0.5×").tag(Float(0.5))
                Text("0.25×").tag(Float(0.25))
              }.pickerStyle(.segmented)
              LabeledContent("Date", value: WorkoutLabels.day(video.metadata.dayKey))
              LabeledContent("Duration", value: VaultVideoLabels.duration(video.metadata.duration))
            }.padding()
          }
        }
      }
      .navigationTitle("Private Video").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            VaultMenuButton(title: "Edit Date", systemImage: "calendar") {
              day = video.flatMap { VaultDates.date($0.metadata.dayKey) } ?? Date()
              playback?.player.pause()
              editingDate = true
            }
            RepsDestructiveButton("Delete Video", systemImage: "trash") {
              playback?.player.pause()
              deleting = true
            }
          } label: {
            Label("Options", systemImage: "ellipsis")
          }.tint(.white).disabled(vault.busy)
        }
      }
      .sheet(isPresented: $editingDate) {
        NavigationStack {
          VaultPrivacySurface {
            if vault.allows(session) {
              Form {
                DatePicker(
                  "Progress Date", selection: $day, in: ...Date(), displayedComponents: .date)
              }
            }
          }
          .navigationTitle("Edit Date").navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel", systemImage: "xmark") { editingDate = false }.tint(.white).disabled(
                vault.busy)
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Save", systemImage: "checkmark") {
                if let video {
                  Task {
                    if await vault.changeVideoDate(video, day: day, session: session) {
                      editingDate = false
                    }
                  }
                }
              }.disabled(vault.busy)
            }
          }.vaultVideoErrorAlert()
        }.interactiveDismissDisabled(vault.busy)
      }
      .repsConfirmation("Delete This Video?", isPresented: $deleting) {
        Button("Delete", role: .destructive) {
          if let video {
            Task {
              stop()
              if await vault.deleteVideo(video, session: session) { dismiss() }
            }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "The private copy will be permanently deleted from Reps. The original in Photos will be kept."
        )
      }
      .task {
        guard let video, vault.allows(session) else { return }
        do { playback = try vault.makeVideoPlayback(video, session: session) } catch {
          vault.error = "This private video could not be opened."
        }
      }
      .onChange(of: rate) { _, value in
        playback?.player.defaultRate = value
        if let player = playback?.player, player.rate != 0 { player.rate = value }
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          stop()
          deleting = false
          editingDate = false
          dismiss()
        }
      }
      .onDisappear { stop() }
      .vaultVideoErrorAlert()
    }
  }
  private func stop() {
    if let playback { vault.releaseVideoPlayback(playback) }
    playback = nil
  }
}
