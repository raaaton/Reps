import SportCore
import SwiftUI

struct ExercisesView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var editing: TrainingExercise?
  @State private var deleting: TrainingExercise?
  @State private var archived: [TrainingExercise] = []
  @State private var deletingArchived: TrainingExercise?
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    TrainingContent { snapshot in
      let old = archived.filter { item in !snapshot.exercises.contains { $0.id == item.id } }
      List {
        Section {
          ForEach(snapshot.exercises) { exercise in
            Button {
              editing = exercise
            } label: {
              TrainingListRow(
                title: exercise.name,
                subtitle: exercise.isEnabled ? TrainingLabels.metric(exercise) : "Disabled")
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", systemImage: "trash", role: .destructive) { deleting = exercise }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.automatic)
            }
            .contextMenu {
              Button("Edit", systemImage: "pencil") { editing = exercise }
              SportDestructiveButton("Delete", systemImage: "trash") { deleting = exercise }
            }
          }
          if snapshot.exercises.isEmpty {
            ContentUnavailableView(
              "No Exercises", systemImage: "figure.strengthtraining.traditional",
              description: Text("Add an exercise with the + button."))
          }
        } footer: {
          Text(
            "Set the number of sets in each workout. After adding an exercise, select it in Workouts."
          )
        }
        if !old.isEmpty {
          Section("Archived") {
            ForEach(old) { exercise in
              NavigationLink {
                ExerciseProgressView(exercise: exercise)
              } label: {
                TrainingListRow(title: exercise.name, subtitle: "Archived exercise")
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                  deletingArchived = exercise
                }.labelStyle(.titleAndIcon)
              }
              .contextMenu {
                SportDestructiveButton("Delete", systemImage: "trash") {
                  deletingArchived = exercise
                }
              }
            }
          }
        }
      }
      // iOS List batch updates crashed when deletion moved a row into/out of Archivés.
      // Recreate only this List when its membership changes; keep alerts and editor outside.
      .id([snapshot.exercises.map(\.id), old.map(\.id)])
      .disabled(busy)
      .sheet(item: $editing) { exercise in
        NavigationStack {
          ExerciseEditor(
            exercise: exercise, isNew: !snapshot.exercises.contains { $0.id == exercise.id })
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Exercise", systemImage: "plus") {
            editing = TrainingExercise(
              id: UUID().uuidString, name: "", tracking: .repetitions,
              setCount: 4, minimumReps: 8, maximumReps: 12, durationSeconds: nil, isEnabled: true)
          }.tint(.white)
            .disabled(busy)
        }
      }
      .sportConfirmation(
        "Delete This Exercise?",
        isPresented: Binding(
          get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), presenting: deleting
      ) { exercise in
        Button("Delete Exercise", role: .destructive) { delete(exercise) }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: { exercise in
        Text(deletionMessage(exercise, snapshot: snapshot))
      }
      .alert(
        "Unable to Delete",
        isPresented: Binding(
          get: { error != nil }, set: { if !$0 { error = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(error ?? "")
      }
    }
    .navigationTitle("Exercises")
    .modifier(ArchivedExerciseDeletion(selection: $deletingArchived))
    .task(id: store.historyRevision) {
      do {
        let result = try await store.historyExercises()
        guard !Task.isCancelled else { return }
        archived = result
      } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
  }

  private func deletionMessage(_ exercise: TrainingExercise, snapshot: TrainingSnapshot) -> String {
    var message = "“\(exercise.name)” will be deleted."
    message += " Its past results will remain in Archived exercises."
    let affected = snapshot.schedules.filter { $0.exerciseIDs.contains(exercise.id) }
    if !affected.isEmpty {
      message +=
        "\n\nIt will be removed from these workouts: \(affected.map(\.name).joined(separator: ", "))."
    }
    let emptied = snapshot.schedulesEmptied(removingExerciseID: exercise.id)
    if !emptied.isEmpty {
      message +=
        "\n\nThese workouts will have no active exercises and will be disabled: \(emptied.map(\.name).joined(separator: ", "))."
    }
    return message
  }

  private func delete(_ exercise: TrainingExercise) {
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteExercise(id: exercise.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

struct ExerciseEditor: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TrainingStore
  @State private var draft: TrainingExercise
  @State private var minimum: String
  @State private var maximum: String
  @State private var duration: String
  @State private var saving = false
  @State private var error: String?
  let isNew: Bool

  init(exercise: TrainingExercise, isNew: Bool) {
    _draft = State(initialValue: exercise)
    _minimum = State(initialValue: String(exercise.minimumReps ?? 8))
    _maximum = State(initialValue: String(exercise.maximumReps ?? 12))
    _duration = State(initialValue: exercise.durationSeconds.map(String.init) ?? "")
    self.isNew = isNew
  }

  var body: some View {
    Form {
      Section {
        TextField("Exercise Name", text: $draft.name)
        Toggle("Exercise Enabled", isOn: $draft.isEnabled)
      }
      Section("Goals") {
        Picker("Metric", selection: $draft.tracking) {
          Text("Repetitions").tag(TrackingMode.repetitions)
          Text("Duration").tag(TrackingMode.duration)
        }
        if draft.tracking == .repetitions {
          LabeledContent("Minimum Repetitions") {
            TextField("8", text: $minimum).keyboardType(.numberPad).multilineTextAlignment(
              .trailing
            )
            .accessibilityLabel("Minimum Repetitions")
          }
          LabeledContent("Maximum Repetitions") {
            TextField("12", text: $maximum).keyboardType(.numberPad).multilineTextAlignment(
              .trailing
            )
            .accessibilityLabel("Maximum Repetitions")
          }
        } else {
          LabeledContent("Seconds per Set") {
            TextField("Untimed", text: $duration).keyboardType(.numberPad).multilineTextAlignment(
              .trailing
            )
            .accessibilityLabel("Seconds per set, optional")
          }
          Text("Leave the duration blank to time each set without a target.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    .disabled(saving)
    .navigationTitle(isNew ? "New Exercise" : "Edit Exercise")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
          .iconOnly
        ).disabled(saving)
      }
      ToolbarItem(placement: .confirmationAction) {
        SportConfirmationButton(title: "Save") {
          save()
        }.labelStyle(.iconOnly).disabled(saving)
      }
    }
    .interactiveDismissDisabled(saving)
    .alert(
      "Unable to Save",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }

  private func save() {
    do {
      var exercise = draft
      switch exercise.tracking {
      case .repetitions:
        exercise.minimumReps = Int(minimum)
        exercise.maximumReps = Int(maximum)
      case .duration:
        let value = duration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, Int(value) == nil {
          throw TrainingError.invalid("Enter a duration in seconds, or leave it blank.")
        }
        exercise.durationSeconds = Int(value)
      }
      let validated = try exercise.validated()
      saving = true
      Task {
        defer { saving = false }
        do {
          try await store.saveExercise(validated)
          dismiss()
        } catch { self.error = error.localizedDescription }
      }
    } catch { self.error = error.localizedDescription }
  }
}
