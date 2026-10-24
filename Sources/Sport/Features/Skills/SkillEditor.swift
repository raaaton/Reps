import SportCore
import SwiftUI

struct SkillEditor: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TrainingStore
  let original: SkillDefinition?
  private let review: Bool
  private let onBack: ((SkillDefinition) -> Void)?
  private let onSaved: (() -> Void)?
  @State private var draft: SkillDefinition
  @State private var busy = false
  @State private var error: String?
  @State private var confirmRemoval = false
  init(
    original: SkillDefinition?, startingDraft: SkillDefinition? = nil,
    review: Bool = false, onBack: ((SkillDefinition) -> Void)? = nil, onSaved: (() -> Void)? = nil
  ) {
    self.original = original
    self.review = review
    self.onBack = onBack
    self.onSaved = onSaved
    _draft = State(
      initialValue: startingDraft ?? original
        ?? SkillDefinition(name: "", steps: [SkillStep(name: "")]))
  }
  var body: some View {
    Form {
      Section("Skill") {
        TextField("Name", text: $draft.name)
        TextField("Overview", text: $draft.summary, axis: .vertical)
        TextField("Preparation", text: $draft.preparation, axis: .vertical)
      }
      Section {
        ForEach($draft.steps) { $step in
          DisclosureGroup(step.name.isEmpty ? "New Step" : step.name) {
            TextField("Step Name", text: $step.name)
            TextField("Instructions", text: $step.instructions, axis: .vertical)
            TextField("Technique / Success Cues", text: $step.cues, axis: .vertical)
            TextField("Practice Suggestion", text: $step.suggestedPractice, axis: .vertical)
            TextField("Equipment", text: $step.equipment, axis: .vertical)
            TextField(
              "HTTPS Demonstration Link",
              text: Binding(
                get: { step.sourceURL ?? "" }, set: { step.sourceURL = $0.isEmpty ? nil : $0 })
            )
            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            Toggle("Secondary Goal", isOn: $step.isExtension)
            Picker("Suggested Format", selection: $step.suggestedFormat) {
              ForEach(SkillFormat.allCases, id: \.self) { Text($0.name).tag($0) }
            }
          }
        }
        .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
        .onDelete { indices in
          if draft.steps.count > indices.count { draft.steps.remove(atOffsets: indices) }
        }
        Button("Add Step", systemImage: "plus") { draft.steps.append(SkillStep(name: "")) }
          .moveDisabled(true).deleteDisabled(true)
      } header: {
        HStack {
          Text("Steps")
          Spacer()
          EditButton().textCase(nil)
        }
      } footer: {
        Text("Only the skill name and step names are required. Keep at least one step.")
      }
    }
    .disabled(busy)
    .navigationTitle(review ? "Review Skill" : original == nil ? "New Skill" : "Edit Skill")
    .navigationBarTitleDisplayMode(
      .inline
    )
    .navigationBarBackButtonHidden(onBack != nil)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        if let onBack {
          SkillBackButton { onBack(draft) }.disabled(busy)
        } else {
          SkillToolbarButton(title: "Cancel", cancel: true) { dismiss() }.disabled(busy)
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        SkillToolbarButton { if affectedWorkouts.isEmpty { save() } else { confirmRemoval = true } }
          .disabled(busy)
      }
    }
    .interactiveDismissDisabled(busy)
    .sportConfirmation("Remove Assigned Steps?", isPresented: $confirmRemoval) {
      Button("Save Changes", role: .destructive) { save() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Removed steps will be removed from: \(affectedWorkouts.joined(separator: ", ")). Recorded practices will be kept."
      )
    }
    .alert(
      "Unable to Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }
  private var affectedWorkouts: [String] {
    guard let original, case .ready(let snapshot) = store.phase else { return [] }
    let removed = Set(original.steps.map(\.id)).subtracting(draft.steps.map(\.id))
    return snapshot.schedules.filter {
      $0.skills.contains { $0.skillID == original.id && removed.contains($0.stepID) }
    }.map(\.name)
  }
  private func save() {
    busy = true
    Task {
      defer { busy = false }
      do {
        try await store.saveSkill(draft, original: original)
        if let onSaved { onSaved() } else { dismiss() }
      } catch { self.error = error.localizedDescription }
    }
  }
}
