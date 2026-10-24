import SportCore
import SwiftUI

struct StreakSummaryRow: View {
  let days: Int
  @AppStorage(StreakDisplayUnit.preferenceKey) private var unit = StreakDisplayUnit.days

  var body: some View {
    LabeledContent("Streak") {
      Menu {
        Picker("Streak Units", selection: $unit) {
          Text("Days").tag(StreakDisplayUnit.days)
          Text("Largest Unit").tag(StreakDisplayUnit.largestUnit)
        }
      } label: {
        Text(unit.label(days: days)).foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Streak Units")
      .accessibilityValue(unit.label(days: days))
      .accessibilityHint("Choose days or the largest complete unit")
    }
  }
}
