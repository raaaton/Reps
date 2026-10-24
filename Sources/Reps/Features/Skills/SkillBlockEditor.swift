import RepsCore
import SwiftUI

struct SkillBlockEditor: View {
  @Environment(\.dismiss) private var dismiss
  @State private var assignment: SkillAssignment
  let onSave: (SkillAssignment) -> Void
  @State private var error: String?
  let definitions: [SkillDefinition]
  @State private var customized: Bool
  init(
    assignment: SkillAssignment, definitions: [SkillDefinition], isNew: Bool = false,
    onSave: @escaping (SkillAssignment) -> Void
  ) {
    _assignment = State(initialValue: assignment)
    self.onSave = onSave
    self.definitions = definitions
    _customized = State(initialValue: !isNew)
  }
  var body: some View {
    Form {
      Section {
        Picker("Skill", selection: $assignment.skillID) {
          ForEach(definitions.filter { !$0.isArchived }) { Text($0.name).tag($0.id) }
        }
        .onChange(of: assignment.skillID) { _, new in
          if let step = definitions.first(where: { $0.id == new })?.steps.first {
            assignment.stepID = step.id
          }
        }
        if let skill = definitions.first(where: { $0.id == assignment.skillID }) {
          Picker("Step", selection: $assignment.stepID) {
            ForEach(skill.steps) { Text($0.name + ($0.isExtension ? " · Beyond" : "")).tag($0.id) }
          }
        }
      }
      Section("Practice") {
        SkillConfigurationFields(
          value: Binding(
            get: { assignment.configuration },
            set: {
              assignment.configuration = $0
              customized = true
            }))
      }
    }
    .onChange(of: assignment.stepID) { _, stepID in
      if !customized,
        let step = definitions.first(where: { $0.id == assignment.skillID })?.steps.first(where: {
          $0.id == stepID
        })
      {
        assignment.configuration.format = step.suggestedFormat
      }
    }
    .alert(
      "Unable to Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
    .navigationTitle("Skill Block").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        SkillToolbarButton(title: "Cancel", cancel: true) { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        SkillToolbarButton {
          do {
            guard let definition = definitions.first(where: { $0.id == assignment.skillID }) else {
              throw TrainingError.invalid("Choose an available skill.")
            }
            _ = try definition.assignment(for: assignment.stepID)
            _ = try assignment.configuration.validated()
            onSave(assignment)
          } catch { self.error = error.localizedDescription }
        }
      }
    }
  }
}

struct ScheduleSkillSection: View {
  @Binding var schedule: TrainingSchedule
  let definitions: [SkillDefinition]
  let onEdit: (SkillAssignment, Bool) -> Void
  var body: some View {
    Section {
      if !schedule.skills.isEmpty {
        Picker("Placement", selection: $schedule.skillPlacement) {
          ForEach(SkillPlacement.allCases, id: \.self) { Text($0.name).tag($0) }
        }
      }
      ForEach(schedule.skills) { block in
        Button {
          onEdit(block, false)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(definitions.first { $0.id == block.skillID }?.name ?? "Unavailable Skill")
              .foregroundStyle(.primary)
            Text(
              definitions.first { $0.id == block.skillID }?.steps.first { $0.id == block.stepID }?
                .name ?? "Choose Step"
            )
            .font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
      .onMove { schedule.skills.move(fromOffsets: $0, toOffset: $1) }
      .onDelete { schedule.skills.remove(atOffsets: $0) }
      if schedule.exerciseIDs.contains("l-sit"),
        schedule.skills.contains(where: { $0.skillID == "l-sit" })
      {
        Text(
          "L-sit is also a strength exercise in this workout. Review both blocks to avoid unintended duplication."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
      Menu("Add Skill", systemImage: "plus") {
        ForEach(definitions.filter { !$0.isArchived }) { skill in
          if let first = skill.steps.first {
            SkillMenuButton(title: skill.name, systemImage: "figure.gymnastics") {
              let block = SkillAssignment(
                skillID: skill.id, stepID: first.id,
                configuration: SkillConfiguration(format: first.suggestedFormat))
              onEdit(block, true)
            }
          }
        }
      }.moveDisabled(true).deleteDisabled(true)
    } header: {
      Text("Skills")
    }
  }
}
