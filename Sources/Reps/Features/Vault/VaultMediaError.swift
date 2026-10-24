import Foundation

enum VaultMediaError: LocalizedError {
  case faceIDUnavailable, exportDenied, captureFailed
  var errorDescription: String? {
    switch self {
    case .faceIDUnavailable:
      "Face ID must be set up and available on this iPhone. Try again after unlocking the iPhone."
    case .exportDenied:
      "Allow adding photos in the iOS settings for Reps to export this copy."
    case .captureFailed:
      "The photo could not be imported. Try taking it again."
    }
  }
}
