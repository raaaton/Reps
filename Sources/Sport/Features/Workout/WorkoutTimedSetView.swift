import SportCore
import SportLiveSupport
import SwiftUI
import UIKit

// Display persisted starts/deadlines; repository reconciliation owns automatic stretch completion.
struct WorkoutTimedSetView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var observedCountdown = false
  let workout: WorkoutSession
  let exercise: WorkoutExercise
  let busy: Bool
  let cancel: () -> Void
  let finish: () -> Void
  var automaticDeadline: Int? = nil
  var showsWeight = true
  var finishTitle = "Finish Set"
  var headerTitle: String? = nil

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.1)) { context in
      let now = Int(context.date.timeIntervalSince1970 * 1000)
      let remaining = exercise.countdownSeconds(at: now)
      Group {
        if remaining > 0 {
          Section {
            VStack(spacing: 8) {
              Text("Get Ready").font(.headline)
              WorkoutTimerDisplay(value: String(remaining), label: "Countdown before the set")
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .sportAnimation(value: remaining)
              Text("Timing starts after the countdown.")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .onChange(of: remaining, initial: true) { _, new in
              guard scenePhase == .active else { return }
              observedCountdown = true
              SportHaptics.shared.play(.selection)
              AccessibilityNotification.Announcement(String(new)).post()
            }
          }
          Section {
            Button("Cancel Countdown", action: cancel)
              .buttonStyle(.bordered).controlSize(.large)
              .frame(maxWidth: .infinity)
              .listRowBackground(Color.clear).listRowSeparator(.hidden)
              .disabled(busy)
          }
        } else {
          Section {
            WorkoutTimerDisplay(
              value: WorkoutLabels.time(
                automaticDeadline.map { max(0, $0 - now + 999) / 1000 * 1000 }
                  ?? max(0, now - (exercise.setStartedAt ?? now))),
              label: automaticDeadline == nil ? "Set duration" : "Stretch time remaining"
            )
            .onAppear {
              guard observedCountdown else { return }
              observedCountdown = false
              guard scenePhase == .active else { return }
              SportHaptics.shared.play(.success)
              AccessibilityNotification.Announcement("Timer Started").post()
            }
            if let target = exercise.goal?.durationTargetMS(forSet: exercise.sets.count + 1) {
              LabeledContent("Target for This Set", value: "\(WorkoutLabels.seconds(target)) s")
                .foregroundStyle(.secondary)
            }
            if showsWeight, let grams = exercise.setWeightGrams {
              LabeledContent("Added Weight", value: "\(WorkoutLabels.weight(grams)) kg")
            }
          } header: {
            Text(headerTitle ?? "Set \(exercise.sets.count + 1) of \(exercise.definition.setCount)")
          }
          if automaticDeadline != nil {
            Section {
              Text("The hold ends automatically at the target duration.").foregroundStyle(
                .secondary)
            }.listRowBackground(Color.clear)
          } else {
            Section {
              Button(action: finish) {
                WorkoutActionLabel(
                  title: busy ? "Saving…" : finishTitle,
                  systemImage: "checkmark", isWorking: busy)
              }
              .sportProminentButton().controlSize(.large)
              .listRowBackground(Color.clear).listRowSeparator(.hidden)
              .disabled(busy)
            } footer: {
              if exercise.setWeightGrams == nil {
                Text("The timer will stop before you enter the added weight.")
              }
            }
          }
        }
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { observedCountdown = false }
    }
  }
}

struct WorkoutActionLabel: View {
  @Environment(\.sportAccent) private var accentChoice
  let title: String
  let systemImage: String
  var isWorking = false

  var body: some View {
    HStack {
      if isWorking {
        ProgressView().tint(SportAccentColors(accentChoice).ink).accessibilityHidden(true)
        Text(title)
      } else {
        Label {
          Text(title)
        } icon: {
          Image(systemName: systemImage).foregroundStyle(SportAccentColors(accentChoice).ink)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .foregroundStyle(SportAccentColors(accentChoice).ink)
    .tint(SportAccentColors(accentChoice).ink)
  }
}
