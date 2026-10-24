import RepsCore
import SwiftUI

struct VaultComparisonRoute: Identifiable {
  let id = UUID()
  let session: UUID
  var pose: VaultPhotoPose?
  var photoID: String?
}

private struct VaultComparisonPair: Hashable {
  let firstID: String
  let secondID: String
}

struct VaultComparisonView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultComparisonRoute
  @State private var pose: VaultPhotoPose
  @State private var firstID = ""
  @State private var secondID = ""
  @State private var initialized = false
  @State private var zoomed: VaultComparisonZoomRoute?
  init(route: VaultComparisonRoute) {
    self.route = route
    _pose = State(initialValue: route.pose ?? .frontRelaxed)
  }
  private var photos: [VaultPhotoEntry] {
    VaultPhotoCollection.candidates(vault.photos, pose: pose)
  }
  private var first: VaultPhotoEntry? { photos.first { $0.id == firstID } }
  private var second: VaultPhotoEntry? { photos.first { $0.id == secondID } }
  private var pair: VaultComparisonPair? {
    guard let first, let second, VaultPhotoCollection.canCompare(first, second) else { return nil }
    return VaultComparisonPair(firstID: first.id, secondID: second.id)
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session) {
          GeometryReader { geometry in
            ScrollView {
              VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                  LabeledContent("Pose") {
                    Picker("Pose", selection: $pose) {
                      ForEach(VaultPhotoPose.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.labelsHidden()
                  }
                  if let first, let second, pair != nil {
                    LabeledContent("First Photo") {
                      Picker("First Photo", selection: $firstID) {
                        ForEach(photos.filter { $0.metadata.dayKey != second.metadata.dayKey }) {
                          Text(choiceLabel($0)).tag($0.id)
                        }
                      }.labelsHidden()
                    }
                    LabeledContent("Second Photo") {
                      Picker("Second Photo", selection: $secondID) {
                        ForEach(photos.filter { $0.metadata.dayKey != first.metadata.dayKey }) {
                          Text(choiceLabel($0)).tag($0.id)
                        }
                      }.labelsHidden()
                    }
                  }
                }.pickerStyle(.menu)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                if let first, let second, pair != nil {
                  HStack(alignment: .top, spacing: 12) {
                    comparisonPhoto(first)
                    comparisonPhoto(second)
                  }.frame(height: max(280, geometry.size.height * 0.65))
                } else {
                  ContentUnavailableView(
                    "Two Dates Needed", systemImage: "rectangle.split.2x1",
                    description: Text(
                      "Add or assign a photo of this pose on two different dates. Assign older photos through Edit."
                    ))
                }
              }.padding()
            }
          }
        } else {
          ContentUnavailableView("Vault Locked", systemImage: "lock.fill")
        }
      }
      .navigationTitle("Compare").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            vault.clearComparison()
            dismiss()
          }.tint(.white)
        }
      }
      .onAppear {
        guard !initialized else { return }
        initialized = true
        if route.pose == nil {
          pose =
            VaultPhotoPose.allCases.first { candidate in
              Set(
                VaultPhotoCollection.candidates(vault.photos, pose: candidate).map {
                  $0.metadata.dayKey
                }
              ).count > 1
            } ?? vault.photos.compactMap { $0.metadata.pose }.first ?? .frontRelaxed
        }
        firstID = route.photoID ?? ""
        reconcile()
      }
      .onChange(of: pose) { _, _ in reconcile() }
      .onChange(of: vault.photos) { _, _ in reconcile() }
      .task(id: pair) {
        guard let pair, vault.allows(route.session) else {
          vault.clearComparison()
          return
        }
        if vault.comparisonImages[pair.firstID] != nil,
          vault.comparisonImages[pair.secondID] != nil
        {
          return
        }
        await vault.loadComparison(
          firstID: pair.firstID, secondID: pair.secondID, session: route.session)
      }
      .fullScreenCover(item: $zoomed) { VaultComparisonZoomView(route: $0) }
      .onDisappear { if zoomed == nil { vault.clearComparison() } }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          zoomed = nil
          dismiss()
        }
      }
      .alert(
        "Comparison Unavailable",
        isPresented: Binding(get: { vault.error != nil }, set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
    }
  }
  private func comparisonPhoto(_ photo: VaultPhotoEntry) -> some View {
    VStack(spacing: 8) {
      Text(WorkoutLabels.day(photo.metadata.dayKey)).font(.caption).foregroundStyle(.secondary)
      Button {
        if let pair {
          zoomed = VaultComparisonZoomRoute(
            session: route.session, firstID: pair.firstID, secondID: pair.secondID,
            initialID: photo.id)
        }
      } label: {
        GeometryReader { geometry in
          if let image = vault.comparisonImages[photo.id] {
            Image(uiImage: image).resizable().scaledToFit()
              .frame(width: geometry.size.width, height: geometry.size.height)
          } else {
            ProgressView().frame(width: geometry.size.width, height: geometry.size.height)
          }
        }
      }.buttonStyle(.plain)
        .disabled(vault.comparisonImages[firstID] == nil || vault.comparisonImages[secondID] == nil)
        .accessibilityLabel("\(pose.label), \(WorkoutLabels.day(photo.metadata.dayKey))")
        .accessibilityHint("Enlarge and compare both photos")
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  private func reconcile() {
    if !photos.contains(where: { $0.id == firstID }) { firstID = photos.first?.id ?? "" }
    if let first,
      !photos.contains(where: { $0.id == secondID && VaultPhotoCollection.canCompare(first, $0) })
    {
      secondID = photos.last { VaultPhotoCollection.canCompare(first, $0) }?.id ?? ""
    }
  }
  private func choiceLabel(_ photo: VaultPhotoEntry) -> String {
    let sameDay = photos.filter { $0.metadata.dayKey == photo.metadata.dayKey }
    let day = WorkoutLabels.day(photo.metadata.dayKey)
    guard sameDay.count > 1, let index = sameDay.firstIndex(where: { $0.id == photo.id }) else {
      return day
    }
    return "\(day) · photo \(index + 1)"
  }
}
