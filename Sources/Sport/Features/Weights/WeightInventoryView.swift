import SportCore
import SwiftUI

struct WeightInventoryView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var editing: WeightItem?
  @State private var deleting: WeightItem?
  @State private var busy = false
  @State private var error: String?
  var body: some View {
    TrainingContent { snapshot in
      List {
        Section {
          LabeledContent("Backpack", value: "3 kg")
        } footer: {
          Text("Fixed weight, added once to each weighted combination.")
        }
        Section("Items") {
          if snapshot.weightItems.isEmpty {
            Text("Add an item with +.").foregroundStyle(.secondary)
          }
          ForEach(snapshot.weightItems) { item in
            Button {
              editing = item
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.name).foregroundStyle(.primary)
                  Text(
                    "\(WorkoutLabels.weight(item.grams)) kg\(item.isEnabled ? "" : " · Disabled")"
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
              }.contentShape(Rectangle())
            }.buttonStyle(.plain)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = item }
              }
              .contextMenu {
                Button("Edit", systemImage: "pencil") { editing = item }
                SportDestructiveButton("Delete", systemImage: "trash") { deleting = item }
              }
          }
        }
        Section("Available Loads") {
          ForEach(store.availableLoads) { load in
            if load.grams == 0 {
              Text("Bodyweight · 0 kg")
            } else {
              DisclosureGroup("\(WorkoutLabels.weight(load.grams)) kg") {
                ForEach(load.components) { component in
                  LabeledContent(
                    component.name, value: "\(WorkoutLabels.weight(component.grams)) kg")
                }
              }
            }
          }
        }
      }
      .disabled(busy)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Item", systemImage: "plus") {
            editing = WeightItem(id: UUID().uuidString, name: "", grams: 0, isEnabled: true)
          }.tint(.white)
        }
      }
      .sheet(item: $editing) { WeightItemEditor(item: $0) }
      .sportConfirmation(
        "Delete This Item?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        presenting: deleting
      ) { item in
        Button("Delete", role: .destructive) { remove(item) }
        Button("Cancel", role: .cancel) { deleting = nil }
      } message: { item in
        Text(
          "“\(item.name)” will no longer be available. Recorded loads and compositions will be kept."
        )
      }
      .alert(
        "Unable to Update",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK", role: .cancel) { error = nil }
      } message: {
        Text(error ?? "")
      }
    }
    .navigationTitle("Added Weight")
  }
  private func remove(_ item: WeightItem) {
    deleting = nil
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteWeightItem(id: item.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

private struct WeightItemEditor: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dismiss) private var dismiss
  @State private var item: WeightItem
  @State private var weight: String
  @State private var saving = false
  @State private var error: String?
  @FocusState private var focused: Bool
  init(item: WeightItem) {
    _item = State(initialValue: item)
    _weight = State(initialValue: item.grams > 0 ? WorkoutLabels.weight(item.grams) : "")
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Item Name", text: $item.name).focused($focused)
          LabeledContent("Weight (kg)") {
            TextField("0,9", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(
              .trailing
            ).focused($focused)
              .accessibilityLabel("Item weight in kilograms")
          }
          Toggle("Include in Combinations", isOn: $item.isEnabled)
        } footer: {
          Text("Each item is available once. The backpack is already included.")
        }
      }.disabled(saving)
        .navigationTitle(item.grams == 0 ? "New Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline).interactiveDismissDisabled(saving)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
              .iconOnly
            ).disabled(
              saving)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(saving ? "Saving…" : "Save") { save() }
              .disabled(
                saving || item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || weight.isEmpty)
          }
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") {
              focused = false
            }.tint(.white).labelStyle(.iconOnly)
          }
        }
        .alert(
          "Item Not Saved",
          isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
          Button("OK", role: .cancel) { error = nil }
        } message: {
          Text(error ?? "")
        }
    }
  }
  private func save() {
    guard !saving else { return }
    saving = true
    focused = false
    Task {
      defer { saving = false }
      do {
        item.grams = try WorkoutWeight.grams(weight)
        try await store.saveWeightItem(item)
        dismiss()
      } catch { self.error = error.localizedDescription }
    }
  }
}
