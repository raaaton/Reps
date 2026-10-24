import RepsCore
import SwiftUI
import UIKit

// One foreground-only path for app-authored feedback. System controls keep their own feedback.
@MainActor
final class RepsHaptics {
  static let shared = RepsHaptics()
  static let preferenceKey = "sport.hapticsEnabled"
  private let selection = UISelectionFeedbackGenerator()
  private let notification = UINotificationFeedbackGenerator()
  private var lastSelection: ContinuousClock.Instant?

  func play(_ event: WorkoutFeedback) {
    guard UserDefaults.standard.object(forKey: Self.preferenceKey) as? Bool ?? true,
      UIApplication.shared.applicationState == .active
    else { return }
    switch event {
    case .selection:
      let now = ContinuousClock.now
      // Scrubbing a dense chart must not turn into a continuous vibration. Never queue taps.
      if let lastSelection, now - lastSelection < .milliseconds(80) { return }
      lastSelection = now
      selection.selectionChanged()
    case .success:
      notification.notificationOccurred(.success)
    }
  }
}

private struct RepsMotion<Value: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @Environment(\.scenePhase) private var scenePhase
  let value: Value

  func body(content: Content) -> some View {
    content.animation(
      reduceMotion || voiceOver || scenePhase != .active ? nil : .smooth(duration: 0.25),
      value: value)
  }
}

extension View {
  // Scope this to discrete content changes, never clocks, text entry or the app's root view.
  func repsAnimation<Value: Equatable>(value: Value) -> some View {
    modifier(RepsMotion(value: value))
  }
}
