import AVFoundation
import AVKit
import SportCore
import SwiftUI

@MainActor
final class VaultVideoPlayback: ObservableObject, Identifiable {
  let id = UUID()
  let player: AVPlayer
  let asset: AVURLAsset
  private let loader: VaultVideoResourceLoader
  @Published private(set) var failed = false
  private var observation: NSKeyValueObservation?
  private var closed = false
  private(set) var privacyPaused = false
  private(set) var privacyRevision = UUID()
  init(reader: VaultVideoReader, byteCount: Int, type: String) {
    loader = VaultVideoResourceLoader(reader: reader, total: byteCount, type: type)
    asset = AVURLAsset(url: URL(string: "sport-vault-video://local/\(id.uuidString)")!)
    asset.resourceLoader.setDelegate(loader, queue: .main)
    player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
    player.isMuted = true
    player.allowsExternalPlayback = false
    player.preventsDisplaySleepDuringVideoPlayback = false
    observation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
      let failed = item.status == .failed
      Task { @MainActor [weak self] in self?.failed = failed }
    }
  }
  func cover() {
    privacyRevision = UUID()
    privacyPaused = true
    player.pause()
    player.cancelPendingPrerolls()
  }
  func foreground() { if !closed { privacyPaused = false } }
  func stop() {
    guard !closed else { return }
    closed = true
    privacyPaused = true
    player.pause()
    player.replaceCurrentItem(with: nil)
    observation = nil
    asset.cancelLoading()
    asset.resourceLoader.setDelegate(nil, queue: nil)
    loader.invalidate()
  }
}

struct VaultNativeVideoPlayer: UIViewControllerRepresentable {
  @ObservedObject var playback: VaultVideoPlayback
  var controls = true
  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = playback.player
    controller.videoGravity = .resizeAspect
    controller.allowsPictureInPicturePlayback = false
    controller.canStartPictureInPictureAutomaticallyFromInline = false
    controller.showsPlaybackControls = controls
    return controller
  }
  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    if controller.player !== playback.player { controller.player = playback.player }
    if controller.showsPlaybackControls != controls { controller.showsPlaybackControls = controls }
  }
  static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
    controller.player?.pause()
    controller.player = nil
  }
}
