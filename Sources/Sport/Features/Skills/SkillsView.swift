import SportCore
import SwiftUI

struct SkillsView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var creating = false
  @State private var manual = false
  var body: some View {
    TrainingContent { snapshot in
      List {
        if let active = store.activeSkillPractice {
          Section("Practice in Progress") {
            NavigationLink {
              SkillPracticeView(practiceID: active.id)
            } label: {
              Label("Resume \(active.definition.name)", systemImage: "play.fill")
            }
          }
        }
        let completed = snapshot.skills.filter { skill in
          !skill.isArchived
            && snapshot.skillProgress.first { $0.skillID == skill.id }?.completed(in: skill) == true
        }
        let followed = snapshot.skills.filter { skill in
          !skill.isArchived && !completed.contains(skill)
            && snapshot.skillProgress.contains { $0.skillID == skill.id }
        }
        if !followed.isEmpty {
          Section("Following") {
            ForEach(followed) { skill in skillLink(skill, snapshot: snapshot) }
          }
        }
        Section("Catalog") {
          ForEach(
            snapshot.skills.filter {
              !$0.isArchived && !followed.contains($0) && !completed.contains($0)
            }
          ) { skill in
            skillLink(skill, snapshot: snapshot)
          }
          if snapshot.skills.allSatisfy(\.isArchived) {
            Text("Create a skill to build your own roadmap.").foregroundStyle(.secondary)
          }
        }
        if !completed.isEmpty {
          Section("Completed") {
            ForEach(completed) { skill in skillLink(skill, snapshot: snapshot, completed: true) }
          }
        }
        Section {
          NavigationLink {
            ArchivedSkillsView()
          } label: {
            Label("Archived Skills", systemImage: "archivebox")
          }
        }
        Section {
          NavigationLink {
            SkillHistoryView()
          } label: {
            Label("Practice History", systemImage: "clock.arrow.circlepath")
          }
        }
      }
      .sheet(isPresented: $creating) {
        SkillGenerationView()
      }
    }
    .sheet(isPresented: $manual) { NavigationStack { SkillEditor(original: nil) } }
    .navigationTitle("Skills").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        SkillToolbarMenu(title: "Create Skill", systemImage: "plus") {
          SkillMenuButton(title: "Create with AI", systemImage: "sparkles") { creating = true }
          SkillMenuButton(title: "Create Manually", systemImage: "square.and.pencil") {
            manual = true
          }
        }
      }
    }
  }
  private func skillLink(
    _ stored: SkillDefinition, snapshot: TrainingSnapshot, completed: Bool = false
  ) -> some View {
    let skill = stored.americanEnglish
    return
      NavigationLink {
        SkillDetailView(skillID: skill.id)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(skill.name).foregroundStyle(completed ? Color.secondary : Color.primary)
          if let progress = snapshot.skillProgress.first(where: { $0.skillID == skill.id }),
            let step = skill.steps.first(where: { $0.id == progress.currentStepID })
          {
            Text(step.name).font(.subheadline).foregroundStyle(.secondary)
          } else {
            Text(
              "\(skill.steps.filter { !$0.isExtension }.count) steps\(skill.isPreset ? "" : " · Custom")"
            )
            .font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
  }
}
