import SportCore
import SwiftUI
import UIKit

public struct SportAccentColors {
  public let choice: AccentChoice
  public init(_ choice: AccentChoice) { self.choice = choice }

  public var fill: Color {
    choice.rgb.map { Color(uiColor: Self.color($0)) } ?? Color(uiColor: .systemBlue)
  }
  public var ink: Color {
    choice.rgb.map { Color(uiColor: Self.color($0.ink)) } ?? .white
  }
  public var tint: Color {
    guard let base = choice.rgb else { return Color(uiColor: .systemBlue) }
    return Color(
      uiColor: UIColor { traits in
        let surfaces = [
          UIColor.systemBackground, .systemGroupedBackground, .secondarySystemGroupedBackground,
          .tertiarySystemGroupedBackground,
        ].map { surface in
          let surface = surface.resolvedColor(with: traits)
          var red: CGFloat = 0
          var green: CGFloat = 0
          var blue: CGFloat = 0
          var alpha: CGFloat = 0
          surface.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
          let hex =
            UInt32((red * 255).rounded()) << 16
            | UInt32((green * 255).rounded()) << 8 | UInt32((blue * 255).rounded())
          return AccentRGB(hex: hex)
        }
        // Cover native grouped and ungrouped surfaces, not just a white card.
        let background = surfaces.sorted { $0.luminance < $1.luminance }[
          traits.userInterfaceStyle == .dark ? surfaces.count - 1 : 0]
        let target = traits.accessibilityContrast == .high ? 7.0 : 4.5
        return Self.color(base.readable(on: background, target: target))
      })
  }
  private static func color(_ rgb: AccentRGB) -> UIColor {
    UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
  }
}
