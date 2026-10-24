import Foundation
import RepsCore

// A LiveActivityIntent runs in Reps's process, so no App Group is needed.
// Refuse extension execution before resolving a path or creating any database.
public actor RepsRuntime {
  public static let shared = RepsRuntime()
  public static let restDidChange = Notification.Name("Sport.restDidChange")
  private var storedRepository: RepsRepository?

  public func repository() throws -> RepsRepository {
    guard Bundle.main.bundleURL.pathExtension == "app" else {
      throw TrainingError.invalid("Open Reps to change the rest timer.")
    }
    if let storedRepository { return storedRepository }
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    let value = try RepsRepository(path: directory.appendingPathComponent("sport.sqlite").path)
    storedRepository = value
    return value
  }
}
