import SportCore
import SportLiveSupport
import SwiftUI

// Content labels keep their native text and layout; only their symbol receives the accent.
// Apply inside each tab's navigation stack, so the system tab bar keeps its native styling.
struct SportLabelStyle: LabelStyle {
  @Environment(\.sportAccent) private var choice

  func makeBody(configuration: Configuration) -> some View {
    Label {
      configuration.title
    } icon: {
      configuration.icon.foregroundStyle(SportAccentColors(choice).tint)
    }
    .labelStyle(.titleAndIcon)
  }
}
