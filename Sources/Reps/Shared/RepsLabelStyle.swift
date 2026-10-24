import RepsCore
import SportLiveSupport
import SwiftUI

// Content labels keep their native text and layout; only their symbol receives the accent.
// Apply inside each tab's navigation stack, so the system tab bar keeps its native styling.
struct RepsLabelStyle: LabelStyle {
  @Environment(\.repsAccent) private var choice

  func makeBody(configuration: Configuration) -> some View {
    Label {
      configuration.title
    } icon: {
      configuration.icon.foregroundStyle(RepsAccentColors(choice).tint)
    }
    .labelStyle(.titleAndIcon)
  }
}
