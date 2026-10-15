import Foundation
import SportCore

// A LiveActivityIntent runs in Sport's process, so no App Group is needed.
// Refuse extension execution before resolving a path or creating any database.
public actor SportRuntime {
  public static let shared = SportRuntime()
  public static let restDidChange = Notification.Name("Sport.restDidChange")
  private var storedRepository: SportRepository?

  public func repository() throws -> SportRepository {
    guard Bundle.main.bundleURL.pathExtension == "app" else {
      throw TrainingError.invalid("Open Sport to change the rest timer.")
    }
    if let storedRepository { return storedRepository }
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    let value = try SportRepository(path: directory.appendingPathComponent("sport.sqlite").path)
    storedRepository = value
    return value
  }
}
