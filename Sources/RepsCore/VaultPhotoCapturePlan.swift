import Foundation

// A launch-time value: captures saved later never change this session's references.
public struct VaultPhotoCapturePlan: Sendable, Equatable {
  public struct Step: Sendable, Equatable, Identifiable {
    public var id: String { reference?.id ?? "single-\(pose?.rawValue ?? "unassigned")" }
    public let pose: VaultPhotoPose?
    public let reference: VaultPhotoEntry?
  }
  public let steps: [Step]
  public let referenceDay: String?
  public static func latestSession(_ photos: [VaultPhotoEntry]) -> Self? {
    guard let day = VaultPhotoCollection.days(photos).first else { return nil }
    let steps = day.photos.map { Step(pose: $0.metadata.pose, reference: $0) }
    return Self(steps: steps, referenceDay: day.id)
  }
  public static func single(pose: VaultPhotoPose, photos: [VaultPhotoEntry]) -> Self {
    let reference = VaultPhotoCollection.candidates(photos, pose: pose).last
    return Self(
      steps: [Step(pose: pose, reference: reference)], referenceDay: reference?.metadata.dayKey)
  }
}
