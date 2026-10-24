import RepsCore
import SportLiveSupport
import SwiftUI
import UIKit

// Skills-only semantic controls. Explicit leaf ink prevents List/Menu/toolbar tint overrides.
struct SkillPrimaryButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Label {
        Text(title).foregroundStyle(.black)
      } icon: {
        Image(systemName: systemImage).foregroundStyle(.black)
      }.frame(maxWidth: .infinity).padding(.vertical, 6)
    }
    .buttonStyle(.borderedProminent).tint(Color.accentColor)
    .labelStyle(.titleAndIcon)
  }
}
struct SkillToolbarButton: View {
  var title = "Save"
  var cancel = false
  let action: () -> Void
  var body: some View {
    if cancel {
      button.buttonStyle(.automatic).tint(.white)
    } else {
      button.buttonStyle(.glassProminent).buttonBorderShape(.circle).tint(Color.accentColor)
    }
  }
  private var button: some View {
    Button(action: action) {
      Image(systemName: cancel ? "xmark" : "checkmark")
        .foregroundStyle(cancel ? .white : .black).accessibilityLabel(title)
    }
  }
}

struct SkillBackButton: View {
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.left").foregroundStyle(.white).accessibilityLabel("Back")
    }.buttonStyle(.automatic).tint(.white)
  }
}

struct SkillDestructiveButton: View {
  let title: String
  var systemImage = "trash"
  var filled = false
  let action: () -> Void
  var body: some View {
    Button(role: .destructive, action: action) {
      SkillDestructiveLabel(title: title, systemImage: systemImage, filled: filled)
    }.tint(.red)
  }
}

struct SkillDestructiveLabel: View {
  let title: String
  var systemImage = "trash"
  var filled = false
  var body: some View {
    Label {
      Text(title).foregroundStyle(filled ? .white : .red)
    } icon: {
      // UIKit menus can discard a SwiftUI template's foreground style. Keep the semantic ink
      // in the original SF Symbol image too, so destructive menu glyphs remain red.
      Image(
        uiImage: (UIImage(systemName: systemImage) ?? UIImage())
          .withTintColor(filled ? .white : .systemRed, renderingMode: .alwaysOriginal)
      ).renderingMode(.original)
    }
  }
}

struct SkillToolbarMenu<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder var content: () -> Content
  var body: some View {
    Menu(content: content) {
      Image(systemName: systemImage).foregroundStyle(.white).accessibilityLabel(title)
    }.buttonStyle(.automatic).tint(.white)
  }
}

struct SkillDemonstrationLink: View {
  let url: URL
  var body: some View {
    Link(destination: url) { Label("View Demonstration", systemImage: "play.rectangle") }
  }
}

struct SkillSecondaryButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .frame(maxWidth: .infinity, minHeight: 28)
    }.buttonStyle(.bordered).tint(.primary)
  }
}

// UIKit menu items do not reliably retain a SwiftUI LabelStyle's template tint.
// Supply original symbol ink, as the destructive menu labels already do.
struct SkillMenuButton: View {
  @Environment(\.repsAccent) private var choice
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
            UIColor(RepsAccentColors(choice).tint), renderingMode: .alwaysOriginal)
        ).renderingMode(.original)
      }
      .labelStyle(.titleAndIcon)
    }
  }
}
