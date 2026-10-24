import SwiftUI

struct AboutView: View {
  var body: some View {
    List {
      Section {
        Text("Reps")
          .font(.title2.bold())
        Text("A personal space for your workouts.")
          .foregroundStyle(.secondary)
      }

      Section("Version") {
        LabeledContent("Version", value: version)
        LabeledContent("Build", value: build)
      }

      Section {
        Text(
          "Track workouts, review progress and keep private photos in a Face ID protected vault. Reps works offline, without an account or server. Training exports exclude private photos."
        )
      }
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
    .scrollBounceBehavior(.basedOnSize)
  }

  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }

  private var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }
}
