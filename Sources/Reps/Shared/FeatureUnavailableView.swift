import SwiftUI

/// An honest unavailable state for features outside the current milestone.
struct FeatureUnavailableView: View {
  let title: LocalizedStringKey
  let systemImage: String
  let message: LocalizedStringKey

  var body: some View {
    ScrollView {
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        Text(message)
      }
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
  }
}
