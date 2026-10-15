import SportCore
import SwiftUI

private struct HistoricalSetDraft: Identifiable {
  let id = UUID()
  var performance = ""
  var weight = "0"
  var sourceID: String? = nil
}

private struct HistoricalExerciseDraft: Identifiable {
  let definition: TrainingExercise
  var id: String { definition.id }
  var sets = [HistoricalSetDraft()]
  var feeling = ""
  var originalFeeling: Int? = nil

  func entry(allowMissingFeeling: Bool) throws -> ManualWorkoutExercise {
    let tenths: Int?
    do {
      tenths = allowMissingFeeling && feeling.isEmpty ? nil : try WorkoutFeeling.tenths(feeling)
    } catch {
      throw TrainingError.invalid(
        "\(definition.name) : enter Feeling from 0 to 10 in 0.5 steps.")
    }
    if let tenths, tenths % 5 != 0, tenths != originalFeeling {
      throw TrainingError.invalid(
        "Enter Feeling in 0.5 steps. Older ratings are kept exactly unless you edit them."
      )
    }
    let performances = try sets.enumerated().map { index, set in
      let grams = try WorkoutWeight.grams(set.weight)
      if definition.tracking == .repetitions {
        guard let reps = Int(set.performance.trimmingCharacters(in: .whitespacesAndNewlines)),
          reps > 0
        else {
          throw TrainingError.invalid(
            "\(definition.name), set \(index + 1): enter at least one repetition.")
        }
        return ManualWorkoutSet(repetitions: reps, weightGrams: grams, sourceID: set.sourceID)
      }
      // The same exact decimal scale converts seconds to milliseconds, without floating point.
      let duration: Int
      do { duration = try WorkoutWeight.grams(set.performance) } catch {
        throw TrainingError.invalid(
          "\(definition.name), set \(index + 1): enter a duration in seconds, with up to three decimal places."
        )
      }
      guard duration > 0 else {
        throw TrainingError.invalid("Each set must have a positive duration.")
      }
      return ManualWorkoutSet(durationMS: duration, weightGrams: grams, sourceID: set.sourceID)
    }
    return ManualWorkoutExercise(
      catalogueID: id, tracking: definition.tracking,
      sets: performances, feelingTenths: tenths)
  }
}

struct ManualWorkoutEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  let original: WorkoutSession?
  @State private var id = UUID().uuidString
  @State private var name = ""
  @State private var date = Date()
  @State private var exercises: [HistoricalExerciseDraft] = []
  @State private var choosingExercises = false
  @State private var saving = false
  @State private var error: String?
  @FocusState private var nameFocused: Bool

  init(workout: WorkoutSession? = nil) {
    original = workout
    guard let workout else { return }
    _id = State(initialValue: workout.id)
    _name = State(initialValue: workout.name)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let parts = workout.dayKey.split(separator: "-").compactMap { Int($0) }
    let selectedDate =
      parts.count == 3
      ? calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) : nil
    _date = State(initialValue: selectedDate ?? WorkoutClock.date(workout.startedAt))
    _exercises = State(
      initialValue: workout.exercises.map { exercise in
        HistoricalExerciseDraft(
          definition: exercise.definition,
          sets: exercise.sets.map { set in
            HistoricalSetDraft(
              performance: set.repetitions.map(String.init)
                ?? WorkoutLabels.weight(set.durationMS ?? 0),
              weight: WorkoutLabels.weight(set.weightGrams), sourceID: set.id)
          }, feeling: exercise.feelingTenths.map(WorkoutLabels.feeling) ?? "",
          originalFeeling: exercise.feelingTenths)
      })
  }

  var body: some View {
    NavigationStack {
      TrainingContent { snapshot in
        Form {
          Section {
            TextField("Workout Name", text: $name).focused($nameFocused)
            DatePicker(
              "Date", selection: $date, in: WorkoutClock.date(0)...Date(),
              displayedComponents: .date)
          } footer: {
            Text(
              original == nil
                ? "Record a past workout without starting live tracking."
                : "Edit recorded values. Workout status and other workouts will be kept."
            )
          }
          Section("Completed Exercises") {
            ForEach($exercises) { $exercise in
              NavigationLink {
                HistoricalExerciseEditor(exercise: $exercise)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(exercise.definition.name).foregroundStyle(.primary)
                  Text(
                    "\(exercise.sets.count) sets · \(exercise.feeling.isEmpty ? "Feeling needed" : "Feeling \(exercise.feeling)")"
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                }
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Remove", systemImage: "trash", role: .destructive) {
                  exercises.removeAll { $0.id == exercise.id }
                }
              }
            }
            Button("Add Exercises", systemImage: "plus") {
              nameFocused = false
              choosingExercises = true
            }
            .disabled(snapshot.exercises.isEmpty)
            if snapshot.exercises.isEmpty {
              Text("Add an exercise in Settings → Exercises first.").foregroundStyle(
                .secondary)
            }
          }
          Section {
            Text(
              "Open each exercise to enter repetitions or duration, added weight and Feeling."
            )
            .foregroundStyle(.secondary)
          }
        }
        .disabled(saving)
        .sheet(isPresented: $choosingExercises) {
          HistoricalExercisePicker(
            available: availableExercises(snapshot), selectedIDs: Set(exercises.map(\.id))
          ) { selected in
            exercises.removeAll { !selected.contains($0.id) }
            for definition in availableExercises(snapshot)
            where selected.contains(definition.id)
              && !exercises.contains(where: { $0.id == definition.id })
            {
              exercises.append(HistoricalExerciseDraft(definition: definition))
            }
          }
        }
      }
      .navigationTitle(original == nil ? "New Workout" : "Edit Workout")
      .navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(saving)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly
          ).disabled(
            saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(saving ? "Saving…" : "Save", systemImage: "checkmark") { save() }
            .labelStyle(.iconOnly)
            .disabled(
              saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || exercises.isEmpty)
        }
      }
      .alert(
        "Workout Not Saved",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
  }

  private func availableExercises(_ snapshot: TrainingSnapshot) -> [TrainingExercise] {
    let archived = original?.exercises.map(\.definition) ?? []
    return archived + snapshot.exercises.filter { item in !archived.contains { $0.id == item.id } }
  }

  private func save() {
    guard !saving else { return }
    nameFocused = false
    saving = true
    Task {
      defer { saving = false }
      do {
        let time = Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 * 1000)
        let draft = ManualWorkout(
          id: id, name: name, performedAt: time,
          exercises: try exercises.map {
            try $0.entry(allowMissingFeeling: original?.status == .cancelled)
          })
        if let original {
          try await store.updateHistoricalWorkout(draft, original: original)
        } else {
          try await store.addHistoricalWorkout(draft)
        }
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}

private struct HistoricalExercisePicker: View {
  @Environment(\.dismiss) private var dismiss
  let available: [TrainingExercise]
  let onSelect: (Set<String>) -> Void
  @State private var selected: Set<String>

  init(
    available: [TrainingExercise], selectedIDs: Set<String>,
    onSelect: @escaping (Set<String>) -> Void
  ) {
    self.available = available
    self.onSelect = onSelect
    _selected = State(initialValue: selectedIDs)
  }

  var body: some View {
    NavigationStack {
      List(available) { exercise in
        Button {
          if selected.contains(exercise.id) {
            selected.remove(exercise.id)
          } else {
            selected.insert(exercise.id)
          }
        } label: {
          HStack {
            Text(exercise.name).foregroundStyle(.primary)
            Spacer()
            if selected.contains(exercise.id) {
              Image(systemName: "checkmark").foregroundStyle(.tint)
            }
          }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected.contains(exercise.id) ? .isSelected : [])
      }
      .navigationTitle("Exercises")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            onSelect(selected)
            dismiss()
          }
        }
      }
    }
  }
}

private struct HistoricalExerciseEditor: View {
  @Binding var exercise: HistoricalExerciseDraft
  @FocusState private var focused: Bool

  var body: some View {
    Form {
      Section {
        ForEach($exercise.sets) { $set in
          VStack(alignment: .leading, spacing: 12) {
            let number = (exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1
            Text("Set \(number)").font(.headline)
            LabeledContent(
              exercise.definition.tracking == .duration ? "Duration (s)" : "Repetitions"
            ) {
              TextField(
                exercise.definition.tracking == .duration ? "30,5" : "10", text: $set.performance
              )
              .keyboardType(exercise.definition.tracking == .duration ? .decimalPad : .numberPad)
              .multilineTextAlignment(.trailing).focused($focused)
              .accessibilityLabel(
                "Set \(number), \(exercise.definition.tracking == .duration ? "duration in seconds" : "completed repetitions")"
              )
            }
            LabeledContent("Added Weight (kg)") {
              TextField("0", text: $set.weight).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).focused($focused)
                .accessibilityLabel("Set \(number), added weight in kilograms")
            }
          }.padding(.vertical, 4)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Remove", systemImage: "trash", role: .destructive) {
                focused = false
                exercise.sets.removeAll { $0.id == set.id }
              }
            }
        }
        Button("Add Set", systemImage: "plus") {
          exercise.sets.append(HistoricalSetDraft())
        }
      } header: {
        Text("Completed Sets")
      } footer: {
        Text("Swipe left on a set to remove it from the draft.")
      }
      Section {
        LabeledContent("Feeling / 10") {
          TextField("From 0 to 10", text: $exercise.feeling)
            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused)
            .accessibilityLabel("Feeling from 0 to 10, in 0.5 steps")
        }
      } header: {
        Text("Feeling")
      } footer: {
        Text(
          "0: no effort · 10: maximum effort. Enter Feeling in 0.5 steps, for example 7.5."
        )
      }
    }
    .navigationTitle(exercise.definition.name)
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
          focused = false
        }.tint(.white)
          .labelStyle(.iconOnly)
      }
    }
  }
}
