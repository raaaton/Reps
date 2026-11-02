import Foundation

// The same centered aspect-fill frame used by the live camera preview.
public struct VaultPhotoFrame: Sendable, Equatable {
  public let x: Int
  public let y: Int
  public let width: Int
  public let height: Int
  public init(x: Int, y: Int, width: Int, height: Int) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
  public static func crop(width: Int, height: Int, aspect: Double) -> Self? {
    guard width > 0, height > 0, width <= 100_000, height <= 100_000,
      aspect.isFinite, aspect > 0
    else { return nil }
    let w: Int
    let h: Int
    if Double(width) / Double(height) > aspect {
      w = max(1, min(width, Int((Double(height) * aspect).rounded(.down))))
      h = height
    } else {
      w = width
      h = max(1, min(height, Int((Double(width) / aspect).rounded(.down))))
    }
    return Self(x: (width - w) / 2, y: (height - h) / 2, width: w, height: h)
  }
}
