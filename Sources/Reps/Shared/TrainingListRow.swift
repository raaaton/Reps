import SwiftUI

struct TrainingListRow: View {
  let title: String
  let subtitle: String
  var status: String? = nil

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).foregroundStyle(.primary)
        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
      }
      Spacer()
      if let status { Text(status).font(.subheadline).foregroundStyle(.secondary) }
      Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
  }
}
