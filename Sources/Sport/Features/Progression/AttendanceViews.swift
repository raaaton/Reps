import SportCore
import SportLiveSupport
import SwiftUI

struct AttendanceGrid: View {
  @Environment(\.sportAccent) private var accentChoice
  let days: [AttendanceDay]
  let select: (AttendanceDay) -> Void
  @ScaledMetric(relativeTo: .caption) private var cell = 18.0
  private var target: Double { max(28, cell) }
  private var weeks: Int { (days.count + 6) / 7 }
  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .top, spacing: 3) {
        ForEach(0..<weeks, id: \.self) { week in
          VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { weekday in
              let index = week * 7 + weekday
              if days.indices.contains(index) {
                let day = days[index]
                Button {
                  choose(day)
                } label: {
                  ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(
                      day.state == .completed
                        ? SportAccentColors(accentChoice).fill : Color.secondary.opacity(0.15))
                    if day.state == .partial { Circle().fill(Color.primary).padding(5) }
                    if day.state == .completed {
                      Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SportAccentColors(accentChoice).ink).accessibilityHidden(
                          true)
                    }
                  }
                  .frame(width: cell, height: cell)
                  .frame(width: target, height: target)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(WorkoutLabels.day(day.key)), \(stateLabel(day.state))")
              } else {
                Color.clear.frame(width: target, height: target).accessibilityHidden(true)
              }
            }
          }
        }
      }
    }
    .defaultScrollAnchor(.trailing)
    Text("13 weeks · Filled: completed · Dot: partial").font(.caption).foregroundStyle(
      .secondary)
  }
  private func choose(_ day: AttendanceDay) {
    SportHaptics.shared.play(.selection)
    select(day)
  }
  private func stateLabel(_ state: AttendanceState) -> String {
    switch state {
    case .completed: "workout completed"
    case .partial: "sets recorded, workout incomplete"
    case .neutral: "no completed workout"
    }
  }
}

struct AttendanceDayView: View {
  let day: AttendanceDay
  var body: some View {
    List {
      if day.workouts.isEmpty {
        Text("No recorded workout on this day. Rest days stay neutral.")
          .foregroundStyle(.secondary)
      }
      ForEach(day.workouts) { workout in
        if workout.status == .active {
          LabeledContent(workout.name, value: "In Progress")
          Text("Resume this workout from Today.").font(.subheadline).foregroundStyle(
            .secondary)
        } else {
          NavigationLink {
            WorkoutHistoryDetail(workoutID: workout.id)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(workout.name).foregroundStyle(.primary)
              Text(
                "\(workout.setCount) sets · \(workout.status == .completed ? "Completed" : "Cancelled")"
              ).font(.subheadline).foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle(WorkoutLabels.day(day.key)).navigationBarTitleDisplayMode(.inline)
  }
}

struct AttendanceListView: View {
  let days: [AttendanceDay]
  var body: some View {
    List {
      let recorded = days.filter { $0.state != .neutral }
      ForEach(recorded.reversed()) { day in
        NavigationLink {
          AttendanceDayView(day: day)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(WorkoutLabels.day(day.key)).foregroundStyle(.primary)
            Text(
              day.state == .completed
                ? "Workout Complete"
                : "Partial Workout"
            ).font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
      if recorded.isEmpty {
        ContentUnavailableView("No Workouts in This Period", systemImage: "calendar")
          .listRowBackground(Color.clear)
      }
    }
    .navigationTitle("Consistency").navigationBarTitleDisplayMode(.inline)
  }
}
