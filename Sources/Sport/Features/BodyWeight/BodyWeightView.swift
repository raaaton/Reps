import SportCore
import SwiftUI

struct BodyWeightView: View {
  @EnvironmentObject private var store: TrainingStore
  @State private var period: ChartPeriod = .threeMonths
  @State private var selectedID: String?
  @State private var draft: BodyWeightDraft?
  @State private var deleting: BodyWeightMeasurement?
  @State private var busy = false
  @State private var error: String?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let points = BodyWeightTrend.points(
        measurements: store.bodyWeights, period: period, ending: context.date)
      List {
        Section { ChartPeriodPicker(selection: $period) }.listRowBackground(Color.clear)
        if let last = points.last {
          Section {
            VStack(alignment: .leading, spacing: 6) {
              Text("Latest Weight").font(.headline)
              Text(BodyWeightPresentation.value(last.measurement.grams))
                .font(.largeTitle.weight(.semibold)).monospacedDigit()
              Text(last.date, format: .dateTime.day().month(.wide).year())
                .font(.subheadline).foregroundStyle(.secondary)
              if let delta = BodyWeightTrend.deltaGrams(points: points) {
                Text("\(BodyWeightPresentation.change(delta)) since the first measurement shown")
                  .font(.subheadline).foregroundStyle(.secondary)
              }
              Text(period.caption).font(.caption).foregroundStyle(.secondary)
            }
            BodyWeightChart(
              points: points, period: period, ending: context.date, selectedID: $selectedID)
            Text(
              "\(points.count) \(points.count == 1 ? "measurement" : "measurements") in this period · kg"
            )
            .font(.caption).foregroundStyle(.secondary)
            if points.count == 1 {
              Text("Add another measurement to see change over time.")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        } else {
          Section {
            ContentUnavailableView {
              Label("No Weight Measurements", systemImage: "chart.xyaxis.line")
            } description: {
              Text(
                store.bodyWeights.isEmpty
                  ? "Add a measurement to start tracking your body weight."
                  : "Choose another period or add a measurement.")
            } actions: {
              Button("Add Body Weight") { draft = BodyWeightDraft(measurement: nil) }
            }
          }.listRowBackground(Color.clear)
        }
        if !store.bodyWeights.isEmpty {
          Section("All Measurements") {
            ForEach(store.bodyWeights.reversed()) { measurement in
              Button {
                draft = BodyWeightDraft(measurement: measurement)
              } label: {
                LabeledContent(WorkoutLabels.day(measurement.dayKey)) {
                  Text(BodyWeightPresentation.value(measurement.grams)).monospacedDigit()
                }.foregroundStyle(.primary).contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityHint("Edit this measurement")
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                  deleting = measurement
                }
              }
              .contextMenu {
                Button("Edit", systemImage: "pencil") {
                  draft = BodyWeightDraft(measurement: measurement)
                }
                SportDestructiveButton("Delete", systemImage: "trash") { deleting = measurement }
              }
              .accessibilityAction(named: "Delete") { deleting = measurement }
            }
          }
        }
      }.disabled(busy)
    }
    .navigationTitle("Body Weight").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Add Body Weight", systemImage: "plus") { draft = BodyWeightDraft(measurement: nil) }
          .tint(.white).disabled(busy)
      }
    }
    .sheet(item: $draft, onDismiss: openRequestedEntry) {
      BodyWeightEditor(measurement: $0.measurement)
    }
    .onChange(of: period) { _, _ in selectedID = nil }
    .onChange(of: store.bodyWeightEntryRequest) { _, _ in openRequestedEntry() }
    .onChange(of: store.isReady) { _, _ in openRequestedEntry() }
    .task { openRequestedEntry() }
    .sportConfirmation(
      "Delete This Measurement?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      presenting: deleting
    ) { measurement in
      Button("Delete", role: .destructive) { remove(measurement) }
      Button("Cancel", role: .cancel) { deleting = nil }
    } message: { measurement in
      Text(
        "The body weight measurement for \(WorkoutLabels.day(measurement.dayKey)) will be permanently deleted."
      )
    }
    .alert(
      "Unable to Delete",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
  private func openRequestedEntry() {
    guard store.isReady, store.bodyWeightEntryRequest != nil, draft == nil else { return }
    draft = BodyWeightDraft(measurement: nil)
    store.consumeBodyWeightEntryRequest()
  }
  private func remove(_ measurement: BodyWeightMeasurement) {
    deleting = nil
    busy = true
    Task {
      defer { busy = false }
      do { try await store.deleteBodyWeight(measurement) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
