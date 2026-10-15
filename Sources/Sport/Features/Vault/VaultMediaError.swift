import Foundation

enum VaultMediaError: LocalizedError {
  case faceIDUnavailable, exportDenied
  var errorDescription: String? {
    switch self {
    case .faceIDUnavailable:
      "Face ID must be set up and available on this iPhone. Try again after unlocking the iPhone."
    case .exportDenied:
      "Allow adding photos in the iOS settings for Sport to export this copy."
    }
  }
}
