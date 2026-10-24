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
    GeometryReader { geometry in
      let fittingWeeks = max(1, Int((geometry.size.width + 3) / (target + 3)))
      let emptyWeeks = max(0, fittingWeeks - weeks)
      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 3) {
          ForEach(0..<emptyWeeks, id: \.self) { _ in
            VStack(spacing: 3) {
              ForEach(0..<7, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3)
                  .fill(Color.secondary.opacity(0.15))
                  .frame(width: cell, height: cell)
                  .frame(width: target, height: target)
              }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
          }
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
                      if day.photoCount > 0 {
                        Image(systemName: "camera.fill")
                          .font(.system(size: cell * 0.55, weight: .semibold))
                          .foregroundStyle(
                            day.state == .completed
                              ? SportAccentColors(accentChoice).ink
                              : SportAccentColors(accentChoice).tint
                          )
                          .accessibilityHidden(true)
                      } else if day.state == .missed || day.state == .completed {
                        Image(systemName: day.state == .completed ? "checkmark" : "xmark")
                          .font(.system(size: cell * 0.5, weight: .bold))
                          .foregroundStyle(
                            day.state == .completed
                              ? SportAccentColors(accentChoice).ink : Color.primary
                          )
                          .accessibilityHidden(true)
                      }
                    }
                    .frame(width: cell, height: cell)
                    .frame(width: target, height: target)
                    .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel("\(WorkoutLabels.day(day.key)), \(day.activitySummary)")
                } else {
                  Color.clear.frame(width: target, height: target).accessibilityHidden(true)
                }
              }
            }
          }
        }
        .frame(minWidth: geometry.size.width, alignment: .trailing)
      }
      .defaultScrollAnchor(.trailing)
    }
    .frame(height: 7 * target + 6 * 3)
  }
  private func choose(_ day: AttendanceDay) {
    SportHaptics.shared.play(.selection)
    select(day)
  }
}

struct AttendanceDayView: View {
  let day: AttendanceDay
  var body: some View {
    List {
      if day.photoCount > 0 {
        LabeledContent {
          Text(String(day.photoCount))
        } label: {
          Label("Progress Photos", systemImage: "camera")
        }
      }
      if day.workouts.isEmpty {
        Text(
          day.state == .missed
            ? "Scheduled workout not completed." : "No recorded workout on this day."
        )
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
                "\(workout.setCount) sets · \(workout.status == .completed ? "Completed" : "Canceled")"
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
      let recorded = days.filter { $0.state != .neutral || $0.photoCount > 0 }
      ForEach(recorded.reversed()) { day in
        NavigationLink {
          AttendanceDayView(day: day)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(WorkoutLabels.day(day.key)).foregroundStyle(.primary)
            Text(day.activitySummary).font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
      if recorded.isEmpty {
        ContentUnavailableView("No Activity in This Period", systemImage: "calendar")
          .listRowBackground(Color.clear)
      }
    }
    .navigationTitle("Consistency").navigationBarTitleDisplayMode(.inline)
  }
}

extension AttendanceDay {
  fileprivate var activitySummary: String {
    let workout: String =
      switch state {
      case .completed: "Workout Complete"
      case .missed: "Scheduled Workout Missed"
      case .neutral: "No Completed Workout"
      }
    guard photoCount > 0 else { return workout }
    let photos = "\(photoCount) progress \(photoCount == 1 ? "photo" : "photos")"
    return state == .neutral ? photos : "\(workout) · \(photos)"
  }
}
