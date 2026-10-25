import Foundation

enum VaultVideoImportError {
  static func describe(_ error: any Error, phase: Int?) -> String {
    if let diagnostic = error as? VaultSilentVideoDiagnostic {
      return diagnostic.localizedDescription
    }
    let stage: String
    switch phase {
    case 0: stage = "Checking vault access"
    case 1: stage = "Checking the video file"
    case 2: stage = "Reading the video duration"
    case 3: stage = "Checking the video track"
    case 4: stage = "Creating the thumbnail"
    case 5: stage = "Reading the recording date"
    case 6: stage = "Preparing the silent encrypted copy"
    case 7: stage = "Validating the prepared video"
    case 8: stage = "Saving the encrypted video"
    default: stage = "Loading the video from Photos"
    }
    var lines = ["\(stage) failed."]
    var current: NSError? = error as NSError
    for _ in 0..<4 {
      guard let failure = current else { break }
      lines.append("\(failure.localizedDescription)\n\(failure.domain) (\(failure.code))")
      current = failure.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return lines.joined(separator: "\n\n")
  }
}
