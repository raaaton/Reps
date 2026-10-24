import SwiftUI

struct SportDestructiveButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  init(_ title: String, systemImage: String, action: @escaping () -> Void) {
    self.title = title
    self.systemImage = systemImage
    self.action = action
  }
  var body: some View {
    Button(role: .destructive, action: action) {
      Label {
        Text(title).foregroundStyle(.red)
      } icon: {
        Image(systemName: systemImage).foregroundStyle(.red)
      }
    }
    .tint(.red)
    .labelStyle(.titleAndIcon)
  }
}
