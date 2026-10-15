import Foundation

public enum AccentChoice: String, CaseIterable, Sendable {
  case icyCyan
  public static func resolve(_ value: String?) -> Self { .icyCyan }
  public var rgb: AccentRGB? { AccentRGB(hex: 0x4DD9E8) }

}

public struct AccentRGB: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public init(hex: UInt32) {
    red = Double((hex >> 16) & 255) / 255
    green = Double((hex >> 8) & 255) / 255
    blue = Double(hex & 255) / 255
  }
  private init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
  public var luminance: Double {
    func linear(_ value: Double) -> Double {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }
  public var ink: Self {
    let black = Self(hex: 0)
    let white = Self(hex: 0xFFFFFF)
    return contrast(with: black) >= contrast(with: white) ? black : white
  }
  public func contrast(with other: Self) -> Double {
    (max(luminance, other.luminance) + 0.05) / (min(luminance, other.luminance) + 0.05)
  }
  public func readable(on background: Self, target: Double) -> Self {
    // Preserve the requested swatch. Only foreground tints get a readable variant.
    if contrast(with: background) >= target { return self }
    let endpoint = background.ink
    var low = 0.0
    var high = 1.0
    func mixed(_ amount: Double) -> Self {
      Self(
        red: red + (endpoint.red - red) * amount,
        green: green + (endpoint.green - green) * amount,
        blue: blue + (endpoint.blue - blue) * amount)
    }
    // A small margin avoids rounding below the requested contrast threshold.
    let goal = min(target + 0.01, endpoint.contrast(with: background))
    for _ in 0..<40 {
      let middle = (low + high) / 2
      if mixed(middle).contrast(with: background) >= goal { high = middle } else { low = middle }
    }
    return mixed(high)
  }
}
