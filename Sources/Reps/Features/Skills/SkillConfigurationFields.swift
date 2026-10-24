import RepsCore
import SwiftUI

struct SkillConfigurationFields: View {
  @Binding var value: SkillConfiguration
  var body: some View {
    Picker("Format", selection: $value.format) {
      ForEach(SkillFormat.allCases, id: \.self) { Text($0.name).tag($0) }
    }
    if value.format == .freePractice {
      Toggle(
        "Practice Reference",
        isOn: Binding(
          get: { value.referenceSeconds != nil }, set: { value.referenceSeconds = $0 ? 300 : nil }))
      if value.referenceSeconds != nil {
        Stepper(
          "Reference: \((value.referenceSeconds ?? 300) / 60) min",
          value: Binding(
            get: { value.referenceSeconds ?? 300 }, set: { value.referenceSeconds = $0 }),
          in: 60...3600, step: 60)
      }
      Text("The reference does not end the practice. Finish when ready.").font(.footnote)
        .foregroundStyle(.secondary)
    } else {
      Stepper("Attempts: \(value.attemptCount)", value: $value.attemptCount, in: 1...1000)
      Stepper("Rest: \(value.restSeconds) sec", value: $value.restSeconds, in: 0...3600, step: 15)
      if value.format == .timedHolds {
        Toggle(
          "Hold Target",
          isOn: Binding(
            get: { value.targetSeconds != nil }, set: { value.targetSeconds = $0 ? 5 : nil }))
        if value.targetSeconds != nil {
          Stepper(
            "Target: \(value.targetSeconds ?? 5) sec",
            value: Binding(get: { value.targetSeconds ?? 5 }, set: { value.targetSeconds = $0 }),
            in: 1...3600, step: 5)
        }
      } else {
        Toggle(
          "Repetition Target",
          isOn: Binding(
            get: { value.targetRepetitions != nil }, set: { value.targetRepetitions = $0 ? 1 : nil }
          ))
        if value.targetRepetitions != nil {
          Stepper(
            "Target: \(value.targetRepetitions ?? 1) reps",
            value: Binding(
              get: { value.targetRepetitions ?? 1 }, set: { value.targetRepetitions = $0 }),
            in: 1...10000)
        }
      }
    }
    TextField("Assistance / Equipment Notes", text: $value.assistance, axis: .vertical)
  }
}
