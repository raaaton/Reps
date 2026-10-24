import RepsCore
import SwiftUI

struct ChartPeriodPicker: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Binding var selection: ChartPeriod

  var body: some View {
    if typeSize >= .xxxLarge {
      menu
    } else {
      ViewThatFits(in: .horizontal) {
        Picker("Period", selection: $selection) {
          choices
        }.pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
        menu
      }.frame(maxWidth: .infinity)
    }
  }
  private var menu: some View {
    Picker("Period", selection: $selection) { choices }.pickerStyle(.menu)
  }
  private var choices: some View {
    ForEach(ChartPeriod.allCases) { period in Text(period.label).tag(period) }
  }
}
