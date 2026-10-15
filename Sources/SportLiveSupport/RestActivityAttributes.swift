import ActivityKit
import Foundation
import SportCore

public struct RestActivityAttributes: ActivityAttributes, Sendable {
  public struct ContentState: Codable, Hashable, Sendable {
    public var deadlineMS: Int?
    public var deadline: Date? { deadlineMS.map(WorkoutClock.date) }
    public var remainingMS: Int?
    public var isPaused: Bool
    public var isCompleted: Bool
    public var accentRawValue: String?

    public init(deadlineMS: Int?, remainingMS: Int?, isPaused: Bool, isCompleted: Bool) {
      self.deadlineMS = deadlineMS
      self.remainingMS = remainingMS
      self.isPaused = isPaused
      self.isCompleted = isCompleted
      accentRawValue = nil
    }

    public init(
      snapshot: RestActivitySnapshot, completed: Bool = false, accentRawValue: String? = nil
    ) {
      deadlineMS = snapshot.deadline
      remainingMS = snapshot.remainingMS
      isPaused = snapshot.isPaused
      isCompleted = completed
      self.accentRawValue = accentRawValue
    }
  }

  public let restID: String
  public let workoutID: String
  public let exerciseName: String
  public let nextSet: Int
  public let isCompletion: Bool

  public init(
    restID: String, workoutID: String, exerciseName: String, nextSet: Int, isCompletion: Bool
  ) {
    self.restID = restID
    self.workoutID = workoutID
    self.exerciseName = exerciseName
    self.nextSet = nextSet
    self.isCompletion = isCompletion
  }
}
