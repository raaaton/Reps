import AVFoundation
import SportCore
import SwiftUI

struct VaultVideoComparisonView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let movementID: String
  let session: UUID
  @State private var firstID = ""
  @State private var secondID = ""
  @State private var first: VaultVideoPlayback?
  @State private var second: VaultVideoPlayback?
  @State private var showingPair = false
  private var videos: [VaultVideoEntry] {
    VaultMovementCollection.videos(vault.videos, movementID: movementID)
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(session) {
          if showingPair, let first, let second,
            let a = videos.first(where: { $0.id == firstID }),
            let b = videos.first(where: { $0.id == secondID })
          {
            VaultVideoPairContent(first: first, second: second, firstEntry: a, secondEntry: b)
          } else {
            Form {
              Picker("First Video", selection: $firstID) {
                ForEach(videos) { Text(label($0)).tag($0.id) }
              }
              Picker("Second Video", selection: $secondID) {
                ForEach(videos.filter { $0.id != firstID }) { Text(label($0)).tag($0.id) }
              }
              Button("Compare Videos", systemImage: "rectangle.split.2x1") { openPair() }
                .disabled(firstID.isEmpty || secondID.isEmpty || firstID == secondID)
            }
          }
        }
      }
      .navigationTitle("Compare Videos").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            stop()
            dismiss()
          }.tint(.white)
        }
        if showingPair {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Choose Videos", systemImage: "arrow.triangle.2.circlepath") { stop() }.tint(
              .white)
          }
        }
      }
      .onAppear {
        firstID = videos.first?.id ?? ""
        secondID = videos.dropFirst().first?.id ?? ""
      }
      .onChange(of: firstID) { _, value in
        if secondID == value { secondID = videos.first { $0.id != value }?.id ?? "" }
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          stop()
          dismiss()
        }
      }
      .onDisappear { stop() }
      .vaultVideoErrorAlert()
    }
  }
  private func label(_ video: VaultVideoEntry) -> String {
    let sameDay = videos.filter { $0.metadata.dayKey == video.metadata.dayKey }
    let index = (sameDay.firstIndex(of: video) ?? 0) + 1
    return
      "\(WorkoutLabels.day(video.metadata.dayKey)) · \(VaultVideoLabels.duration(video.metadata.duration))\(sameDay.count > 1 ? " · \(index)" : "")"
  }
  private func openPair() {
    guard let a = videos.first(where: { $0.id == firstID }),
      let b = videos.first(where: { $0.id == secondID }), a.id != b.id
    else { return }
    do {
      first = try vault.makeVideoPlayback(a, session: session)
      second = try vault.makeVideoPlayback(b, session: session)
      first?.player.isMuted = true
      second?.player.isMuted = true
      showingPair = true
    } catch {
      stop()
      vault.error = "These private videos could not be opened."
    }
  }
  private func stop() {
    if let first { vault.releaseVideoPlayback(first) }
    if let second { vault.releaseVideoPlayback(second) }
    first = nil
    second = nil
    showingPair = false
  }
}

@MainActor
final class VaultVideoPairController: ObservableObject {
  let first: VaultVideoPlayback
  let second: VaultVideoPlayback
  @Published var linked = true { didSet { pause() } }
  @Published var speed: Float = 1 { didSet { pause() } }
  @Published var seeking = false
  private var endObservers: [NSObjectProtocol] = []
  private var boundaryObservers: [(AVPlayer, Any)] = []
  init(first: VaultVideoPlayback, second: VaultVideoPlayback) {
    self.first = first
    self.second = second
    for playback in [first, second] {
      if let item = playback.player.currentItem {
        endObservers.append(
          NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
          ) { [weak self] _ in
            Task { @MainActor [weak self] in if self?.linked == true { self?.pause() } }
          })
      }
    }
  }
  func pause() {
    first.player.pause()
    second.player.pause()
    for (player, token) in boundaryObservers { player.removeTimeObserver(token) }
    boundaryObservers = []
  }
  func playBoth(firstDuration: Double, secondDuration: Double) {
    pause()
    guard !seeking, first.player.currentItem?.status == .readyToPlay,
      second.player.currentItem?.status == .readyToPlay
    else { return }
    let a = first.player.currentTime().seconds
    let b = second.player.currentTime().seconds
    let remaining = VaultVideoAlignment(first: a, second: b).remaining(
      firstDuration: firstDuration, secondDuration: secondDuration)
    guard remaining > 0 else { return }
    for (player, start) in [(first.player, a), (second.player, b)] {
      let boundary = CMTime(seconds: start + remaining, preferredTimescale: 600_000)
      let token = player.addBoundaryTimeObserver(forTimes: [NSValue(time: boundary)], queue: .main)
      { [weak self] in
        Task { @MainActor [weak self] in self?.pause() }
      }
      boundaryObservers.append((player, token))
    }
    let host = CMTimeAdd(
      CMClockGetTime(CMClockGetHostTimeClock()),
      CMTime(seconds: 0.15, preferredTimescale: 1_000_000_000))
    for player in [first.player, second.player] {
      player.automaticallyWaitsToMinimizeStalling = false
      player.setRate(speed, time: player.currentTime(), atHostTime: host)
    }
  }
  func seek(_ playback: VaultVideoPlayback, to seconds: Double) async {
    pause()
    seeking = true
    _ = await playback.player.seek(
      to: CMTime(seconds: seconds, preferredTimescale: 600_000), toleranceBefore: .zero,
      toleranceAfter: .zero)
    seeking = false
  }
  func close() {
    pause()
    for observer in endObservers { NotificationCenter.default.removeObserver(observer) }
    endObservers = []
  }
}

private struct VaultVideoPairContent: View {
  let firstEntry: VaultVideoEntry
  let secondEntry: VaultVideoEntry
  @StateObject private var control: VaultVideoPairController
  @State private var tick = 0
  init(
    first: VaultVideoPlayback, second: VaultVideoPlayback, firstEntry: VaultVideoEntry,
    secondEntry: VaultVideoEntry
  ) {
    self.firstEntry = firstEntry
    self.secondEntry = secondEntry
    _control = StateObject(wrappedValue: VaultVideoPairController(first: first, second: second))
  }
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        HStack(alignment: .top, spacing: 8) {
          VStack {
            Text(WorkoutLabels.day(firstEntry.metadata.dayKey)).font(.subheadline)
            VaultNativeVideoPlayer(playback: control.first, controls: false).frame(height: 260)
          }.frame(maxWidth: .infinity)
          VStack {
            Text(WorkoutLabels.day(secondEntry.metadata.dayKey)).font(.subheadline)
            VaultNativeVideoPlayer(playback: control.second, controls: false).frame(height: 260)
          }.frame(maxWidth: .infinity)
        }
        if control.first.failed || control.second.failed {
          Text("A private video could not be played.").foregroundStyle(.secondary)
        }
        Toggle("Link Playback", isOn: $control.linked)
        Picker("Playback Speed", selection: $control.speed) {
          Text("1×").tag(Float(1))
          Text("0.5×").tag(Float(0.5))
          Text("0.25×").tag(Float(0.25))
        }.pickerStyle(.segmented)
        if control.linked {
          HStack {
            Button("Play Both", systemImage: "play.fill") {
              control.playBoth(
                firstDuration: firstEntry.metadata.duration,
                secondDuration: secondEntry.metadata.duration)
            }
            Button("Pause Both", systemImage: "pause.fill") { control.pause() }
          }.disabled(control.seeking)
        }
        VaultVideoScrubber(
          title: "First Video", playback: control.first, duration: firstEntry.metadata.duration,
          control: control, tick: tick)
        VaultVideoScrubber(
          title: "Second Video", playback: control.second, duration: secondEntry.metadata.duration,
          control: control, tick: tick)
      }.padding()
    }
    .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in tick &+= 1 }
    .onDisappear { control.close() }
  }
}

private struct VaultVideoScrubber: View {
  let title: String
  @ObservedObject var playback: VaultVideoPlayback
  let duration: Double
  @ObservedObject var control: VaultVideoPairController
  let tick: Int
  @State private var position = 0.0
  @State private var dragging = false
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      Slider(
        value: $position, in: 0...duration,
        onEditingChanged: { editing in
          dragging = editing
          if editing {
            control.pause()
          } else {
            Task { await control.seek(playback, to: position) }
          }
        }
      ).accessibilityLabel("\(title) position").accessibilityValue(
        VaultVideoLabels.duration(position))
      Text("\(VaultVideoLabels.duration(position)) / \(VaultVideoLabels.duration(duration))").font(
        .caption.monospacedDigit()
      ).foregroundStyle(.secondary)
      if !control.linked {
        HStack {
          Button("Play", systemImage: "play.fill") {
            playback.player.playImmediately(atRate: control.speed)
          }
          Button("Pause", systemImage: "pause.fill") { playback.player.pause() }
        }.disabled(control.seeking)
      }
    }
    .onChange(of: tick) { _, _ in
      if !dragging, !control.seeking {
        let seconds = playback.player.currentTime().seconds
        if seconds.isFinite { position = min(duration, max(0, seconds)) }
      }
    }
  }
}
