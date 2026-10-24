import RepsCore
import SwiftUI

struct VaultComparisonZoomRoute: Identifiable {
  let id = UUID()
  let session: UUID
  let firstID: String
  let secondID: String
  let initialID: String
}

struct VaultComparisonZoomView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultComparisonZoomRoute
  @State private var selectedID: String
  @State private var command: VaultZoomCommand?
  init(route: VaultComparisonZoomRoute) {
    self.route = route
    _selectedID = State(initialValue: route.initialID)
  }
  private var entry: VaultPhotoEntry? { vault.photos.first { $0.id == selectedID } }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session), let image = vault.comparisonImages[selectedID] {
          VStack(spacing: 12) {
            GeometryReader { geometry in
              VaultZoomScrollView(
                image: image, imageID: selectedID, viewport: geometry.size, command: command,
                onAlternate: { alternate() }
              ).frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                  "\(entry?.metadata.pose?.label ?? "Private Photo"), \(entry.map { WorkoutLabels.day($0.metadata.dayKey) } ?? "")"
                )
                .accessibilityHint("Show the other photo with the comparison button")
                .accessibilityAction(named: "Show other photo") { alternate() }
            }
            if let entry {
              Text(
                "\(entry.metadata.pose?.label ?? "") · \(WorkoutLabels.day(entry.metadata.dayKey))"
              )
              .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Tap to switch photos. Pinch to zoom.")
              .font(.footnote).foregroundStyle(.secondary).padding(.bottom)
          }
        } else {
          ContentUnavailableView("Photos Unavailable", systemImage: "lock.fill")
        }
      }
      .navigationTitle("Compare").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }.tint(.white)
        }
        if vault.allows(route.session), !vault.gate.covered {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Show other photo", systemImage: "arrow.left.arrow.right") { alternate() }
              .tint(.white)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Fit to Screen") { setZoom(1) }
              Button("Zoom ×2") { setZoom(2) }
              Button("Zoom ×4") { setZoom(4) }
            } label: {
              Label("Zoom", systemImage: "plus.magnifyingglass")
            }.tint(.white)
          }
        }
      }
      .onChange(of: vault.gate.phase) { _, phase in if phase != .unlocked { dismiss() } }
    }
  }
  private func alternate() {
    guard vault.allows(route.session) else { return }
    selectedID = selectedID == route.firstID ? route.secondID : route.firstID
  }
  private func setZoom(_ value: Double) {
    command = VaultZoomCommand(scale: CGFloat(value))
  }
}
