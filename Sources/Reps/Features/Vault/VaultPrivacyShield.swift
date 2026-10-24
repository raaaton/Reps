import SwiftUI
import UIKit

// A non-key, noninteractive window also covers AVKit's native full-screen presentation
// and navigation bars in app-switcher snapshots. It never presents or dismisses a controller.
@MainActor
final class VaultPrivacyShield {
  static let shared = VaultPrivacyShield()
  private var windows: [UIWindow] = []
  func show() {
    guard windows.isEmpty else { return }
    for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
      let window = UIWindow(windowScene: scene)
      window.windowLevel = .normal + 1
      window.isUserInteractionEnabled = false
      let controller = UIHostingController(
        rootView:
          ContentUnavailableView("Private Vault", systemImage: "lock.fill")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(uiColor: .systemBackground))
          .accessibilityHidden(true))
      window.rootViewController = controller
      window.isHidden = false
      windows.append(window)
    }
  }
  func hide() {
    for window in windows {
      window.isHidden = true
      window.rootViewController = nil
    }
    windows = []
  }
}
