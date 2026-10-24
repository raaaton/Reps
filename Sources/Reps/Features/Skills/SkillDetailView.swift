import RepsCore
import SwiftUI

struct SkillDetailView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let skillID: String
  var stepID: String? = nil
  @State private var selectedStep = ""
  @State private var editing = false
  @State private var addingAssignment: SkillAssignment?
  @State private var resetting = false
  @State private var permanentlyDeleting = false
  @State private var completionPresented = false
  @State private var adopting = false
  @State private var archiving = false
  @State private var adoptIDs: Set<String> = []
  @State private var practiceID: String?
  @State private var workoutRoute: WorkoutRoute?
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    TrainingContent { snapshot in
      if let storedSkill = snapshot.skills.first(where: { $0.id == skillID }) {
        let skill = storedSkill.americanEnglish
        List {
          if let stepID, let step = skill.steps.first(where: { $0.id == stepID }) {
            stepContent(skill, step: step, snapshot: snapshot)
          } else {
            overview(skill, snapshot: snapshot)
          }
          if let error { Section { Text(error).foregroundStyle(.secondary) } }
        }
        .disabled(busy)
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(stepID == nil ? .large : .inline)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            SkillToolbarMenu(title: "More", systemImage: "ellipsis") {
              if !skill.isArchived {
                SkillMenuButton(
                  title: skill.isPreset ? "Duplicate and Edit" : "Edit Skill",
                  systemImage: skill.isPreset ? "plus.square.on.square" : "pencil"
                ) {
                  editing = true
                }
                SkillDestructiveButton(
                  title: "Reset Progress", systemImage: "arrow.counterclockwise"
                ) { resetting = true }
                SkillDestructiveButton(title: "Archive Skill", systemImage: "archivebox") {
                  archiving = true
                }
              } else {
                SkillDestructiveButton(title: "Delete Permanently") { permanentlyDeleting = true }
              }
            }
          }
        }
        .repsConfirmation("Delete Skill Permanently?", isPresented: $permanentlyDeleting) {
          Button("Delete Permanently", role: .destructive) {
            perform {
              try await store.deleteArchivedSkill(id: skill.id)
              dismiss()
            }
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("Remove the skill and its progress permanently. Recorded practices will be kept.")
        }
        .alert("Skill Complete", isPresented: $completionPresented) {
          Button("Done", role: .cancel) {}
        } message: {
          Text("Main goal and all secondary goals completed.")
        }
        .repsConfirmation("Reset Skill Progress?", isPresented: $resetting) {
          Button("Reset Progress", role: .destructive) {
            perform { try await store.resetSkill(id: skill.id) }
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text(
            "Clear all step and goal progress. Future workout blocks restart at the first step with the same practice settings. Recorded practices will be kept."
          )
        }
        .onAppear { selectInitial(skill, snapshot: snapshot) }
        .onChange(of: skill.steps.map(\.id)) { _, _ in selectInitial(skill, snapshot: snapshot) }
        .sheet(isPresented: $editing) {
          NavigationStack {
            SkillEditor(
              original: skill.isPreset ? nil : skill,
              startingDraft: skill.isPreset ? skill.duplicated() : skill)
          }
        }
        .sheet(item: $addingAssignment) { assignment in
          NavigationStack { SkillAddToWorkoutView(assignment: assignment) }
        }
        .sheet(isPresented: $adopting) {
          NavigationStack {
            Form {
              Section {
                Text(
                  "Set this as your current step. Choose the workouts that should also use it; their practice settings stay the same."
                )
                ForEach(snapshot.schedules.filter { $0.skills.contains { $0.skillID == skill.id } })
                { schedule in
                  Toggle(
                    schedule.name,
                    isOn: Binding(
                      get: { adoptIDs.contains(schedule.id) },
                      set: {
                        if $0 { adoptIDs.insert(schedule.id) } else { adoptIDs.remove(schedule.id) }
                      }))
                }
              }
              if let error { Section { Text(error).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Current Step").navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                SkillToolbarButton(title: "Cancel", cancel: true) { adopting = false }
              }
              ToolbarItem(placement: .confirmationAction) {
                SkillToolbarButton {
                  var progress =
                    snapshot.skillProgress.first { $0.skillID == skill.id }
                    ?? SkillProgress(skillID: skill.id, currentStepID: selectedStep)
                  perform {
                    progress = try progress.settingCurrent(selectedStep, in: skill)
                    try await store.saveSkillProgress(progress, adoptingIn: Array(adoptIDs))
                    adopting = false
                  }
                }.disabled(busy)
              }
            }
          }
        }
        .repsConfirmation("Archive This Skill?", isPresented: $archiving) {
          Button("Archive Skill", role: .destructive) {
            perform { try await store.archiveSkill(id: skill.id) }
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          let names = snapshot.schedules.filter { $0.skills.contains { $0.skillID == skill.id } }
            .map(\.name)
          Text(
            names.isEmpty
              ? "Recorded practices will be kept."
              : "Removed from: \(names.joined(separator: ", ")). Recorded practices will be kept.")
        }
      }
    }
    .sheet(isPresented: Binding(get: { practiceID != nil }, set: { if !$0 { practiceID = nil } })) {
      if let id = practiceID { NavigationStack { SkillPracticeView(practiceID: id) } }
    }
    .fullScreenCover(item: $workoutRoute) { WorkoutFlowView(route: $0) }
  }
  private func currentStep(_ skill: SkillDefinition, snapshot: TrainingSnapshot) -> SkillStep {
    let id = snapshot.skillProgress.first { $0.skillID == skill.id }?.currentStepID
    return skill.steps.first { $0.id == id } ?? skill.steps[0]
  }

  @ViewBuilder private func overview(_ skill: SkillDefinition, snapshot: TrainingSnapshot)
    -> some View
  {
    let progress = snapshot.skillProgress.first { $0.skillID == skill.id }
    let complete = progress?.completed(in: skill) == true
    if complete {
      Section {
        Label("All Goals Complete", systemImage: "checkmark.seal.fill").font(.headline)
          .foregroundStyle(.secondary)
      }
    } else if progress?.mainGoalCompleted(in: skill) == true {
      Section {
        Label("Main Goal Complete", systemImage: "checkmark.circle.fill").foregroundStyle(
          .secondary)
      }
    }
    let current = currentStep(skill, snapshot: snapshot)
    Section {
      NavigationLink {
        SkillDetailView(skillID: skill.id, stepID: current.id)
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          Text(current.name).font(.headline).foregroundStyle(.primary)
          Text("View instructions").font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
      }
      if !skill.isArchived {
        practiceButton(skill, step: current)
        Button("Add to Workout", systemImage: "calendar.badge.plus") {
          openAdd(skill, stepID: current.id)
        }
      }
    } header: {
      Text(
        skill.isArchived
          ? "Archived"
          : snapshot.skillProgress.contains { $0.skillID == skill.id }
            ? "Current Step" : "Start Here")
    }
    roadmap(skill, snapshot: snapshot, extensions: false)
    if skill.steps.contains(where: \.isExtension) {
      roadmap(skill, snapshot: snapshot, extensions: true)
    }
    Section {
      NavigationLink {
        SkillHistoryView(skillID: skill.id)
      } label: {
        Label("Practice History", systemImage: "clock.arrow.circlepath")
      }
    }
  }

  private func roadmap(_ skill: SkillDefinition, snapshot: TrainingSnapshot, extensions: Bool)
    -> some View
  {
    let steps = skill.steps.filter { $0.isExtension == extensions }
    let currentID = snapshot.skillProgress.first { $0.skillID == skill.id }?.currentStepID
    return Section {
      ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
        NavigationLink {
          SkillDetailView(skillID: skill.id, stepID: step.id)
        } label: {
          SkillRoadmapRow(
            step: step, number: index + 1, isCurrent: currentID == step.id,
            achievement: achievement(step.id, snapshot: snapshot))
        }
        .contextMenu {
          if !skill.isArchived {
            SkillMenuButton(title: "Current Step", systemImage: "location") {
              perform {
                let old =
                  snapshot.skillProgress.first { $0.skillID == skill.id }
                  ?? SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
                try await store.saveSkillProgress(try old.settingCurrent(step.id, in: skill))
              }
            }
            SkillMenuButton(title: "First Success", systemImage: "checkmark.circle") {
              setAchievement(.firstSuccess, step: step, skill: skill, snapshot: snapshot)
            }
            SkillMenuButton(title: "Consistent", systemImage: "checkmark.circle.fill") {
              setAchievement(.consistent, step: step, skill: skill, snapshot: snapshot)
            }
          }
        }
      }
    } header: {
      Text(extensions ? "Beyond the Goal" : "Roadmap")
    }
  }

  @ViewBuilder private func stepContent(
    _ skill: SkillDefinition, step: SkillStep,
    snapshot: TrainingSnapshot
  ) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          step.isExtension
            ? "Beyond the Goal"
            : "Step \((skill.steps.filter { !$0.isExtension }.firstIndex { $0.id == step.id } ?? 0) + 1) of \(skill.steps.filter { !$0.isExtension }.count)"
        )
        .font(.subheadline).foregroundStyle(.secondary)
        Text(step.name).font(.title2.bold()).foregroundStyle(.primary)
      }.listRowBackground(Color.clear)
    }
    if !skill.isArchived {
      Section {
        practiceButton(skill, step: step)
        Button("Add to Workout", systemImage: "calendar.badge.plus") {
          openAdd(skill, stepID: step.id)
        }
      }
    }
    SkillInstructionsSection(step: step)
    Section {
      if snapshot.skillProgress.first(where: { $0.skillID == skill.id })?.currentStepID == step.id {
        Label("Current Step", systemImage: "location.fill").foregroundStyle(.secondary)
      } else if !skill.isArchived {
        Button("Make Current Step", systemImage: "location") {
          selectedStep = step.id
          error = nil
          adoptIDs = []
          adopting = true
        }
      }
      Picker(
        "Your Progress",
        selection: Binding(
          get: { achievement(step.id, snapshot: snapshot) },
          set: { setAchievement($0, step: step, skill: skill, snapshot: snapshot) })
      ) {
        ForEach(SkillAchievement.allCases, id: \.self) { Text($0.name).tag($0) }
      }.disabled(skill.isArchived)
    } header: {
      Text("Progress")
    }
  }

  private func practiceButton(_ skill: SkillDefinition, step: SkillStep) -> some View {
    SkillPrimaryButton(
      title: store.workouts.active != nil
        ? "Resume Workout" : store.activeSkillPractice != nil ? "Resume Practice" : "Practice",
      systemImage: "play.fill"
    ) { start(skill, stepID: step.id) }
    .listRowSeparator(.hidden).padding(.vertical, 4)
  }
  private func openAdd(_ skill: SkillDefinition, stepID: String) {
    do { addingAssignment = try skill.assignment(for: stepID) } catch {
      self.error = error.localizedDescription
    }
  }

  private func selectInitial(_ skill: SkillDefinition, snapshot: TrainingSnapshot) {
    if skill.steps.contains(where: { $0.id == selectedStep }) { return }
    selectedStep =
      stepID ?? snapshot.skillProgress.first { $0.skillID == skill.id }?.currentStepID ?? skill
      .steps.first?
      .id ?? ""
  }
  private func achievement(_ id: String, snapshot: TrainingSnapshot) -> SkillAchievement {
    snapshot.skillProgress.first { $0.skillID == skillID }?.achievements[id] ?? .unrecorded
  }
  private func setAchievement(
    _ value: SkillAchievement, step: SkillStep, skill: SkillDefinition, snapshot: TrainingSnapshot
  ) {
    var progress =
      snapshot.skillProgress.first { $0.skillID == skill.id }
      ?? SkillProgress(skillID: skill.id, currentStepID: currentStep(skill, snapshot: snapshot).id)
    perform {
      progress = try progress.settingAchievement(value, stepID: step.id, in: skill)
      try await store.saveSkillProgress(progress)
      if progress.completed(in: skill),
        snapshot.skillProgress.first(where: { $0.skillID == skill.id })?.completed(in: skill)
          != true
      {
        completionPresented = true
        RepsHaptics.shared.play(.success)
      }
    }
  }
  private func start(_ skill: SkillDefinition, stepID: String) {
    if let workout = store.workouts.active {
      workoutRoute = WorkoutRoute(scheduleID: nil, workoutID: workout.id)
      return
    }
    if let active = store.activeSkillPractice {
      practiceID = active.id
      return
    }
    let step = skill.steps.first { $0.id == stepID } ?? skill.steps[0]
    let assignment = SkillAssignment(
      skillID: skill.id, stepID: step.id,
      configuration: SkillConfiguration(format: step.suggestedFormat))
    perform { practiceID = try await store.startSkillPractice(assignment) }
  }
  private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
    busy = true
    Task {
      defer { busy = false }
      do {
        try await operation()
        error = nil
      } catch { self.error = error.localizedDescription }
    }
  }
}

struct SkillInstructionsSection: View {
  let step: SkillStep
  var body: some View {
    Section("How to Practice") {
      VStack(alignment: .leading, spacing: 20) {
        if !step.instructions.isEmpty { Text(step.instructions) }
        if !step.cues.isEmpty { guidance("Focus On", text: step.cues) }
        if !step.suggestedPractice.isEmpty {
          guidance("Practice Tip", text: step.suggestedPractice)
        }
        if !step.equipment.isEmpty { guidance("Equipment", text: step.equipment) }
      }.padding(.vertical, 8)
      if let source = step.sourceURL, let url = URL(string: source), url.scheme == "https" {
        SkillDemonstrationLink(url: url)
      }
    }
  }
  private func guidance(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
      Text(text).foregroundStyle(.primary)
    }
  }
}

private struct SkillRoadmapRow: View {
  let step: SkillStep
  let number: Int
  let isCurrent: Bool
  let achievement: SkillAchievement
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Group {
        if achievement == .consistent {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
        } else if step.isExtension {
          Image(systemName: "arrow.up.right.circle").foregroundStyle(.tint)
        } else {
          Text("\(number)").monospacedDigit()
        }
      }
      .font(.headline).foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
      .frame(minWidth: 24).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(step.name).foregroundStyle(.primary)
        if isCurrent {
          Text("Current").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
        }
        if achievement != .unrecorded {
          Text(achievement.name).font(.subheadline).foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(step.isExtension ? "Optional extension" : "Step \(number)"), \(step.name)\(isCurrent ? ", current step" : "")\(achievement == .unrecorded ? "" : ", \(achievement.name)")"
    )
  }
}
