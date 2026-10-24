import RepsCore
import SportLiveSupport
import SwiftUI
import UIKit

struct VaultMenuButton: View {
  @Environment(\.repsAccent) private var accent
  let title: String
  let systemImage: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Label {
        Text(title).foregroundStyle(.primary)
      } icon: {
        Image(
          uiImage: (UIImage(systemName: systemImage) ?? UIImage()).withTintColor(
            UIColor(RepsAccentColors(accent).tint), renderingMode: .alwaysOriginal)
        )
        .renderingMode(.original)
      }.labelStyle(.titleAndIcon)
    }
  }
}
