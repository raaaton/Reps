import RepsCore
import SportLiveSupport
import SwiftUI

private struct RepsAccentKey: EnvironmentKey {
  static let defaultValue = AccentChoice.icyCyan
}
extension EnvironmentValues {
  var repsAccent: AccentChoice {
    get { self[RepsAccentKey.self] }
    set { self[RepsAccentKey.self] = newValue }
  }
}

private struct RepsProminentButton: ViewModifier {
  @Environment(\.repsAccent) private var choice
  func body(content: Content) -> some View {
    let colors = RepsAccentColors(choice)
    content.buttonStyle(.borderedProminent).tint(colors.fill).foregroundStyle(colors.ink)
      .labelStyle(.titleAndIcon)
  }
}
extension View {
  func repsProminentButton() -> some View { modifier(RepsProminentButton()) }
}

// Native accent-filled confirmation buttons, with black ink only on the glyph.
struct RepsConfirmationButton: View {
  @Environment(\.repsAccent) private var choice
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
    .tint(RepsAccentColors(choice).fill)
  }
}
