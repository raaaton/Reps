import SportCore
import SportLiveSupport
import SwiftUI

private struct SportAccentKey: EnvironmentKey {
  static let defaultValue = AccentChoice.icyCyan
}
extension EnvironmentValues {
  var sportAccent: AccentChoice {
    get { self[SportAccentKey.self] }
    set { self[SportAccentKey.self] = newValue }
  }
}

private struct SportProminentButton: ViewModifier {
  @Environment(\.sportAccent) private var choice
  func body(content: Content) -> some View {
    let colors = SportAccentColors(choice)
    content.buttonStyle(.borderedProminent).tint(colors.fill).foregroundStyle(colors.ink)
  }
}
extension View {
  func sportProminentButton() -> some View { modifier(SportProminentButton()) }
}

// Keep confirmation glyphs dark inside native accent-filled toolbar actions.
struct SportConfirmationLabel: View {
  let title: String
  var body: some View {
    Image(systemName: "checkmark")
      .foregroundStyle(.black).tint(.black).accessibilityLabel(title)
  }
}
