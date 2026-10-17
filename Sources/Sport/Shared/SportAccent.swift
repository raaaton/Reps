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

// Native accent-filled confirmation buttons, with black ink only on the glyph.
struct SportConfirmationButton: View {
  @Environment(\.sportAccent) private var choice
  let title: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: "checkmark")
        .foregroundStyle(.black)
        .accessibilityLabel(title)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .tint(SportAccentColors(choice).fill)
  }
}
