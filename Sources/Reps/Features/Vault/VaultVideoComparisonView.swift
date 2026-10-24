import AVFoundation
import RepsCore
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
  @Published private(set) var seeking = false
  @Published private(set) var preparing = false
  @Published private(set) var message: String?
  private var revision = UUID()
  private var operation: Task<Void, Never>?
  private var endObservers: [NSObjectProtocol] = []
  private var alignedStart: (Double, Double)?
  private var atEnd = false
  init(first: VaultVideoPlayback, second: VaultVideoPlayback) {
    self.first = first
    self.second = second
    for playback in [first, second] {
      if let item = playback.player.currentItem {
        endObservers.append(
          NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
          ) { [weak self] _ in
            Task { @MainActor [weak self] in
              guard let self, self.linked else { return }
              self.pause()
              self.atEnd = true
            }
          })
        endObservers.append(
          NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main
          ) { [weak self] _ in
            Task { @MainActor [weak self] in
              guard let self, self.linked else { return }
              self.pause()
              self.message = "Playback paused while buffering. Tap Play Both to resume together."
            }
          })
      }
    }
  }
  func pause() {
    revision = UUID()
    operation?.cancel()
    operation = nil
    preparing = false
    seeking = false
    for playback in [first, second] {
      playback.player.pause()
      playback.player.cancelPendingPrerolls()
    }
  }
  private func ready(_ playback: VaultVideoPlayback, request: UUID) async throws {
    for _ in 0..<200 {
      try Task.checkCancellation()
      guard revision == request, !playback.privacyPaused, playback.player.currentItem != nil,
        !playback.failed
      else {
        throw VaultFailure.locked
      }
      if playback.player.currentItem?.status == .readyToPlay { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    throw VaultVideoFailure.invalid
  }
  func playBoth(firstDuration: Double, secondDuration: Double) {
    pause()
    let request = revision
    let privacy = (first.privacyRevision, second.privacyRevision)
    preparing = true
    message = nil
    operation = Task { [weak self] in
      guard let self else { return }
      let timeout = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(10)) } catch { return }
        guard let self, self.revision == request, self.preparing else { return }
        self.pause()
        self.message = "The videos took too long to prepare. Try again."
      }
      defer { timeout.cancel() }
      do {
        try await ready(first, request: request)
        try await ready(second, request: request)
        if atEnd, let start = alignedStart {
          guard
            await first.player.seek(
              to: CMTime(seconds: start.0, preferredTimescale: 600_000), toleranceBefore: .zero,
              toleranceAfter: .zero),
            revision == request,
            await second.player.seek(
              to: CMTime(seconds: start.1, preferredTimescale: 600_000), toleranceBefore: .zero,
              toleranceAfter: .zero)
          else { throw VaultVideoFailure.invalid }
        }
        guard revision == request else { return }
        let a = first.player.currentTime().seconds
        let b = second.player.currentTime().seconds
        let remaining = VaultVideoAlignment(first: a, second: b).remaining(
          firstDuration: firstDuration, secondDuration: secondDuration)
        guard remaining > 0.02 else { throw VaultVideoFailure.invalid }
        alignedStart = (a, b)
        atEnd = false
        for (playback, start) in [(first, a), (second, b)] {
          playback.player.currentItem?.forwardPlaybackEndTime = CMTime(
            seconds: start + remaining, preferredTimescale: 600_000)
          playback.player.automaticallyWaitsToMinimizeStalling = false
        }
        async let aReady = first.player.preroll(atRate: speed)
        async let bReady = second.player.preroll(atRate: speed)
        let prepared = await (aReady, bReady)
        try Task.checkCancellation()
        guard revision == request else { return }
        guard prepared.0, prepared.1, !first.privacyPaused, !second.privacyPaused,
          privacy.0 == first.privacyRevision, privacy.1 == second.privacyRevision
        else {
          throw VaultVideoFailure.invalid
        }
        let host = CMTimeAdd(
          CMClockGetTime(CMClockGetHostTimeClock()),
          CMTime(seconds: 0.2, preferredTimescale: 1_000_000_000))
        first.player.setRate(
          speed, time: CMTime(seconds: a, preferredTimescale: 600_000), atHostTime: host)
        second.player.setRate(
          speed, time: CMTime(seconds: b, preferredTimescale: 600_000), atHostTime: host)
        preparing = false
      } catch {
        guard revision == request else { return }
        pause()
        message = "The videos could not start together. Try again."
      }
    }
  }
  func seek(_ playback: VaultVideoPlayback, to seconds: Double) async {
    pause()
    let request = revision
    seeking = true
    atEnd = false
    alignedStart = nil
    for item in [first.player.currentItem, second.player.currentItem] {
      item?.forwardPlaybackEndTime = .invalid
    }
    _ = await playback.player.seek(
      to: CMTime(seconds: seconds, preferredTimescale: 600_000),
      toleranceBefore: .zero, toleranceAfter: .zero)
    guard revision == request else { return }
    seeking = false
  }
  func play(_ playback: VaultVideoPlayback) {
    guard !playback.privacyPaused else { return }
    if linked {
      pause()
    } else {
      revision = UUID()
      operation?.cancel()
      operation = nil
      preparing = false
      playback.player.cancelPendingPrerolls()
    }
    playback.player.currentItem?.forwardPlaybackEndTime = .invalid
    playback.player.playImmediately(atRate: speed)
  }
  func close() {
    pause()
    for observer in endObservers { NotificationCenter.default.removeObserver(observer) }
    endObservers = []
  }
}

private struct VaultVideoPairContent: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  let firstEntry: VaultVideoEntry
  let secondEntry: VaultVideoEntry
  @StateObject private var control: VaultVideoPairController
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
        if control.preparing { ProgressView("Preparing both videos…") }
        if let message = control.message {
          Text(message).font(.footnote).foregroundStyle(.secondary)
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
          control: control)
        VaultVideoScrubber(
          title: "Second Video", playback: control.second, duration: secondEntry.metadata.duration,
          control: control)
      }.padding()
    }
    .onChange(of: vault.gate.covered) { _, covered in if covered { control.pause() } }
    .onDisappear { control.close() }
  }
}

private struct VaultVideoScrubber: View {
  let title: String
  @ObservedObject var playback: VaultVideoPlayback
  let duration: Double
  @ObservedObject var control: VaultVideoPairController
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
            control.play(playback)
          }
          Button("Pause", systemImage: "pause.fill") { playback.player.pause() }
        }.disabled(control.seeking)
      }
    }
    .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
      if !dragging, !control.seeking {
        let seconds = playback.player.currentTime().seconds
        if seconds.isFinite { position = min(duration, max(0, seconds)) }
      }
    }
  }
}
