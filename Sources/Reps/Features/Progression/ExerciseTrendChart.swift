import Charts
import RepsCore
import SportLiveSupport
import SwiftUI

struct ExerciseTrendChart: View {
  @Environment(\.repsAccent) private var accentChoice
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @Environment(\.scenePhase) private var scenePhase
  @State private var revealed = false
  let points: [SessionTrendPoint]
  let metric: SessionTrendMetric
  @Binding var selectedIndex: Int?
  @ScaledMetric(relativeTo: .body) private var height = 220.0
  private var ticks: [Int] {
    guard points.count > 1 else { return [0] }
    return Array(Set([0, (points.count - 1) / 3, (points.count - 1) * 2 / 3, points.count - 1]))
      .sorted()
  }
  var body: some View {
    Chart {
      if let selectedIndex, points.indices.contains(selectedIndex) {
        RuleMark(x: .value("Selected Workout", selectedIndex))
          .foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .zIndex(-1).accessibilityHidden(true)
      }
      ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
        LineMark(
          x: .value("Workout", index),
          y: .value(TrendPresentation.title(metric), point.value(for: metric))
        )
        .interpolationMethod(.linear).lineStyle(StrokeStyle(lineWidth: 2.5))
        .foregroundStyle(RepsAccentColors(accentChoice).tint).accessibilityHidden(true)
        PointMark(
          x: .value("Workout", index),
          y: .value(TrendPresentation.title(metric), point.value(for: metric))
        )
        .symbolSize(selectedIndex == index ? 55 : 20).foregroundStyle(
          RepsAccentColors(accentChoice).tint
        )
        .zIndex(selectedIndex == index ? 2 : 1)
        .accessibilityLabel("Workout \(index + 1), \(WorkoutLabels.day(point.performance.dayKey))")
        .accessibilityValue(
          "\(TrendPresentation.chartValue(point.value(for: metric), metric: metric)), \(TrendPresentation.setCount(point.context.seriesCount)); workout total \(TrendPresentation.value(point.total, metric: metric))"
        )
      }
    }
    .chartXSelection(
      value: Binding(
        get: { selectedIndex },
        set: { index in
          if let index, points.indices.contains(index), index != selectedIndex {
            RepsHaptics.shared.play(.selection)
          }
          selectedIndex = index
        })
    )
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if let selectedIndex, points.indices.contains(selectedIndex),
          let frame = proxy.plotFrame,
          let x = proxy.position(forX: selectedIndex),
          let y = proxy.position(forY: points[selectedIndex].value(for: metric))
        {
          let point = points[selectedIndex]
          let plot = geometry[frame]
          ChartCalloutLayout(anchor: CGPoint(x: plot.minX + x, y: plot.minY + y)) {
            VStack(alignment: .leading, spacing: 3) {
              Text(point.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption).foregroundStyle(.secondary)
              Text(
                "\(TrendPresentation.value(point.total, metric: metric)) • \(TrendPresentation.setCount(point.context.seriesCount))"
              )
              .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
        }
      }
      .allowsHitTesting(false).accessibilityHidden(true)
    }
    .chartXScale(domain: -0.5...max(0.5, Double(points.count) - 0.5))
    .chartYScale(domain: 0...max(1, (points.map { $0.value(for: metric) }.max() ?? 0) * 1.1))
    .chartXAxis {
      AxisMarks(values: ticks) { axis in
        if let index = axis.as(Int.self), points.indices.contains(index) {
          AxisValueLabel {
            Text(points[index].date, format: .dateTime.day().month(.abbreviated))
              .accessibilityHidden(true)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { axis in
        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
        AxisValueLabel {
          if let value = axis.as(Double.self) {
            Text(value, format: .number.precision(.fractionLength(0...1))).accessibilityHidden(true)
          }
        }
      }
    }
    .chartLegend(.hidden).frame(height: height)
    .accessibilityLabel(
      "Chart of \(TrendPresentation.title(metric).lowercased()). One value per workout, from oldest to newest."
    )
    // A new filter gets a new chart: update marks/axes immediately, fade only its presentation.
    .transaction { $0.animation = nil }
    .opacity(revealed ? 1 : 0)
    .animation(
      reduceMotion || voiceOver || scenePhase != .active ? nil : .easeOut(duration: 0.15),
      value: revealed
    )
    .onAppear { revealed = true }
    .onDisappear { revealed = false }
  }
}

// The callout is a SwiftUI overlay above the entire chart, never a child of
// a point mark. Measure/place it in one layout pass so fitting at the edges
// cannot bring a mark in front or cause a second-frame positioning flash.
private struct ChartCalloutLayout: Layout {
  let anchor: CGPoint
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard let card = subviews.first else { return }
    let size = card.sizeThatFits(ProposedViewSize(width: min(260, bounds.width), height: nil))
    let x = max(bounds.minX, min(anchor.x - size.width / 2, bounds.maxX - size.width))
    let y = max(bounds.minY, min(anchor.y - size.height - 8, bounds.maxY - size.height))
    card.place(
      at: CGPoint(x: x, y: y), anchor: .topLeading,
      proposal: ProposedViewSize(width: size.width, height: size.height))
  }
}
