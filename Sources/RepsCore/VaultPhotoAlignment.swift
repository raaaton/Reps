import Foundation

public struct VaultAlignmentImage: Sendable {
  public let width: Int
  public let height: Int
  public let pixels: [UInt8]

  public init(width: Int, height: Int, pixels: [UInt8]) {
    self.width = width
    self.height = height
    self.pixels = pixels
  }
}

public struct VaultAlignmentPoint: Equatable, Sendable {
  public let x: Double
  public let y: Double
}

public struct VaultAlignmentRect: Codable, Equatable, Sendable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

/// A similarity transform in top-left normalized image coordinates. Rotation is
/// clockwise visually and uniform in physical pixels, including non-square images.
public struct VaultAlignmentTransform: Equatable, Sendable {
  public let rotationRadians: Double
  public let scale: Double
  public let translationX: Double
  public let translationY: Double

  public init(
    rotationRadians: Double = 0, scale: Double = 1,
    translationX: Double = 0, translationY: Double = 0
  ) {
    self.rotationRadians = rotationRadians
    self.scale = scale
    self.translationX = translationX
    self.translationY = translationY
  }

  public func applying(x: Double, y: Double, aspectRatio: Double) -> VaultAlignmentPoint {
    let u = (x - 0.5) * aspectRatio
    let v = y - 0.5
    let c = cos(rotationRadians)
    let s = sin(rotationRadians)
    return VaultAlignmentPoint(
      x: 0.5 + scale * (u * c - v * s) / aspectRatio + translationX,
      y: 0.5 + scale * (u * s + v * c) + translationY)
  }

}

public struct VaultAlignmentResult: Sendable {
  public let transform: VaultAlignmentTransform
  public let isReliable: Bool
  public let score: Double
  public let commonCrop: VaultAlignmentRect?
}

/// Bounded contour registration; no perspective, shear or independent axis scaling.
/// Inputs are in-memory grayscale images with the same centered-crop aspect ratio.
public enum VaultPhotoAlignment {
  private struct Edge {
    let x: Double
    let y: Double
    let weight: Double
  }

  private struct Contours {
    let width: Int
    let height: Int
    let edges: [Edge]
    let distance: [Double]
    var aspect: Double { Double(width) / Double(height) }
  }

  private static let rejected = VaultAlignmentResult(
    transform: VaultAlignmentTransform(),
    isReliable: false, score: 0, commonCrop: nil)

  public static func evaluate(reference: VaultAlignmentImage, moving: VaultAlignmentImage)
    -> VaultAlignmentResult
  {
    guard let pair = prepare(reference, moving) else { return rejected }
    return result(reference: pair.0, moving: pair.1, transform: VaultAlignmentTransform())
  }

  public static func register(reference: VaultAlignmentImage, moving: VaultAlignmentImage)
    -> VaultAlignmentResult
  {
    guard let (fixed, current) = prepare(reference, moving) else { return rejected }
    var best = VaultAlignmentTransform()
    var bestCost = cost(reference: fixed, moving: current, transform: best).mean
    // 6,125 bounded candidates with <=160 sampled edges each, not image-by-image comparisons.
    for rotation in -2...2 {
      guard !Task.isCancelled else { return rejected }
      for scale in -2...2 {
        for x in -3...3 {
          for y in -3...3 {
            let candidate = VaultAlignmentTransform(
              rotationRadians: Double(rotation) * .pi / 45,
              scale: 1 + Double(scale) * 0.075,
              translationX: Double(x) * 0.04, translationY: Double(y) * 0.04)
            let value = cost(reference: fixed, moving: current, transform: candidate).mean
            if value < bestCost {
              best = candidate
              bestCost = value
            }
          }
        }
      }
    }
    for level in 0..<3 {
      guard !Task.isCancelled else { return rejected }
      let factor = pow(0.5, Double(level))
      let anchor = best
      for rotation in -1...1 {
        for scale in -1...1 {
          for x in -1...1 {
            for y in -1...1 {
              let candidate = VaultAlignmentTransform(
                rotationRadians: anchor.rotationRadians + Double(rotation) * .pi / 90 * factor,
                scale: anchor.scale + Double(scale) * 0.0375 * factor,
                translationX: anchor.translationX + Double(x) * 0.02 * factor,
                translationY: anchor.translationY + Double(y) * 0.02 * factor)
              guard abs(candidate.rotationRadians) <= .pi / 22.5,
                (0.85...1.15).contains(candidate.scale),
                abs(candidate.translationX) <= 0.12, abs(candidate.translationY) <= 0.12
              else { continue }
              let value = cost(reference: fixed, moving: current, transform: candidate).mean
              if value < bestCost {
                best = candidate
                bestCost = value
              }
            }
          }
        }
      }
    }
    return result(reference: fixed, moving: current, transform: best)
  }

  /// Conservative same-aspect crop, fully covered in both the reference and the
  /// transformed moving image. Convexity makes testing its four corners sufficient.
  public static func commonCrop(for transform: VaultAlignmentTransform, aspectRatio: Double)
    -> VaultAlignmentRect?
  {
    guard aspectRatio.isFinite, aspectRatio > 0, transform.scale.isFinite, transform.scale > 0,
      transform.rotationRadians.isFinite, transform.translationX.isFinite,
      transform.translationY.isFinite
    else { return nil }
    let centerX = 0.5 + transform.translationX / 2
    let centerY = 0.5 + transform.translationY / 2
    let c = cos(transform.rotationRadians)
    let s = sin(transform.rotationRadians)
    func covered(_ fraction: Double) -> Bool {
      for x in [centerX - fraction / 2, centerX + fraction / 2] {
        for y in [centerY - fraction / 2, centerY + fraction / 2] {
          guard (0...1).contains(x), (0...1).contains(y) else { return false }
          let u = (x - 0.5 - transform.translationX) * aspectRatio
          let v = y - 0.5 - transform.translationY
          let sx = 0.5 + (u * c + v * s) / transform.scale / aspectRatio
          let sy = 0.5 + (-u * s + v * c) / transform.scale
          guard (0...1).contains(sx), (0...1).contains(sy) else { return false }
        }
      }
      return true
    }
    guard covered(0) else { return nil }
    var lower = 0.0
    var upper = 1.0
    for _ in 0..<32 {
      let middle = (lower + upper) / 2
      if covered(middle) { lower = middle } else { upper = middle }
    }
    guard lower > 0.1 else { return nil }
    return VaultAlignmentRect(
      x: centerX - lower / 2, y: centerY - lower / 2,
      width: lower, height: lower)
  }

  private static func result(
    reference: Contours, moving: Contours,
    transform: VaultAlignmentTransform
  ) -> VaultAlignmentResult {
    let value = cost(reference: reference, moving: moving, transform: transform)
    // Background edges can dominate a whole-image average. Require independent
    // bidirectional support in the central subject region as well; room alignment
    // alone must never turn the stencil green.
    let reliable =
      value.mean < 1.25 && value.coverage > 0.78
      && value.centralMean < 1.25 && value.centralCoverage > 0.8
      && value.centralSupport >= 10
    return VaultAlignmentResult(
      transform: transform, isReliable: reliable,
      score: max(0, min(1, value.coverage * (1 - value.mean / 5))),
      commonCrop: reliable ? commonCrop(for: transform, aspectRatio: reference.aspect) : nil)
  }

  private static func prepare(_ reference: VaultAlignmentImage, _ moving: VaultAlignmentImage)
    -> (Contours, Contours)?
  {
    guard let fixed = contours(reference), let current = contours(moving),
      abs(fixed.aspect - current.aspect) < 0.025
    else { return nil }
    return (fixed, current)
  }

  private static func contours(_ image: VaultAlignmentImage) -> Contours? {
    guard image.width >= 8, image.height >= 8,
      image.width <= 16_384, image.height <= 16_384,
      image.pixels.count == image.width * image.height
    else { return nil }
    let ratio = min(1, 96 / Double(max(image.width, image.height)))
    let width = max(8, Int(Double(image.width) * ratio))
    let height = max(8, Int(Double(image.height) * ratio))
    var pixels = [Double](repeating: 0, count: width * height)
    for y in 0..<height {
      for x in 0..<width {
        let sx = min(image.width - 1, Int((Double(x) + 0.5) / Double(width) * Double(image.width)))
        let sy = min(
          image.height - 1, Int((Double(y) + 0.5) / Double(height) * Double(image.height)))
        pixels[y * width + x] = Double(image.pixels[sy * image.width + sx])
      }
    }
    var gradients = pixels.map { _ in 0.0 }
    var peak = 0.0
    for y in 1..<(height - 1) {
      for x in 1..<(width - 1) {
        let index = y * width + x
        let gx = pixels[index + 1] - pixels[index - 1]
        let gy = pixels[index + width] - pixels[index - width]
        let magnitude = hypot(gx, gy)
        gradients[index] = magnitude
        peak = max(peak, magnitude)
      }
    }
    guard peak > 12 else { return nil }
    let threshold = max(12, peak * 0.24)
    var all: [Edge] = []
    var distance = [Double](repeating: 1_000, count: width * height)
    for y in 2..<(height - 2) {
      for x in 2..<(width - 2) where gradients[y * width + x] >= threshold {
        let nx = (Double(x) + 0.5) / Double(width)
        let ny = (Double(y) + 0.5) / Double(height)
        let weight = 0.35 + 0.65 * max(0, 1 - abs(nx - 0.5) * 2)
        all.append(Edge(x: nx, y: ny, weight: weight))
        distance[y * width + x] = 0
      }
    }
    // Too little contour support, or overwhelming texture, cannot give trustworthy alignment.
    guard all.count >= 40, all.count < width * height / 3,
      let minY = all.map(\.y).min(), let maxY = all.map(\.y).max(), maxY - minY > 0.25,
      let minX = all.map(\.x).min(), let maxX = all.map(\.x).max(), maxX - minX > 0.15
    else { return nil }
    for y in 1..<height {
      for x in 1..<width {
        let i = y * width + x
        distance[i] = min(
          distance[i], distance[i - 1] + 1, distance[i - width] + 1,
          distance[i - width - 1] + 1.414)
        if x + 1 < width { distance[i] = min(distance[i], distance[i - width + 1] + 1.414) }
      }
    }
    for y in stride(from: height - 2, through: 0, by: -1) {
      for x in stride(from: width - 2, through: 0, by: -1) {
        let i = y * width + x
        distance[i] = min(
          distance[i], distance[i + 1] + 1, distance[i + width] + 1,
          distance[i + width + 1] + 1.414)
        if x > 0 { distance[i] = min(distance[i], distance[i + width - 1] + 1.414) }
      }
    }
    let count = min(160, all.count)
    let samples = (0..<count).map { all[$0 * all.count / count] }
    return Contours(width: width, height: height, edges: samples, distance: distance)
  }

  private static func cost(
    reference: Contours, moving: Contours,
    transform: VaultAlignmentTransform
  ) -> (
    mean: Double, coverage: Double, centralMean: Double, centralCoverage: Double,
    centralSupport: Int
  ) {
    let c = cos(transform.rotationRadians)
    let s = sin(transform.rotationRadians)
    let aspect = reference.aspect
    var total = 0.0
    var weight = 0.0
    var matched = 0.0
    var centralMean = 0.0
    var centralCoverage = 1.0
    var centralSupport = Int.max
    func accumulate(_ edges: [Edge], target: Contours, inverse: Bool) {
      var centerTotal = 0.0
      var centerWeight = 0.0
      var centerMatched = 0.0
      var centerCount = 0
      for edge in edges {
        let u: Double
        let v: Double
        let x: Double
        let y: Double
        if inverse {
          u = (edge.x - 0.5 - transform.translationX) * aspect
          v = edge.y - 0.5 - transform.translationY
          x = 0.5 + (u * c + v * s) / transform.scale / aspect
          y = 0.5 + (-u * s + v * c) / transform.scale
        } else {
          u = (edge.x - 0.5) * aspect
          v = edge.y - 0.5
          x = 0.5 + transform.scale * (u * c - v * s) / aspect + transform.translationX
          y = 0.5 + transform.scale * (u * s + v * c) + transform.translationY
        }
        let px = Int(floor(x * Double(target.width)))
        let py = Int(floor(y * Double(target.height)))
        let distance =
          px >= 0 && px < target.width && py >= 0 && py < target.height
          ? target.distance[py * target.width + px] : 10
        total += min(10, distance) * edge.weight
        weight += edge.weight
        if distance <= 2 { matched += edge.weight }
        if (0.34...0.66).contains(edge.x) && (0.12...0.88).contains(edge.y) {
          centerTotal += min(10, distance) * edge.weight
          centerWeight += edge.weight
          centerCount += 1
          if distance <= 2 { centerMatched += edge.weight }
        }
      }
      centralMean = max(centralMean, centerTotal / max(centerWeight, 1))
      centralCoverage = min(centralCoverage, centerMatched / max(centerWeight, 1))
      centralSupport = min(centralSupport, centerCount)
    }
    accumulate(moving.edges, target: reference, inverse: false)
    accumulate(reference.edges, target: moving, inverse: true)
    return (
      total / max(weight, 1), matched / max(weight, 1),
      centralMean, centralCoverage, centralSupport
    )
  }
}
