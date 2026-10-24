import RepsCore
import SwiftUI

struct WeightSelectionRow: View {
  @EnvironmentObject private var store: TrainingStore
  @Binding var selection: AvailableLoad
  @State private var choosing = false
  var body: some View {
    Button {
      choosing = true
    } label: {
      HStack {
        Text("Added Weight").foregroundStyle(.primary)
        Spacer()
        Text(
          selection.grams == 0 ? "Bodyweight" : "\(WorkoutLabels.weight(selection.grams)) kg"
        )
        .foregroundStyle(.secondary)
        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
      }.contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Added Weight")
    .accessibilityValue("\(WorkoutLabels.weight(selection.grams)) kilograms")
    .sheet(isPresented: $choosing) {
      LoadPicker(
        loads: store.loadChoices(retaining: selection),
        selected: selection
      ) { selection = $0 }
    }
  }
}

private struct LoadPicker: View {
  @Environment(\.dismiss) private var dismiss
  let loads: [AvailableLoad]
  let selected: AvailableLoad
  let onSelect: (AvailableLoad) -> Void
  var body: some View {
    NavigationStack {
      List(loads) { load in
        Button {
          onSelect(load)
          dismiss()
        } label: {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              Text(load.grams == 0 ? "Bodyweight" : "\(WorkoutLabels.weight(load.grams)) kg")
                .foregroundStyle(.primary)
              if load.grams != 0 {
                Text(load.components.map(\.displayName).joined(separator: " + ")).font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            if load == selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
          }.contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityAddTraits(load == selected ? .isSelected : [])
      }
      .navigationTitle("Added Weight").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly)
        }
      }
    }
  }
}
