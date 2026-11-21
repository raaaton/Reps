import RepsCore
import SwiftUI

struct ExerciseVariantsView: View {
  @EnvironmentObject private var store: TrainingStore
  let exercise: TrainingExercise
  @State private var error: String?
  @State private var archiving: ExerciseVariant?
  var body: some View {
    List {
      if case .ready(let snapshot) = store.phase {
        let variants = snapshot.variants.filter { $0.exerciseID == exercise.id }
        Section {
          ForEach(variants.filter { !$0.isArchived }) { variant in
            NavigationLink {
              ExerciseVariantEditor(variant: variant)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(variant.displayName)
                if variant.isBase {
                  Text("Base progression").font(.caption).foregroundStyle(.secondary)
                }
              }
            }
            .swipeActions(edge: .trailing) {
              if !variant.isBase {
                Button("Archive", systemImage: "archivebox") { archiving = variant }.tint(.orange)
              }
            }
          }
          NavigationLink {
            var variant = ExerciseVariant.base(for: exercise)
            let _ = {
              variant.id = UUID().uuidString
              variant.name = ""
            }()
            ExerciseVariantEditor(variant: variant)
          } label: {
            Label("Add Progression", systemImage: "plus").labelStyle(.titleAndIcon)
          }
        }
        if variants.contains(where: \.isArchived) {
          Section("Archived") {
            ForEach(variants.filter(\.isArchived)) { variant in
              Text(variant.displayName).foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle("Progressions").navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Archive Progression?",
      isPresented: Binding(get: { archiving != nil }, set: { if !$0 { archiving = nil } }),
      titleVisibility: .visible
    ) {
      if let variant = archiving {
        Button("Archive") {
          Task {
            do { try await store.archiveVariant(id: variant.id) } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Past results stay available. Choose another progression for future workouts.")
    }
    .alert(
      "Unable to Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }
}

struct ExerciseVariantEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State var variant: ExerciseVariant
  @State private var measure = ""
  @State private var unit = ""
  @State private var minimum = ""
  @State private var maximum = ""
  @State private var duration = ""
  @State private var saving = false
  @State private var error: String?
  init(variant: ExerciseVariant) {
    _variant = State(initialValue: variant)
    _measure = State(initialValue: variant.measure ?? "")
    _unit = State(initialValue: variant.unit ?? "")
    _minimum = State(initialValue: variant.minimumReps.map(String.init) ?? "8")
    _maximum = State(initialValue: variant.maximumReps.map(String.init) ?? "12")
    _duration = State(initialValue: variant.durationSeconds.map(String.init) ?? "")
  }
  var body: some View {
    Form {
      Section {
        TextField("Progression Name", text: $variant.name)
        LabeledContent("Measurement") {
          TextField("Optional", text: $measure).keyboardType(.decimalPad).multilineTextAlignment(
            .trailing
          )
          .accessibilityLabel("Measurement, optional")
        }
        LabeledContent("Unit") {
          TextField("cm", text: $unit).multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel(
              "Measurement unit")
        }
      } footer: {
        Text("Measurements identify a fixed progression. Units are kept as entered.")
      }
      Section("Targets") {
        Picker("Metric", selection: $variant.tracking) {
          Text("Repetitions").tag(TrackingMode.repetitions)
          Text("Duration").tag(TrackingMode.duration)
        }
        if variant.tracking == .repetitions {
          field("Minimum Repetitions", text: $minimum)
          field("Maximum Repetitions", text: $maximum)
        } else {
          field("Seconds per Set", text: $duration)
        }
      }
      Section {
        Text(
          "Sets are defined by each workout. Performance and added-weight goals are specific to this progression."
        ).foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Edit Progression").navigationBarTitleDisplayMode(.inline)
    .disabled(saving).interactiveDismissDisabled(saving)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        RepsConfirmationButton(title: "Save") { save() }.labelStyle(.iconOnly).disabled(saving)
      }
    }
    .alert(
      "Unable to Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }
  private func field(_ title: String, text: Binding<String>) -> some View {
    LabeledContent(title) {
      TextField(title, text: text).keyboardType(.numberPad).multilineTextAlignment(.trailing)
        .accessibilityLabel(title)
    }
  }
  private func save() {
    do {
      var result = variant
      result.measure = try VariantMeasure.parse(measure)
      result.unit = unit
      result.minimumReps = Int(minimum)
      result.maximumReps = Int(maximum)
      let seconds = duration.trimmingCharacters(in: .whitespacesAndNewlines)
      if result.tracking == .duration && !seconds.isEmpty && Int(seconds) == nil {
        throw TrainingError.invalid("Enter a duration in seconds, or leave it blank.")
      }
      result.durationSeconds = Int(seconds)
      result = try result.validated()
      saving = true
      Task {
        defer { saving = false }
        do {
          try await store.saveVariant(result)
          dismiss()
        } catch { self.error = error.localizedDescription }
      }
    } catch { self.error = error.localizedDescription }
  }
}

struct WorkoutVariantPicker: View {
  @EnvironmentObject private var store: TrainingStore
  let workout: WorkoutSession
  let exercise: WorkoutExercise
  @State private var saving = false
  @State private var error: String?
  var body: some View {
    if case .ready(let snapshot) = store.phase {
      let variants = snapshot.variants.filter {
        $0.exerciseID == exercise.definition.parentExerciseID && !$0.isArchived
      }
      if variants.count > 1 {
        Section {
          Picker(
            "Progression",
            selection: Binding(
              get: { exercise.definition.variantID },
              set: { id in
                saving = true
                Task {
                  defer { saving = false }
                  do {
                    try await store.selectWorkoutVariant(
                      workoutID: workout.id, exerciseID: exercise.id, variantID: id)
                  } catch { self.error = error.localizedDescription }
                }
              })
          ) {
            ForEach(variants) { variant in Text(variant.displayName).tag(variant.id) }
          }.pickerStyle(.menu)
            .disabled(saving || !exercise.canChangeVariant)
            .accessibilityHint(
              exercise.canChangeVariant
                ? "Choose before starting the first set" : "Progression locked for this workout")
        } footer: {
          if !exercise.canChangeVariant { Text("Progression locked after the first set starts.") }
        }
        .alert(
          "Unable to Change Progression",
          isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(error ?? "")
        }
      }
    }
  }
}
