import Charts
import RepsCore
import SportLiveSupport
import SwiftUI

struct BodyWeightChart: View {
  @Environment(\.repsAccent) private var accentChoice
  let points: [BodyWeightPoint]
  let period: ChartPeriod
  let ending: Date
  @Binding var selectedID: String?
  @ScaledMetric(relativeTo: .body) private var height = 220.0
  private var selected: BodyWeightPoint? { points.first { $0.id == selectedID } }
  private var bounds: ClosedRange<Double> {
    let low = points.map(\.kilograms).min() ?? 0
    let high = points.map(\.kilograms).max() ?? 1
    let padding = max((high - low) * 0.15, 0.5)
    return max(0, low - padding)...(high + padding)
  }
  var body: some View {
    Chart {
      if let selected {
        RuleMark(x: .value("Selected Date", selected.date))
          .foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .zIndex(-1).accessibilityHidden(true)
      }
      ForEach(points) { point in
        if points.count > 1 {
          LineMark(x: .value("Date", point.date), y: .value("Weight in kilograms", point.kilograms))
            .interpolationMethod(.linear).lineStyle(StrokeStyle(lineWidth: 2.5))
            .foregroundStyle(RepsAccentColors(accentChoice).tint).accessibilityHidden(true)
        }
        PointMark(x: .value("Date", point.date), y: .value("Weight in kilograms", point.kilograms))
          .symbolSize(selectedID == point.id ? 55 : 25)
          .foregroundStyle(RepsAccentColors(accentChoice).tint)
          .accessibilityLabel(point.date.formatted(.dateTime.day().month(.wide).year()))
          .accessibilityValue(BodyWeightPresentation.value(point.measurement.grams))
      }
    }
    .chartXSelection(
      value: Binding<Date?>(
        get: { selected?.date },
        set: { date in
          selectedID = date.flatMap { date in
            points.min {
              abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }?.id
          }
        })
    )
    .chartXScale(domain: period.startDate(ending: ending)...ending)
    .chartXScale(range: .plotDimension(padding: 12))
    .chartYScale(domain: bounds)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 3)) { axis in
        AxisValueLabel {
          if let date = axis.as(Date.self) {
            Text(date, format: .dateTime.day().month(.abbreviated)).accessibilityHidden(true)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { axis in
        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
        AxisValueLabel {
          if let value = axis.as(Double.self) {
            Text(value, format: .number.precision(.fractionLength(0...2))).accessibilityHidden(true)
          }
        }
      }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if let selected, let frame = proxy.plotFrame,
          let x = proxy.position(forX: selected.date),
          let y = proxy.position(forY: selected.kilograms)
        {
          let plot = geometry[frame]
          BodyWeightCallout(anchor: CGPoint(x: plot.minX + x, y: plot.minY + y)) {
            VStack(alignment: .leading, spacing: 3) {
              Text(selected.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption).foregroundStyle(.secondary)
              Text(BodyWeightPresentation.value(selected.measurement.grams))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .padding(10).background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
          }.frame(width: geometry.size.width, height: geometry.size.height)
        }
      }.allowsHitTesting(false).accessibilityHidden(true)
    }
    .chartLegend(.hidden).frame(height: height)
    .accessibilityLabel(
      "Body weight over time. Dates on the horizontal axis; kilograms on the vertical axis."
    )
    .transaction { $0.animation = nil }
  }
}

private struct BodyWeightCallout: Layout {
  let anchor: CGPoint
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard let callout = subviews.first else { return }
    let size = callout.sizeThatFits(ProposedViewSize(width: min(260, bounds.width), height: nil))
    let x = max(bounds.minX, min(anchor.x - size.width / 2, bounds.maxX - size.width))
    let y = max(bounds.minY, min(anchor.y - size.height - 8, bounds.maxY - size.height))
    callout.place(
      at: CGPoint(x: x, y: y), anchor: .topLeading,
      proposal: ProposedViewSize(width: size.width, height: size.height))
  }
}
