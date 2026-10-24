import RepsCore
import SwiftUI

struct SkillHistoryView: View {
  @EnvironmentObject private var store: TrainingStore
  var skillID: String? = nil
  @State private var deleting: SkillPractice?
  @State private var error: String?
  @State private var busy = false
  var body: some View {
    List {
      let values = store.skillHistory.filter {
        $0.state.isTerminal && (skillID == nil || $0.definition.id == skillID)
      }
      if values.isEmpty {
        ContentUnavailableView(
          "No Recorded Practices", systemImage: "clock.arrow.circlepath",
          description: Text("Completed, skipped and canceled practices will appear here."))
      }
      ForEach(values) { practice in
        NavigationLink {
          SkillPracticeResultView(practice: practice)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(practice.definition.name).foregroundStyle(.primary)
            Text(practice.step?.name ?? "Recorded Step").font(.subheadline).foregroundStyle(
              .secondary)
            Text(
              "\(WorkoutLabels.day(WorkoutClock.dayKey(practice.createdAt))) · \(practice.origin.name)"
            )
            .font(.caption).foregroundStyle(.secondary)
          }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          SkillDestructiveButton(title: "Delete", filled: true) { deleting = practice }
        }
        .contextMenu { SkillDestructiveButton(title: "Delete") { deleting = practice } }
      }
      if let error { Text(error).foregroundStyle(.secondary) }
    }
    .disabled(busy)
    .repsConfirmation(
      "Delete This Practice?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete Practice", role: .destructive) {
        guard let practice = deleting else { return }
        busy = true
        Task {
          defer {
            busy = false
            deleting = nil
          }
          do {
            try await store.deleteSkillPractice(id: practice.id)
            error = nil
          } catch { self.error = error.localizedDescription }
        }
      }
      Button("Cancel", role: .cancel) { deleting = nil }
    } message: {
      Text(
        "This practice will be removed permanently. Strength history and skill progress will be kept."
      )
    }
    .navigationTitle("Skill History")
  }
}
struct SkillPracticeResultView: View {
  let practice: SkillPractice
  var body: some View {
    List { SkillPracticeResultSections(practice: practice) }.navigationTitle(
      practice.definition.name)
  }
}
struct SkillPracticeResultSections: View {
  let practice: SkillPractice
  var body: some View {
    Section(practice.definition.name) {
      LabeledContent("Step", value: practice.step?.name ?? "Recorded Step")
      LabeledContent("Origin", value: practice.origin.name)
      LabeledContent(
        "Status",
        value: practice.state == .cancelled ? "Canceled" : practice.state.rawValue.capitalized)
      LabeledContent("Format", value: practice.configuration.format.name)
      if practice.startedAt != nil {
        LabeledContent(
          "Practice Time",
          value: WorkoutLabels.elapsed(
            practice.elapsedMS(at: practice.endedAt ?? practice.lastEventAt)))
      }
      if !practice.configuration.assistance.isEmpty {
        LabeledContent("Assistance", value: practice.configuration.assistance)
      }
      ForEach(practice.attempts) { attempt in
        LabeledContent(
          "Attempt \(attempt.number)",
          value: attempt.durationMS.map { WorkoutLabels.elapsed($0) }
            ?? "\(attempt.repetitions ?? 0) reps")
      }
      if let best = practice.bestHoldMS {
        LabeledContent("Best Hold (Declared)", value: WorkoutLabels.elapsed(best))
      }
      if !practice.note.isEmpty { Text(practice.note) }
    }
  }
}
