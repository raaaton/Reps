import AppIntents
import Foundation
import RepsCore
import SportLiveSupport

public struct RestPauseIntent: LiveActivityIntent {
  public static let title: LocalizedStringResource = "Pause or resume the rest timer"
  public static let isDiscoverable = false
  public static var supportedModes: IntentModes { .background }

  @Parameter(title: "Rest") public var restID: String
  @Parameter(title: "Resume") public var resume: Bool
  @Parameter(title: "Expected State") public var expectedTime: Int

  public init() {}
  public init(restID: String, resume: Bool, expectedTime: Int) {
    self.restID = restID
    self.resume = resume
    self.expectedTime = expectedTime
  }
  public func perform() async throws -> some IntentResult {
    let repository = try await RepsRuntime.shared.repository()
    try await repository.changeRest(
      id: restID, action: resume ? .resume : .pause, expectedTime: expectedTime,
      now: WorkoutClock.now)
    await MainActor.run {
      NotificationCenter.default.post(name: RepsRuntime.restDidChange, object: nil)
    }
    await RestActivityCoordinator.shared.refresh(retry: true)
    return .result()
  }
}
