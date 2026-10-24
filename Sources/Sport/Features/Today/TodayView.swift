import SportCore
import SportLiveSupport
import SwiftUI

struct TodayView: View {
  @Environment(\.sportAccent) private var accentChoice
  @EnvironmentObject private var store: TrainingStore
  @State private var route: WorkoutRoute?
  @State private var skillPracticeID: String?
  @State private var restartScheduleID: String?
  var body: some View {
    TrainingContent { snapshot in
      TimelineView(.periodic(from: .now, by: 60)) { context in
        List {
          if let practice = store.activeSkillPractice {
            Section("Practice in Progress") {
              Button("Resume \(practice.definition.name)", systemImage: "play.fill") {
                skillPracticeID = practice.id
              }
            }
          }
          if let active = store.workouts.active {
            Section("Workout in Progress") {
              VStack(alignment: .leading, spacing: 4) {
                Text(active.name).font(.headline)
                if let practice = active.currentSkill {
                  Text("Skills · " + (practice.step?.name ?? practice.definition.name))
                    .foregroundStyle(.secondary)
                } else if let step = active.currentSupport {
                  Text("\(step.kind == .warmUp ? "Warm-up" : "Stretch") · \(step.name)")
                    .foregroundStyle(.secondary)
                } else if let exercise = active.currentExercise {
                  Text(exercise.definition.name).foregroundStyle(.secondary)
                  Text(
                    "\(exercise.sets.count) of \(exercise.definition.setCount) sets recorded"
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                }
              }
            }
            Section {
              Button {
                route = WorkoutRoute(scheduleID: nil, workoutID: active.id)
              } label: {
                Label("Resume Workout", systemImage: "play.fill")
                  .frame(maxWidth: .infinity)
              }
              .sportProminentButton().controlSize(.large)
              .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
          }
          if let schedule = snapshot.schedule(on: context.date) {
            Section {
              ForEach(snapshot.exercises(for: schedule)) { exercise in
                VStack(alignment: .leading, spacing: 4) {
                  Text(exercise.name)
                  ExerciseGoalRow(exercise: exercise, scheduleID: schedule.id)
                }
                .padding(.vertical, 2)
              }
            } header: {
              Text(schedule.name)
            }
            Section {
              NavigationLink {
                RestSettingsView()
              } label: {
                LabeledContent("Between Sets", value: TrainingLabels.rest(snapshot.restSeconds))
                  .foregroundStyle(.primary)
              }
            }
            if store.workouts.active == nil && store.activeSkillPractice == nil {
              let completed = completedWorkout(scheduleID: schedule.id, date: context.date)
              Section {
                if let completed {
                  NavigationLink {
                    WorkoutHistoryDetail(workoutID: completed.id)
                  } label: {
                    Label("Workout Complete", systemImage: "checkmark.circle")
                  }
                  Button("Start Again", systemImage: "arrow.counterclockwise") {
                    restartScheduleID = schedule.id
                  }
                } else {
                  Button {
                    route = WorkoutRoute(scheduleID: schedule.id, workoutID: nil)
                  } label: {
                    Label {
                      Text("Prepare Workout")
                    } icon: {
                      Image(systemName: "play.fill").foregroundStyle(
                        SportAccentColors(accentChoice).ink)
                    }.frame(maxWidth: .infinity)
                  }
                  .sportProminentButton().controlSize(.large)
                  .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                  .listRowBackground(Color.clear)
                }
              }
            }
          } else {
            ContentUnavailableView(
              "Rest Day", systemImage: "figure.cooldown",
              description: Text("No workout scheduled for today.")
            )
            .listRowBackground(Color.clear)
          }

          Section("This Week") {
            if snapshot.schedules.isEmpty {
              Text("Add a workout in Settings → Workouts.").foregroundStyle(.secondary)
            }
            ForEach(snapshot.schedules) { schedule in
              NavigationLink {
                ScheduleDetailView(scheduleID: schedule.id)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(schedule.name).foregroundStyle(.primary)
                  Text(
                    "\(TrainingLabels.weekday(schedule.weekday))\(schedule.isEnabled ? "" : " · Disabled")"
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        .listSectionSpacing(.compact)
      }
    }
    .navigationTitle("Today")
    .onChange(of: store.pendingWorkoutID, initial: true) { _, _ in openLinkedWorkout() }
    .onChange(of: store.isReady) { _, _ in openLinkedWorkout() }
    .onChange(of: store.workouts.active?.id) { _, _ in openLinkedWorkout() }
    .onChange(of: store.workouts.history) { _, _ in openLinkedWorkout() }
    .sheet(
      isPresented: Binding(
        get: { skillPracticeID != nil }, set: { if !$0 { skillPracticeID = nil } })
    ) {
      if let id = skillPracticeID { NavigationStack { SkillPracticeView(practiceID: id) } }
    }
    .fullScreenCover(item: $route) { WorkoutFlowView(route: $0) }
    .sportConfirmation(
      "Start Again?",
      isPresented: Binding(
        get: { restartScheduleID != nil }, set: { if !$0 { restartScheduleID = nil } })
    ) {
      Button("Start Again") {
        if let id = restartScheduleID {
          route = WorkoutRoute(scheduleID: id, workoutID: nil, restart: true)
        }
        restartScheduleID = nil
      }
      Button("Cancel", role: .cancel) { restartScheduleID = nil }
    } message: {
      Text("Your previous workout will remain in history. A new workout will be created.")
    }
  }
  private func openLinkedWorkout() {
    guard let id = store.pendingWorkoutID, case .ready = store.phase else { return }
    route = WorkoutRoute(scheduleID: "", workoutID: id)
    store.consumeWorkoutLink()
  }
  private func completedWorkout(scheduleID: String, date: Date) -> WorkoutSummary? {
    let day = WorkoutClock.dayKey(Int(date.timeIntervalSince1970 * 1000))
    return store.workouts.history.first { workout in
      workout.scheduleID == scheduleID && workout.dayKey == day
        && workout.status == WorkoutStatus.completed
    }
  }

}

struct ScheduleDetailView: View {
  let scheduleID: String

  var body: some View {
    TrainingContent { snapshot in
      if let schedule = snapshot.schedules.first(where: { $0.id == scheduleID }) {
        List {
          Section {
            LabeledContent("Day", value: TrainingLabels.weekday(schedule.weekday))
            LabeledContent("Workout", value: schedule.isEnabled ? "Enabled" : "Disabled")
          }
          Section("Active Exercises") {
            ForEach(snapshot.exercises(for: schedule)) { exercise in
              VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                Text(TrainingLabels.target(exercise)).font(.subheadline).foregroundStyle(.secondary)
              }
            }
            if snapshot.exercises(for: schedule).isEmpty {
              Text("No Active Exercises").foregroundStyle(.secondary)
            }
          }
          Section {
            LabeledContent("Rest", value: TrainingLabels.rest(snapshot.restSeconds))
          } footer: {
            Text("Edit this workout in Settings → Workouts.")
          }
        }
        .navigationTitle(schedule.name)
      } else {
        ContentUnavailableView(
          "Workout Deleted", systemImage: "calendar",
          description: Text("Find your other workouts in Today.")
        )
        .navigationTitle("Workout")
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }
}
