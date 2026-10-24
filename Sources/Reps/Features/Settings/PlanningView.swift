import RepsCore
import SwiftUI

struct PlanningView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var editing: TrainingSchedule?
  @State private var deleting: TrainingSchedule?
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    TrainingContent { snapshot in
      List {
        Section {
          ForEach(snapshot.schedules) { schedule in
            Button {
              editing = schedule
            } label: {
              TrainingListRow(
                title: schedule.name, subtitle: TrainingLabels.weekday(schedule.weekday),
                status: schedule.isEnabled ? nil : "Disabled")
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", systemImage: "trash", role: .destructive) { deleting = schedule }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.automatic)
            }
            .contextMenu {
              Button("Edit", systemImage: "pencil") { editing = schedule }
              RepsDestructiveButton("Delete", systemImage: "trash") { deleting = schedule }
            }
          }
          if snapshot.schedules.isEmpty {
            ContentUnavailableView(
              "No Workouts", systemImage: "calendar",
              description: Text("Add a workout with the + button."))
          }
        } footer: {
          Text(
            snapshot.schedules.count == 7
              ? "All seven days are occupied. Delete a workout to free a day."
              : "One workout per day. Tap a workout to edit it.")
        }
      }
      .disabled(busy)
      .sheet(item: $editing) { schedule in
        NavigationStack {
          ScheduleEditor(
            schedule: schedule, snapshot: snapshot,
            isNew: !snapshot.schedules.contains { $0.id == schedule.id })
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Workout", systemImage: "plus") {
            if let day = (1...7).first(where: { day in
              !snapshot.schedules.contains { $0.weekday == day }
            }) {
              editing = TrainingSchedule(
                id: UUID().uuidString, name: "", weekday: day,
                isEnabled: snapshot.exercises.contains { $0.isEnabled },
                reminderMinutes: nil, exerciseIDs: [])
            }
          }.tint(.white)
            .disabled(busy || snapshot.schedules.count == 7)
        }
      }
      .repsConfirmation(
        "Delete This Workout?",
        isPresented: Binding(
          get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), presenting: deleting
      ) { schedule in
        Button("Delete Workout", role: .destructive) { delete(schedule) }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: { schedule in
        Text(
          "“\(schedule.name)” will be removed from the schedule. Its exercises will be kept."
        )
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
    .navigationTitle("Workouts")
  }

  private func delete(_ schedule: TrainingSchedule) {
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteSchedule(id: schedule.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

struct ScheduleEditor: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TrainingStore
  @State private var draft: TrainingSchedule
  @State private var selecting = false
  @State private var saving = false
  @State private var error: String?
  @State private var editMode: EditMode = .inactive
  @State private var reminderRequested: Bool
  @State private var choosingTime = false
  @State private var skillDraft: SkillAssignment?
  @State private var newSkillBlock = false
  @State private var chosenTime = Date()
  let snapshot: TrainingSnapshot
  let isNew: Bool

  init(schedule: TrainingSchedule, snapshot: TrainingSnapshot, isNew: Bool = false) {
    _draft = State(initialValue: schedule)
    _reminderRequested = State(initialValue: schedule.reminderMinutes != nil)
    self.snapshot = snapshot
    self.isNew = isNew
  }

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $draft.name)
        Picker("Day", selection: $draft.weekday) {
          ForEach(1...7, id: \.self) { day in
            if !snapshot.schedules.contains(where: { $0.id != draft.id && $0.weekday == day }) {
              Text(TrainingLabels.weekday(day)).tag(day)
            }
          }
        }
        Toggle("Workout Enabled", isOn: $draft.isEnabled)
      }
      Section {
        ForEach(draft.exerciseIDs, id: \.self) { id in
          if let exercise = snapshot.exercises.first(where: { $0.id == id }) {
            WorkoutExerciseRow(
              exercise: exercise,
              setCount: Binding(
                get: { draft.setCounts[id] ?? 4 },
                set: { draft.setCounts[id] = $0 }))
          }
        }
        .onMove { draft.exerciseIDs.move(fromOffsets: $0, toOffset: $1) }
        .onDelete { offsets in
          for index in offsets { draft.setCounts.removeValue(forKey: draft.exerciseIDs[index]) }
          draft.exerciseIDs.remove(atOffsets: offsets)
        }
        Button("Choose Exercises", systemImage: "plus") { selecting = true }
          .moveDisabled(true).deleteDisabled(true)
      } header: {
        HStack {
          Text("Exercises")
          Spacer()
          EditButton().textCase(nil)
        }
      }
      ScheduleSkillSection(schedule: $draft, definitions: snapshot.skills) { assignment, isNew in
        newSkillBlock = isNew
        skillDraft = assignment
      }
      Section {
        Toggle("Add a Reminder", isOn: $reminderRequested)
        if reminderRequested, let minutes = draft.reminderMinutes {
          DatePicker(
            "Time",
            selection: Binding(
              get: { TrainingLabels.time(minutes) },
              set: {
                let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                draft.reminderMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
              }
            ), displayedComponents: .hourAndMinute)
        } else if reminderRequested {
          Button("Choose a Time", systemImage: "clock") { choosingTime = true }
        }
      } footer: {
        Text(
          "Enable workout reminders in Settings → Notifications. Starting a workout removes its reminder for that day."
        )
      }
    }
    .environment(\.editMode, $editMode)
    .disabled(saving)
    .navigationTitle(isNew ? "New Workout" : "Edit Workout")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
          .iconOnly
        ).disabled(saving)
      }
      ToolbarItem(placement: .confirmationAction) {
        RepsConfirmationButton(title: "Save") {
          save()
        }.labelStyle(.iconOnly).disabled(saving)
      }
    }
    .interactiveDismissDisabled(saving)
    .sheet(item: $skillDraft) { assignment in
      NavigationStack {
        SkillBlockEditor(assignment: assignment, definitions: snapshot.skills, isNew: newSkillBlock)
        { saved in
          if let index = draft.skills.firstIndex(where: { $0.id == saved.id }) {
            draft.skills[index] = saved
          } else {
            draft.skills.append(saved)
          }
          skillDraft = nil
        }
      }.environment(\.editMode, .constant(.inactive))
    }
    .sheet(isPresented: $selecting) {
      NavigationStack {
        List {
          if !snapshot.exercises.contains(where: { $0.isEnabled }) {
            ContentUnavailableView(
              "No Active Exercises", systemImage: "figure.strengthtraining.traditional",
              description: Text("Add or enable an exercise in Settings → Exercises."))
          }
          ForEach(snapshot.exercises.filter(\.isEnabled)) { exercise in
            Toggle(
              exercise.name,
              isOn: Binding(
                get: { draft.exerciseIDs.contains(exercise.id) },
                set: { selected in
                  if selected {
                    draft.exerciseIDs.append(exercise.id)
                    draft.setCounts[exercise.id] = 4
                  } else {
                    draft.exerciseIDs.removeAll { $0 == exercise.id }
                    draft.setCounts.removeValue(forKey: exercise.id)
                  }
                }
              ))
          }
        }
        .navigationTitle("Choose Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            RepsConfirmationButton(title: "Done") {
              selecting = false
            }.labelStyle(.iconOnly)
          }
        }
      }
    }
    .sheet(isPresented: $choosingTime) {
      NavigationStack {
        DatePicker("Reminder Time", selection: $chosenTime, displayedComponents: .hourAndMinute)
          .datePickerStyle(.wheel)
          .padding()
          .navigationTitle("Reminder Time")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel", systemImage: "xmark") { choosingTime = false }.foregroundStyle(
                .white
              ).labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Choose") {
                let components = Calendar.current.dateComponents(
                  [.hour, .minute], from: chosenTime)
                draft.reminderMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                choosingTime = false
              }
            }
          }
      }
      .presentationDetents([.medium, .large])
    }
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
    guard !reminderRequested || draft.reminderMinutes != nil else {
      error = "Choose a time for this reminder, or turn it off."
      return
    }
    var schedule = draft
    if !reminderRequested { schedule.reminderMinutes = nil }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await store.saveSchedule(schedule, creating: isNew)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
