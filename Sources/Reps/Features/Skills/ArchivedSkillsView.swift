import RepsCore
import SwiftUI

struct ArchivedSkillsView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var deleting: SkillDefinition?
  @State private var error: String?
  @State private var busy = false
  var body: some View {
    TrainingContent { snapshot in
      List {
        let archived = snapshot.skills.filter(\.isArchived)
        if archived.isEmpty {
          ContentUnavailableView("No Archived Skills", systemImage: "archivebox")
        }
        ForEach(archived) { skill in
          NavigationLink {
            SkillDetailView(skillID: skill.id)
          } label: {
            Text(skill.name).foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            SkillDestructiveButton(title: "Delete", filled: true) { deleting = skill }
              .labelStyle(.iconOnly)
          }
          .contextMenu {
            Button(role: .destructive) {
              deleting = skill
            } label: {
              SkillDestructiveLabel(title: "Delete Permanently")
            }
          }
        }
        if let error { Text(error).foregroundStyle(.secondary) }
      }.disabled(busy)
    }
    .navigationTitle("Archived Skills")
    .repsConfirmation(
      "Delete Skill Permanently?",
      isPresented: Binding(
        get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete Permanently", role: .destructive) {
        guard let skill = deleting else { return }
        busy = true
        Task {
          defer {
            busy = false
            deleting = nil
          }
          do {
            try await store.deleteArchivedSkill(id: skill.id)
            error = nil
          } catch { self.error = error.localizedDescription }
        }
      }
      Button("Cancel", role: .cancel) { deleting = nil }
    } message: {
      Text(
        "Remove this archived skill and its progress permanently. Recorded practices will be kept.")
    }
  }
}
