import SportCore
import SwiftUI

struct SkillPracticeView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let practiceID: String
  var body: some View {
    Group {
      if let practice = store.skillHistory.first(where: { $0.id == practiceID }) {
        if practice.state.isTerminal {
          SkillPracticeResultView(practice: practice)
        } else {
          SkillPracticeContent(practice: practice)
        }
      } else {
        ContentUnavailableView(
          "Practice Unavailable", systemImage: "figure.gymnastics",
          description: Text("Return to Skills and choose a practice."))
      }
    }
    .navigationTitle("Practice").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        SkillToolbarButton(title: "Close", cancel: true) { dismiss() }
      }
    }
  }
}

struct SkillPracticeContent: View {
  @EnvironmentObject private var store: TrainingStore
  let practice: SkillPractice
  @State private var busy = false
  @State private var error: String?
  @State private var repetitions = ""
  @State private var note = ""
  @State private var bestHold = ""
  @State private var finishing = false
  @State private var cancelConfirm = false
  @State private var configuring = false
  private var definition: SkillDefinition { practice.definition.americanEnglish }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let now = Int(context.date.timeIntervalSince1970 * 1000)
      List {
        Section {
          Text(definition.name).font(.title2).fontWeight(.semibold)
          Text(practice.step?.name ?? "Skill Practice").font(.headline)
          Text(practice.configuration.format.name).foregroundStyle(.secondary)
          if !practice.configuration.assistance.isEmpty {
            Text(practice.configuration.assistance).foregroundStyle(.secondary)
          }
        }
        if practice.state == .preparation {
          Section("Preparation") {
            Text(
              definition.preparation.isEmpty
                ? "No preparation instructions have been added for this personal skill."
                : definition.preparation)
            Button("Ready to Practice", systemImage: "checkmark") { apply(.acknowledgePreparation) }
          }
        } else {
          Section {
            switch practice.state {
            case .ready:
              if practice.configuration.format == .freePractice {
                Button("Begin Practice", systemImage: "play.fill") { apply(.begin) }
              } else if practice.attempts.count < practice.configuration.attemptCount {
                Text(
                  "Attempt \(practice.attempts.count + 1) of \(practice.configuration.attemptCount)"
                )
                if let target = practice.configuration.targetSeconds,
                  practice.configuration.format == .timedHolds
                {
                  Text("Target: \(target) sec")
                }
                if let target = practice.configuration.targetRepetitions,
                  practice.configuration.format == .repetitions
                {
                  Text("Target: \(target) reps")
                }
                Button("Begin Attempt", systemImage: "play.fill") { apply(.beginAttempt) }
              } else {
                Text("Planned attempts recorded. Finish when ready.")
              }
            case .practicing:
              LabeledContent(
                "Practice Time", value: WorkoutLabels.elapsed(practice.elapsedMS(at: now)))
              if let reference = practice.configuration.referenceSeconds {
                Text("Reference: \(WorkoutLabels.elapsed(reference * 1000)) · finish when ready")
                  .font(.subheadline).foregroundStyle(.secondary)
              }
              Button("Pause", systemImage: "pause.fill") { apply(.pause) }
            case .paused:
              Text("Paused").font(.headline)
              Button("Resume", systemImage: "play.fill") { apply(.resume) }
            case .countdown:
              if practice.countdown(at: now) > 0 {
                Text("Ready in \(practice.countdown(at: now))").font(.largeTitle.monospacedDigit())
                Button("Cancel Countdown", systemImage: "xmark") { apply(.cancelCountdown) }
              } else {
                LabeledContent(
                  "Hold Time",
                  value: WorkoutLabels.elapsed(max(0, now - (practice.attemptStartedAt ?? now))))
                Button("Finish Hold", systemImage: "checkmark") {
                  apply(.recordAttempt(repetitions: nil))
                }
              }
            case .attempt:
              TextField("Actual Repetitions", text: $repetitions).keyboardType(.numberPad)
              Button("Record Attempt", systemImage: "checkmark") {
                guard let count = Int(repetitions) else {
                  error = "Enter the repetitions you performed."
                  return
                }
                apply(.recordAttempt(repetitions: count))
                repetitions = ""
              }
            case .resting:
              LabeledContent("Rest", value: WorkoutLabels.elapsed(practice.restRemaining(at: now)))
              if practice.restRemaining(at: now) > 0 {
                Button("Pause Rest", systemImage: "pause.fill") { apply(.changeRest(.pause)) }
                Button("Skip Rest", systemImage: "forward.end.fill") { apply(.changeRest(.skip)) }
              } else {
                Button("Continue", systemImage: "play.fill") { apply(.beginAttempt) }
              }
            default: EmptyView()
            }
          }
        }
        if let step = definition.steps.first(where: { $0.id == practice.assignment.stepID }) {
          DisclosureGroup("How to Practice") {
            Text(step.instructions)
            if !step.cues.isEmpty { Text(step.cues).foregroundStyle(.secondary) }
            if !step.suggestedPractice.isEmpty { Text(step.suggestedPractice).font(.subheadline) }
            if !step.equipment.isEmpty { LabeledContent("Equipment", value: step.equipment) }
            if let link = step.sourceURL, let url = URL(string: link), url.scheme == "https" {
              SkillDemonstrationLink(url: url)
            }
          }
        }
        Section {
          if practice.startedAt == nil {
            Button("Adjust This Block", systemImage: "slider.horizontal.3") { configuring = true }
          }
          if practice.startedAt != nil, practice.state != .countdown, practice.state != .attempt {
            Button("Finish Practice", systemImage: "checkmark") { openFinish() }
          }
          Button("Skip This Block", systemImage: "forward.end.fill") { apply(.skip) }
          SkillDestructiveButton(title: "Cancel Practice", systemImage: "xmark.circle") {
            cancelConfirm = true
          }
        }
        if let error { Section { Text(error).foregroundStyle(.secondary) } }
      }
      .disabled(busy)
      .scrollDismissesKeyboard(.interactively)
    }
    .sheet(isPresented: $finishing) {
      NavigationStack {
        Form {
          Section {
            TextField("Note (Optional)", text: $note, axis: .vertical)
            TextField("Best Hold in Seconds (Optional, Declared)", text: $bestHold).keyboardType(
              .decimalPad)
          } footer: {
            Text("Practice time includes natural rests and is separate from a hold duration.")
          }
          if let error { Text(error).foregroundStyle(.secondary) }
        }
        .navigationTitle("Finish Practice").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            SkillToolbarButton(title: "Back", cancel: true) { finishing = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            SkillToolbarButton {
              var declared: Int?
              if !bestHold.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let seconds = Double(bestHold.replacingOccurrences(of: ",", with: ".")),
                  seconds.isFinite, seconds > 0, seconds <= 86400
                else {
                  error = "Enter a positive duration in seconds."
                  return
                }
                declared = Int((seconds * 1000).rounded())
              }
              apply(.finish(note: note, bestHoldMS: declared), dismissFinish: true)
            }.disabled(busy)
          }
        }
        .interactiveDismissDisabled(busy)
      }
    }
    .sheet(isPresented: $configuring) {
      NavigationStack { SkillPracticeConfiguration(practice: practice) }
    }
    .sportConfirmation("Cancel This Practice?", isPresented: $cancelConfirm) {
      Button("Cancel Practice", role: .destructive) { apply(.cancel) }
      Button("Keep Practicing", role: .cancel) {}
    } message: {
      Text("Already recorded attempts will be kept.")
    }
  }
  private func openFinish() {
    guard practice.state != .paused else {
      finishing = true
      return
    }
    busy = true
    Task {
      defer { busy = false }
      do {
        try await store.applySkillAction(.pause, practice: practice)
        finishing = true
        error = nil
      } catch { self.error = error.localizedDescription }
    }
  }
  private func apply(_ action: SkillAction, dismissFinish: Bool = false) {
    busy = true
    Task {
      defer { busy = false }
      do {
        try await store.applySkillAction(action, practice: practice)
        error = nil
        if dismissFinish { finishing = false }
      } catch { self.error = error.localizedDescription }
    }
  }
}

private struct SkillPracticeConfiguration: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let practice: SkillPractice
  @State private var assignment: SkillAssignment
  @State private var busy = false
  @State private var error: String?
  init(practice: SkillPractice) {
    self.practice = practice
    _assignment = State(initialValue: practice.assignment)
  }
  var body: some View {
    Form {
      Section {
        Picker("Step", selection: $assignment.stepID) {
          ForEach(practice.definition.steps) { Text($0.name).tag($0.id) }
        }
        SkillConfigurationFields(value: $assignment.configuration)
      } footer: {
        Text("These changes apply only to this practice. Edit the workout to change future blocks.")
      }
      if let error { Section { Text(error).foregroundStyle(.secondary) } }
    }
    .navigationTitle("This Practice").navigationBarTitleDisplayMode(.inline)
    .disabled(busy)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        SkillToolbarButton(title: "Cancel", cancel: true) { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        SkillToolbarButton {
          busy = true
          Task {
            defer { busy = false }
            do {
              try await store.applySkillAction(
                .reviseConfiguration(assignment.configuration), practice: practice)
              if let latest = store.skillHistory.first(where: { $0.id == practice.id }),
                latest.assignment.stepID != assignment.stepID
              {
                try await store.applySkillAction(.reviseStep(assignment.stepID), practice: latest)
              }
              dismiss()
            } catch { self.error = error.localizedDescription }
          }
        }.disabled(busy)
      }
    }
    .interactiveDismissDisabled(busy)
  }
}
