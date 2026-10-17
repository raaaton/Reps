import SportCore
import SwiftUI

struct VaultPhotoDetail: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultPhotoRoute
  @State private var confirmDelete = false
  @State private var confirmExport = false
  @State private var editDate = false
  @State private var comparing: VaultComparisonRoute?
  @State private var zoomCommand: VaultZoomCommand?
  private var entry: VaultPhotoEntry? { vault.photos.first { $0.id == route.id } }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session) {
          if let image = vault.preview {
            GeometryReader { geometry in
              VaultZoomScrollView(
                image: image, imageID: route.id, viewport: geometry.size,
                command: zoomCommand
              )
              .frame(width: geometry.size.width, height: geometry.size.height)
              .accessibilityElement(children: .ignore)
              .accessibilityLabel(
                "Private photo from \(entry.map { WorkoutLabels.day($0.metadata.dayKey) } ?? "selected day")"
              )
            }
          } else {
            ProgressView("Opening photo…")
          }
        } else {
          ContentUnavailableView("Vault Locked", systemImage: "lock.fill")
        }
      }
      .navigationTitle(
        vault.gate.covered
          ? "Private Photo" : entry.map { WorkoutLabels.day($0.metadata.dayKey) } ?? "Private Photo"
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") {
            vault.clearPreview()
            dismiss()
          }.tint(.white)
        }
        if vault.allows(route.session), !vault.gate.covered {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Fit to Screen") { zoomCommand = VaultZoomCommand(scale: 1) }
              Button("Zoom ×2") { zoomCommand = VaultZoomCommand(scale: 2) }
              Button("Zoom ×4") { zoomCommand = VaultZoomCommand(scale: 4) }
            } label: {
              Label("Zoom", systemImage: "plus.magnifyingglass")
            }.tint(.white)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Compare", systemImage: "rectangle.split.2x1") {
              comparing = VaultComparisonRoute(
                session: route.session, pose: entry?.metadata.pose, photoID: route.id)
            }.tint(.white).disabled(vault.busy || entry?.metadata.pose == nil)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Edit", systemImage: "pencil") { editDate = true }
              Button("Export to Photos", systemImage: "square.and.arrow.up") {
                confirmExport = true
              }
              SportDestructiveButton("Delete", systemImage: "trash") { confirmDelete = true }
            } label: {
              Label("Options", systemImage: "ellipsis")
            }.tint(.white).disabled(vault.busy)
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if let notice = vault.notice, !vault.gate.covered {
          Text(notice).font(.footnote).padding().frame(maxWidth: .infinity).background(.bar)
        }
      }
      .sportConfirmation("Delete This Private Photo?", isPresented: $confirmDelete) {
        Button("Delete", role: .destructive) {
          Task {
            await vault.delete(id: route.id, session: route.session)
            if vault.allows(route.session), entry == nil { dismiss() }
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "The encrypted Sport copy will be permanently deleted. The original in Photos will be kept."
        )
      }
      .sportConfirmation("Export to Photos?", isPresented: $confirmExport) {
        Button("Export") { Task { await vault.export(id: route.id, session: route.session) } }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "A copy without vault protection will be created in Photos and may sync according to your Photos settings."
        )
      }
      .alert(
        "Unable to Complete Operation",
        isPresented: Binding(
          get: { vault.error != nil && !editDate && comparing == nil },
          set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
      .sheet(isPresented: $editDate) {
        if let entry {
          VaultMetadataEditor(route: route, initial: entry.metadata)
        }
      }
      .sheet(item: $comparing, onDismiss: { vault.clearComparison() }) {
        VaultComparisonView(route: $0)
      }
      .task { await vault.loadPreview(id: route.id, session: route.session) }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          editDate = false
          comparing = nil
          confirmExport = false
          confirmDelete = false
          dismiss()
        }
      }
    }
  }
}

private struct VaultMetadataEditor: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let route: VaultPhotoRoute
  @State private var date: Date
  @State private var pose: VaultPhotoPose?
  init(route: VaultPhotoRoute, initial: VaultPhotoMetadata) {
    self.route = route
    _date = State(initialValue: VaultDates.date(initial.dayKey) ?? Date())
    _pose = State(initialValue: initial.pose)
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        Form {
          DatePicker(
            "Progress Date", selection: $date, in: ...Date(), displayedComponents: .date)
          Picker("Pose", selection: $pose) {
            Text("Not Assigned").tag(Optional<VaultPhotoPose>.none)
            ForEach(VaultPhotoPose.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
          }
        }.disabled(vault.busy)
      }
      .navigationTitle("Edit Photo").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).labelStyle(
            .iconOnly
          ).disabled(
            vault.busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          SportConfirmationButton(title: "Save") {
            Task {
              if await vault.changeMetadata(
                id: route.id, day: date, pose: pose, session: route.session)
              {
                dismiss()
              }
            }
          }
          .labelStyle(.iconOnly).disabled(vault.busy || !vault.allows(route.session))
        }
      }
      .alert(
        "Changes Not Saved",
        isPresented: Binding(get: { vault.error != nil }, set: { if !$0 { vault.error = nil } })
      ) {
        Button("OK", role: .cancel) { vault.error = nil }
      } message: {
        Text(vault.error ?? "")
      }
      .onChange(of: vault.gate.phase) { _, phase in if phase != .unlocked { dismiss() } }
    }.interactiveDismissDisabled(vault.busy)
  }
}
