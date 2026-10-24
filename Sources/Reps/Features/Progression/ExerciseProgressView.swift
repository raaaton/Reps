import Foundation
import RepsCore
import SwiftUI

private struct TrendRequest: Hashable, Sendable {
  let months: Int
  let metric: SessionTrendMetric
  let revision: Int
  let tracking: TrackingMode
  let retry: Int
}
private struct TrendProjection: Sendable {
  let request: TrendRequest
  let points: [SessionTrendPoint]
  let periodTotal: Int?
}
struct ExerciseProgressView: View {
  @EnvironmentObject private var store: TrainingStore
  @Environment(\.dynamicTypeSize) private var typeSize
  let exercise: TrainingExercise
  @State private var period: ChartPeriod = .threeMonths
  @State private var metric: SessionTrendMetric
  @State private var projection: TrendProjection?
  @State private var selectedIndex: Int?
  @State private var retry = 0
  @State private var loading = true
  @State private var error: String?
  init(exercise: TrainingExercise) {
    self.exercise = exercise
    _metric = State(initialValue: exercise.tracking == .duration ? .duration : .volume)
  }
  private var request: TrendRequest {
    TrendRequest(
      months: period.rawValue, metric: metric, revision: store.historyRevision,
      tracking: exercise.tracking, retry: retry)
  }
  private var definition: TrainingExercise? {
    if case .ready(let snapshot) = store.phase {
      return snapshot.exercises.first { $0.id == exercise.id }
    }
    return nil
  }
  private var displayedMetric: SessionTrendMetric { projection?.request.metric ?? metric }
  private var displayedPeriod: ChartPeriod {
    projection.flatMap { ChartPeriod(rawValue: $0.request.months) } ?? period
  }
  private var points: [SessionTrendPoint] { projection?.points ?? [] }
  private var selected: SessionTrendPoint? {
    if let selectedIndex, points.indices.contains(selectedIndex) { return points[selectedIndex] }
    return points.last
  }
  private var summaryTotal: Int? {
    guard let projection else { return nil }
    if displayedMetric == .volume { return projection.points.last?.cumulativeTotal }
    if displayedMetric == .repetitions || displayedMetric == .duration {
      return projection.periodTotal
    }
    return points.last?.total
  }
  var body: some View {
    List {
      Section {
        ChartPeriodPicker(selection: $period)
        if typeSize >= .xxxLarge {
          metricPicker.pickerStyle(.menu)
        } else {
          ViewThatFits(in: .horizontal) {
            metricPicker.pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
            metricPicker.pickerStyle(.menu)
          }.frame(maxWidth: .infinity)
        }
      }.listRowBackground(Color.clear)
      if loading && projection == nil {
        Section { ProgressView("Loading workouts…") }
      } else if let error, projection == nil {
        Section {
          Text(error).foregroundStyle(.secondary)
          Button("Try Again") { retry += 1 }
        }
      } else if let projection {
        if let last = points.last, let summaryTotal {
          Section {
            VStack(alignment: .leading, spacing: 6) {
              Text(TrendPresentation.summaryTitle(displayedMetric)).font(.headline)
              Text(TrendPresentation.value(summaryTotal, metric: displayedMetric)).font(.largeTitle)
                .fontWeight(.semibold)
              Text(
                displayedMetric != .load
                  ? displayedPeriod.caption
                  : "Last Workout · \(WorkoutLabels.day(last.performance.dayKey))"
              ).font(
                .subheadline
              ).foregroundStyle(.secondary)
              if displayedMetric != .volume, let first = points.first, points.count > 1 {
                let delta = last.value(for: displayedMetric) - first.value(for: displayedMetric)
                Text(
                  "\(displayedMetric != .load ? "Last workout: " : "")\(delta > 0 ? "+" : delta < 0 ? "−" : "")\(TrendPresentation.chartValue(abs(delta), metric: displayedMetric)) since the first workout shown"
                ).font(.subheadline).foregroundStyle(.secondary)
              }
              Text("\(points.count) \(points.count == 1 ? "workout" : "workouts") in this period")
                .font(.caption).foregroundStyle(.secondary)
            }
            ExerciseTrendChart(
              points: points, metric: displayedMetric, selectedIndex: $selectedIndex
            )
            .id(projection.request)
            .overlay(alignment: .topTrailing) {
              if loading { ProgressView().accessibilityLabel("Updating chart") }
            }
            Text(
              displayedMetric == .volume
                ? "The curve shows average volume per set, from oldest to newest."
                : "Workouts are evenly spaced from oldest to newest."
            ).font(
              .caption
            ).foregroundStyle(.secondary)
            Text(TrendPresentation.unitDescription(displayedMetric)).font(.caption).foregroundStyle(
              .secondary)
            if displayedMetric == .volume, summaryTotal == 0 {
              Text(
                "Without added weight, this volume is 0 kg. Use Repetitions to follow bodyweight results."
              )
              .font(.caption).foregroundStyle(.secondary)
            }
            if points.count == 1 {
              Text(
                displayedMetric == .volume
                  ? "Only one recorded workout in this period."
                  : "Only one workout: another workout is needed to show change."
              ).font(.caption).foregroundStyle(.secondary)
            }
          }
        } else {
          Section {
            ContentUnavailableView(
              "No Workouts in This Period",
              systemImage: "chart.xyaxis.line",
              description: Text(
                "Choose another period to see this exercise’s completed workouts."
              ))
          }.listRowBackground(Color.clear)
        }
        if let selected {
          Section(selectedIndex == nil ? "Last Workout — Details" : "Selected Workout") {
            LabeledContent("Date", value: WorkoutLabels.day(selected.performance.dayKey))
            LabeledContent("Sets", value: String(selected.context.seriesCount))
            LabeledContent(
              TrendPresentation.workoutTitle(displayedMetric),
              value: TrendPresentation.value(selected.total, metric: displayedMetric))
            ForEach(selected.performance.exercise.sets) { set in
              LabeledContent("Set \(set.number)", value: WorkoutLabels.performance(set))
            }
            if let feeling = selected.performance.exercise.feelingTenths {
              LabeledContent("Feeling", value: "\(WorkoutLabels.feeling(feeling)) / 10")
            }
            NavigationLink("Open Workout") {
              WorkoutHistoryDetail(workoutID: selected.workoutID)
            }
          }
        }
      }
      if let error, projection != nil {
        Section {
          Text(error).foregroundStyle(.secondary)
          Button("Try Again") { retry += 1 }
        }
      }
      if let definition {
        Section("Next Workout") { ExerciseWorkoutGoals(exercise: definition) }
      } else {
        Section {
          Text("Archived exercise. Past results remain available.").foregroundStyle(
            .secondary)
        }
      }
      Section {
        NavigationLink("All Results") { ExerciseHistoryView(exercise: exercise) }
      }
    }
    .navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
    .onChange(of: exercise.tracking) { _, mode in
      metric = mode == .duration ? .duration : .volume
    }
    .task(id: request) { await load() }
  }
  private var metricPicker: some View {
    Picker("Metric", selection: $metric) {
      if exercise.tracking == .repetitions {
        Text("Volume").tag(SessionTrendMetric.volume)
      }
      Text(exercise.tracking == .duration ? "Duration" : "Repetitions").tag(
        exercise.tracking == .duration ? SessionTrendMetric.duration : .repetitions)
      Text("Added Weight").tag(SessionTrendMetric.load)
    }
  }
  private func load() async {
    loading = true
    error = nil
    let request = request
    let metric = request.metric
    let months = request.months
    let tracking = request.tracking
    do {
      let records = try await store.exerciseHistory(exerciseID: exercise.id)
      let value = try await Task.detached(priority: .userInitiated) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let since = (ChartPeriod(rawValue: months) ?? .threeMonths).startDate(
          ending: Date(), calendar: calendar)
        let points: [SessionTrendPoint]
        if metric == .volume {
          points = try SessionTrends.cumulativeVolume(
            records: records, since: since, calendar: calendar)
        } else {
          points = SessionTrends.points(
            records: records, metric: metric, tracking: tracking, weight: nil, since: since,
            calendar: calendar)
        }
        let periodTotal: Int? =
          metric == .repetitions || metric == .duration
          ? try SessionTrends.total(points: points) : nil
        return TrendProjection(
          request: request, points: points,
          periodTotal: periodTotal)
      }.value
      guard !Task.isCancelled, self.request == request else { return }
      // Publish matching labels, filters, points and selection together; never empty the list.
      withTransaction(Transaction(animation: nil)) {
        projection = value
        selectedIndex = nil
        loading = false
      }
    } catch {
      if !Task.isCancelled, self.request == request {
        self.error = error.localizedDescription
        loading = false
      }
    }
  }
}
