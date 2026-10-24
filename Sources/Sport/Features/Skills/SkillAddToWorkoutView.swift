import SportCore
import SwiftUI

struct SkillAddToWorkoutView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State private var assignment: SkillAssignment
  @State private var scheduleID = ""
  @State private var busy = false
  @State private var error: String?
  init(assignment: SkillAssignment) { _assignment = State(initialValue: assignment) }
  var body: some View {
    TrainingContent { snapshot in
      Form {
        Section {
          if let skill = snapshot.skills.first(where: { $0.id == assignment.skillID }) {
            Text(skill.name).font(.headline)
            Picker("Step", selection: $assignment.stepID) {
              ForEach(skill.steps) { Text($0.name).tag($0.id) }
            }
          }
          Picker("Workout", selection: $scheduleID) {
            ForEach(snapshot.schedules) { Text($0.name).tag($0.id) }
          }
          if snapshot.schedules.isEmpty { Text("Create a workout in Settings → Workouts first.") }
          if assignment.skillID == "l-sit",
            snapshot.schedules.first(where: { $0.id == scheduleID })?.exerciseIDs.contains("l-sit")
              == true
          {
            Text("This workout also contains L-sit as a strength exercise.").foregroundStyle(
              .secondary)
          }
        }
        Section("Practice") { SkillConfigurationFields(value: $assignment.configuration) }
        if let error { Section { Text(error).foregroundStyle(.secondary) } }
      }
      .disabled(busy)
      .onAppear { if scheduleID.isEmpty { scheduleID = snapshot.schedules.first?.id ?? "" } }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          SkillToolbarButton(title: "Cancel", cancel: true) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          SkillToolbarButton(title: "Add") {
            guard var schedule = snapshot.schedules.first(where: { $0.id == scheduleID }) else {
              return
            }
            schedule.skills.append(assignment)
            busy = true
            Task {
              defer { busy = false }
              do {
                try await store.saveSchedule(schedule)
                dismiss()
              } catch { self.error = error.localizedDescription }
            }
          }.disabled(busy || scheduleID.isEmpty)
        }
      }
    }
    .navigationTitle("Add to Workout").navigationBarTitleDisplayMode(.inline)
    .interactiveDismissDisabled(busy)
  }
}
