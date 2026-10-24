import RepsCore
import SwiftUI

struct WorkoutExerciseRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let exercise: TrainingExercise
  @Binding var setCount: Int
  @State private var customizing = false
  @State private var customInput = ""

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        stackedContent
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: 16) {
            description.fixedSize(horizontal: true, vertical: true)
            Spacer(minLength: 0)
            setMenu
          }
          stackedContent
        }
      }
    }
    .repsConfirmation("Number of Sets", isPresented: $customizing) {
      TextField("Sets", text: $customInput)
        .keyboardType(.numberPad)
        .accessibilityLabel("Number of sets")
      Button("Cancel", role: .cancel) {}
      Button("Apply") {
        if let customCount { setCount = customCount }
      }.disabled(customCount == nil)
    } message: {
      Text("\(exercise.name)\nEnter a number from 1 to 1000.")
    }
  }

  private var stackedContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      description
      setMenu
    }
  }

  private var description: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(exercise.name).foregroundStyle(.primary)
      Text(
        exercise.isEnabled
          ? TrainingLabels.metric(exercise, includePerSet: false) : "Exercise disabled"
      )
      .font(.subheadline).foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var setMenu: some View {
    Menu {
      Picker("Sets", selection: $setCount) {
        ForEach(1...8, id: \.self) { count in
          Text(count == 1 ? "1 set" : "\(count) sets").tag(count)
        }
        if !(1...8).contains(setCount) {
          Text("\(setCount) sets").tag(setCount)
        }
      }.pickerStyle(.inline)
      Button("Custom…") {
        customInput = String(setCount)
        customizing = true
      }
    } label: {
      HStack(spacing: 4) {
        Text(setCount == 1 ? "1 set" : "\(setCount) sets")
          .monospacedDigit()
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption.weight(.semibold))
      }
      .fixedSize()
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .foregroundStyle(.tint)
    .accessibilityLabel("Sets for \(exercise.name)")
    .accessibilityValue(String(setCount))
    .accessibilityHint("Choose the number of sets")
  }

  private var customCount: Int? {
    guard let value = Int(customInput.trimmingCharacters(in: .whitespacesAndNewlines)),
      (1...1000).contains(value)
    else { return nil }
    return value
  }
}
