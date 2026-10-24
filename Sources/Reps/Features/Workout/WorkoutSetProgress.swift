import RepsCore
import SportLiveSupport
import SwiftUI

struct WorkoutSetProgress: View {
  @Environment(\.repsAccent) private var accentChoice
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let exercise: WorkoutExercise

  private var total: Int { exercise.definition.setCount }
  private var completed: Int { exercise.sets.count }

  var body: some View {
    Group {
      // Avoid producing an unbounded number of views for an unusually large objective.
      if total <= 12 {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 10) {
            ForEach(0..<total, id: \.self) { index in
              Image(systemName: index < completed ? "checkmark.circle.fill" : "circle.fill")
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .foregroundStyle(
                  index < completed ? RepsAccentColors(accentChoice).tint : Color.secondary)
            }
          }
          .font(.title3).fixedSize()
          bar
        }
      } else {
        bar
      }
    }
    .repsAnimation(value: completed)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Recorded Sets")
    .accessibilityValue("\(completed) of \(total)")
  }

  private var bar: some View {
    ProgressView(value: Double(completed), total: Double(total))
  }
}
