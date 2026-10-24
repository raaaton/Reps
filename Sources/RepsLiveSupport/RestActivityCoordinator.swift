import ActivityKit
import Foundation
import RepsCore

@MainActor
public final class RestActivityCoordinator {
  public static let shared = RestActivityCoordinator()
  public private(set) var message: String?
  private var synchronizing = false
  private var needsRefresh = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var failedSnapshot: RestActivitySnapshot?
  private let defaults = UserDefaults.standard
  private let attemptedKey = "Sport.lastRestActivityID"

  // Re-read SQLite on every queued pass; view snapshots never own ActivityKit state.
  public func refresh(retry: Bool = false) async {
    if retry { failedSnapshot = nil }
    needsRefresh = true
    if synchronizing {
      await withCheckedContinuation { waiters.append($0) }
      return
    }
    synchronizing = true
    defer {
      synchronizing = false
      let completedWaiters = waiters
      waiters.removeAll()
      for waiter in completedWaiters { waiter.resume() }
    }
    repeat {
      needsRefresh = false
      do {
        let repository = try await RepsRuntime.shared.repository()
        let now = WorkoutClock.now
        let snapshot = try await repository.restActivitySnapshot(now: now)
        try await reconcile(snapshot)
      } catch {
        message =
          "Rest continues in Reps. The Live Activity is unavailable: \(error.localizedDescription)"
      }
    } while needsRefresh
  }

  private func reconcile(_ snapshot: RestActivitySnapshot?) async throws {
    let activities = RestActivityBridge.records().filter {
      $0.status == .active || $0.status == .stale || $0.status == .pending
    }
    // Includes pending scheduled completions, so pause/skip/cancel remove future alerts.
    let identities = activities.map {
      RestActivityIdentity(
        id: $0.id, restID: $0.attributes.restID,
        isCompletion: $0.attributes.isCompletion, deadline: $0.contentState.deadlineMS)
    }
    for id in RestActivityPolicy.retiredIDs(records: identities, snapshot: snapshot) {
      await RestActivityBridge.end(id: id)
    }
    guard let snapshot else {
      message = nil
      failedSnapshot = nil
      return
    }
    guard try await isCurrent(snapshot) else { return }
    guard RestActivityBridge.areActivitiesEnabled else {
      message =
        "Allow Live Activities in the iOS settings for Reps to see the rest timer outside the app."
      return
    }
    if failedSnapshot == snapshot { return }
    let live = RestActivityBridge.records().filter {
      $0.attributes.restID == snapshot.restID
        && ($0.status == .active || $0.status == .stale
          || $0.status == .pending)
    }
    let accent = AccentChoice.icyCyan.rawValue
    let state = RestActivityAttributes.ContentState(snapshot: snapshot, accentRawValue: accent)
    let content = ActivityContent(state: state, staleDate: state.deadline)
    let countdowns = live.filter { !$0.attributes.isCompletion }
    if let countdown = countdowns.first {
      if countdown.contentState != state {
        await RestActivityBridge.update(id: countdown.id, content: content)
      }
      for duplicate in countdowns.dropFirst() {
        await RestActivityBridge.end(id: duplicate.id)
      }
    } else if defaults.string(forKey: attemptedKey) != snapshot.restID {
      do {
        _ = try Activity.request(
          attributes: attributes(snapshot, completion: false), content: content, pushType: nil)
        defaults.set(snapshot.restID, forKey: attemptedKey)
      } catch {
        failedSnapshot = snapshot
        throw error
      }
    } else {
      // A dismissed countdown stays dismissed across polling and app relaunch.
      for activity in live where activity.attributes.isCompletion {
        await RestActivityBridge.end(id: activity.id)
      }
      message = nil
      return
    }
    // A pause/skip may have committed while an Activity update/end was awaited.
    // Never schedule the old completion after that suspension point.
    guard try await isCurrent(snapshot) else { return }
    let completions = live.filter { $0.attributes.isCompletion }
    if let deadline = state.deadline, completions.isEmpty {
      do {
        _ = try Activity.request(
          attributes: attributes(snapshot, completion: true),
          content: ActivityContent(
            state: RestActivityAttributes.ContentState(
              snapshot: snapshot, completed: true, accentRawValue: accent),
            staleDate: nil),
          pushType: nil, style: .transient,
          alertConfiguration: AlertConfiguration(
            title: "Rest Complete", body: "Your next set is ready.", sound: .default),
          start: deadline)
      } catch {
        failedSnapshot = snapshot
        message =
          "The countdown remains visible. The completion alert outside Reps is unavailable: \(error.localizedDescription)"
        return
      }
    }
    if let completion = completions.first {
      let completionState = RestActivityAttributes.ContentState(
        snapshot: snapshot, completed: true, accentRawValue: accent)
      if completion.contentState != completionState {
        await RestActivityBridge.update(
          id: completion.id, content: ActivityContent(state: completionState, staleDate: nil))
      }
    }
    for duplicate in completions.dropFirst() {
      await RestActivityBridge.end(id: duplicate.id)
    }
    message = nil
    failedSnapshot = nil
  }

  private func isCurrent(_ snapshot: RestActivitySnapshot) async throws -> Bool {
    let repository = try await RepsRuntime.shared.repository()
    let current = try await repository.restActivitySnapshot(now: WorkoutClock.now)
    guard current == snapshot else {
      needsRefresh = true
      return false
    }
    return true
  }

  private func attributes(_ snapshot: RestActivitySnapshot, completion: Bool)
    -> RestActivityAttributes
  {
    RestActivityAttributes(
      restID: snapshot.restID, workoutID: snapshot.workoutID, exerciseName: snapshot.exerciseName,
      nextSet: snapshot.nextSet, isCompletion: completion)
  }
}
