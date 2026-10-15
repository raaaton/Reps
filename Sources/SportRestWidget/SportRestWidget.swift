import ActivityKit
import SportCore
import SportLiveSupport
import SwiftUI
import WidgetKit

@main
struct SportRestWidgetBundle: WidgetBundle {
  var body: some Widget { SportRestWidget() }
}

struct SportRestWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestActivityAttributes.self) { context in
      RestActivityLockScreen(context: context)
        .widgetURL(workoutURL(context.attributes.workoutID))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(restTitle(context)).font(.caption.weight(.semibold))
            .invalidatableContent()
            .padding(.leading, 8).padding(.top, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          RestActivityTimer(state: context.state, completed: completed(context))
            .font(.title2.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .padding(.trailing, 8).padding(.top, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.exerciseName).font(.headline).lineLimit(1)
            HStack {
              Text("Set \(context.attributes.nextSet)").foregroundStyle(.secondary)
              Spacer()
              if !completed(context) { RestActivityButton(context: context) }
            }
          }
          .padding(.horizontal, 8).padding(.bottom, 8)
        }
      } compactLeading: {
        Image(systemName: restIcon(context)).foregroundStyle(accentColors(context).tint)
          .accessibilityLabel(restTitle(context))
      } compactTrailing: {
        RestActivityTimer(state: context.state, completed: completed(context))
          .font(.caption.weight(.semibold))
      } minimal: {
        Image(systemName: restIcon(context)).foregroundStyle(accentColors(context).tint)
          .accessibilityLabel(restTitle(context))
      }
      .widgetURL(workoutURL(context.attributes.workoutID))
      .keylineTint(accentColors(context).tint)
    }
  }
}

private func accentColors(_ context: ActivityViewContext<RestActivityAttributes>)
  -> SportAccentColors
{
  SportAccentColors(.icyCyan)
}

private func completed(_ context: ActivityViewContext<RestActivityAttributes>) -> Bool {
  context.state.isCompleted || (!context.state.isPaused && context.isStale)
}

private func restTitle(_ context: ActivityViewContext<RestActivityAttributes>) -> String {
  completed(context) ? "Rest Complete" : context.state.isPaused ? "PAUSE" : "REST"
}

private func restIcon(_ context: ActivityViewContext<RestActivityAttributes>) -> String {
  completed(context) ? "checkmark" : context.state.isPaused ? "pause.fill" : "timer"
}

private func workoutURL(_ id: String) -> URL? {
  URL(string: "sport://workout/\(id)")
}

private struct RestActivityLockScreen: View {
  let context: ActivityViewContext<RestActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(restTitle(context)).font(.subheadline.weight(.semibold))
          .invalidatableContent()
        Spacer(minLength: 12)
        RestActivityTimer(state: context.state, completed: completed(context))
          .font(.title2.weight(.semibold))
      }
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(context.attributes.exerciseName).font(.headline).lineLimit(1)
          Text("Set \(context.attributes.nextSet)")
            .font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer(minLength: 12)
        if !completed(context) { RestActivityButton(context: context) }
      }
    }
    .padding(14)
  }
}

private struct RestActivityTimer: View {
  let state: RestActivityAttributes.ContentState
  let completed: Bool

  var body: some View {
    Group {
      if completed {
        EmptyView()
      } else if state.isPaused {
        let seconds =
          max(0, (state.remainingMS ?? 0) / 1000)
          + ((state.remainingMS ?? 0) % 1000 == 0 ? 0 : 1)
        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
          .accessibilityLabel("Rest Paused")
          .accessibilityValue("\(seconds / 60) minutes and \(seconds % 60) seconds remaining")
      } else if let deadline = state.deadline {
        // A native timer stretches to its proposed width. Size it with the same
        // font's widest minute/second label, then align its changing digits right.
        let now = Date()
        let seconds = max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
        let minuteDigits = max(1, String(seconds / 60).count)
        Text(String(repeating: "0", count: minuteDigits) + ":00")
          .hidden().accessibilityHidden(true)
          .overlay(alignment: .trailing) {
            Text(
              timerInterval: min(now, deadline)...deadline, countsDown: true,
              showsHours: false
            )
            .multilineTextAlignment(.trailing)
          }
      }
    }
    .multilineTextAlignment(.trailing)
    .monospacedDigit()
    .invalidatableContent()
    .accessibilityLabel(
      completed ? "Rest Complete" : state.isPaused ? "Rest Paused" : "Rest time remaining")
  }
}

private struct RestActivityButton: View {
  let context: ActivityViewContext<RestActivityAttributes>

  var body: some View {
    let paused = context.state.isPaused
    Button(
      intent: RestPauseIntent(
        restID: context.attributes.restID, resume: paused,
        expectedTime: paused ? context.state.remainingMS ?? 0 : context.state.deadlineMS ?? 0)
    ) {
      Label {
        Text(paused ? "Resume" : "Pause")
      } icon: {
        if paused {
          Image(systemName: "play.fill")
        } else {
          Image(systemName: "pause.fill").foregroundStyle(.white)
        }
      }
    }
    .buttonStyle(.bordered).tint(accentColors(context).tint)
  }
}
