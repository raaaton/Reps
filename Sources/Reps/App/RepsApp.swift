import RepsCore
import SportLiveSupport
import SwiftUI

@main
struct RepsApp: App {
  @UIApplicationDelegateAdaptor(RepsAppDelegate.self) private var appDelegate
  @StateObject private var store = TrainingStore()
  @StateObject private var vault = PhotoVaultStore()
  @Environment(\.scenePhase) private var scenePhase
  @State private var clockRevision = 0
  private var runsVideoProbe: Bool {
    #if DEBUG
      VaultVideoProbeLaunch.enabled
    #else
      false
    #endif
  }

  private struct RestWake: Hashable {
    let id: String
    let deadline: Int
    let clockRevision: Int
  }

  private var restWake: RestWake? {
    guard scenePhase == .active, let workout = store.workouts.active else { return nil }
    if let rest = workout.rest, rest.status == .running, let deadline = rest.deadline {
      return RestWake(id: rest.id, deadline: deadline, clockRevision: clockRevision)
    }
    if let step = workout.currentSupport, let deadline = step.automaticDeadline {
      return RestWake(id: step.id, deadline: deadline, clockRevision: clockRevision)
    }
    return nil
  }

  @ViewBuilder
  private var rootView: some View {
    #if DEBUG
      if runsVideoProbe {
        VaultVideoProbeScreen()
      } else {
        RepsTabView()
      }
    #else
      RepsTabView()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      rootView
        .tint(RepsAccentColors(.icyCyan).tint)
        .environment(\.repsAccent, .icyCyan)
        .environmentObject(store)
        .environmentObject(vault)
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        ) { _ in vault.cover() }
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in vault.foreground() }
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
        ) { _ in vault.background() }
        .onReceive(NotificationCenter.default.publisher(for: RepsRuntime.restDidChange)) { _ in
          Task { await store.refreshWorkouts() }
        }
        .task {
          if !runsVideoProbe {
            await store.reload()
          }
        }
        .task(id: restWake) {
          guard let wake = restWake else { return }
          while !Task.isCancelled {
            let remaining = wake.deadline - WorkoutClock.now
            if remaining > 0 {
              do { try await Task.sleep(for: .milliseconds(remaining)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await store.refreshWorkouts()
            guard restWake == wake else { return }
            // A backward clock jump needs another deadline wait; a failed refresh
            // after expiry gets a bounded retry instead of a busy loop.
            if wake.deadline <= WorkoutClock.now {
              do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
          }
        }
        .onChange(of: scenePhase) { _, phase in
          switch phase {
          case .active: vault.foreground()
          case .inactive: vault.cover()
          case .background: vault.background()
          @unknown default: vault.background()
          }
          if phase == .active, !runsVideoProbe {
            Task { await store.reload() }
          }
        }
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
        ) { _ in
          guard !runsVideoProbe else { return }
          clockRevision &+= 1
          Task { await store.reload() }
        }
    }
  }
}
