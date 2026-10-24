import SportCore
import SwiftUI

private struct VaultMovementRoute: Identifiable {
  let id: String
  let session: UUID
}
private struct VaultMovementEditorRoute: Identifiable {
  let id = UUID()
  let original: VaultMovementEntry?
  let session: UUID
}

struct VaultMovementsView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @State private var selected: VaultMovementRoute?
  @State private var editing: VaultMovementEditorRoute?
  @State private var attemptedSync: [String] = []
  @State private var deleting: VaultMovementEntry?
  var body: some View {
    TrainingContent { snapshot in
      let followedIDs = Set(
        VaultMovementCollection.following(
          snapshot.skills,
          progress: snapshot.skillProgress, movements: vault.movements
        ).compactMap(\.metadata.skillID))
      let followed = vault.movements.filter {
        $0.metadata.skillID.map(followedIDs.contains) == true
      }
      let custom = vault.movements.filter { $0.metadata.skillID == nil }.sorted {
        $0.metadata.name < $1.metadata.name
      }
      let saved = VaultMovementCollection.saved(
        vault.movements, following: followed, videos: vault.videos
      ).filter { $0.metadata.skillID != nil }
      List {
        if !followed.isEmpty {
          Section("Following") { ForEach(followed) { movementRow($0) } }
        }
        if !custom.isEmpty {
          Section("Custom Movements") { ForEach(custom) { movementRow($0) } }
        }
        if !saved.isEmpty {
          Section("Saved Movements") { ForEach(saved) { movementRow($0) } }
        }
        if followed.isEmpty && custom.isEmpty && saved.isEmpty {
          ContentUnavailableView(
            "No Movements", systemImage: "figure.strengthtraining.traditional",
            description: Text(
              "Skills you follow appear here. You can also add a movement just for the vault.")
          )
          .listRowBackground(Color.clear)
          Button("Add Custom Movement", systemImage: "plus") { beginEditing(nil) }
        }
        if vault.busy { ProgressView("Updating vault…") }
      }
      .task(id: syncKey(snapshot)) { await sync(snapshot) }
      .onChange(of: vault.busy) { _, busy in
        if !busy { Task { await sync(snapshot) } }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add Custom Movement", systemImage: "plus") { beginEditing(nil) }
          .tint(.white).disabled(vault.busy)
      }
    }
    .sheet(item: $selected) { route in
      VaultMovementDetailView(movementID: route.id, session: route.session)
    }
    .sheet(item: $editing) { route in
      VaultMovementEditor(original: route.original, session: route.session)
    }
    .sportConfirmation(
      "Delete This Movement?",
      isPresented: Binding(
        get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete", role: .destructive) {
        if let deleting, let session = vault.sessionToken {
          Task { await vault.deleteVideoMovement(deleting, session: session) }
        }
        deleting = nil
      }
      Button("Cancel", role: .cancel) { deleting = nil }
    } message: {
      Text(
        "The movement and all its private videos will be permanently deleted from Sport. Originals in Photos will be kept."
      )
    }
    .onChange(of: vault.gate.phase) { _, phase in
      if phase != .unlocked {
        selected = nil
        editing = nil
        deleting = nil
      }
    }
  }
  private func syncKey(_ snapshot: TrainingSnapshot) -> [String] {
    snapshot.skills.map { skill in
      "\(skill.id)|\(skill.name)|\(skill.isArchived)|\(snapshot.skillProgress.first { $0.skillID == skill.id }?.completed(in: skill) == true)|\(snapshot.skillProgress.contains { $0.skillID == skill.id })"
    } + [vault.sessionToken?.uuidString ?? ""]
  }
  private func sync(_ snapshot: TrainingSnapshot) async {
    let key = syncKey(snapshot)
    guard !vault.busy, let session = vault.sessionToken, attemptedSync != key else { return }
    attemptedSync = key
    await vault.syncVideoMovements(
      skills: snapshot.skills, progress: snapshot.skillProgress, session: session)
  }
  private func beginEditing(_ original: VaultMovementEntry?) {
    guard let session = vault.sessionToken else { return }
    editing = VaultMovementEditorRoute(original: original, session: session)
  }
  private func movementRow(_ entry: VaultMovementEntry) -> some View {
    Button {
      if let session = vault.sessionToken {
        selected = VaultMovementRoute(id: entry.id, session: session)
      }
    } label: {
      HStack {
        Label {
          VStack(alignment: .leading, spacing: 4) {
            Text(entry.metadata.name).foregroundStyle(.primary)
            let count = vault.videos.filter { $0.metadata.movementID == entry.id }.count
            Text("\(count) \(count == 1 ? "video" : "videos")").font(.subheadline).foregroundStyle(
              .secondary)
          }
        } icon: {
          Image(systemName: "video")
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(
          .tertiary)
      }
    }.buttonStyle(.plain)
      .contextMenu {
        if entry.metadata.skillID == nil {
          VaultMenuButton(title: "Rename", systemImage: "pencil") { beginEditing(entry) }
          SportDestructiveButton("Delete Movement", systemImage: "trash") { deleting = entry }
        }
      } preview: {
        Label("Private Movement", systemImage: "lock.fill").padding()
      }
      .disabled(vault.busy)
  }
}

private struct VaultMovementEditor: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  let original: VaultMovementEntry?
  let session: UUID
  @State private var name = ""
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(session) {
          Form {
            Section {
              TextField("Movement Name", text: $name).textInputAutocapitalization(.words)
            } footer: {
              Text("This movement is saved only in the vault.")
            }
          }.disabled(vault.busy)
        }
      }
      .navigationTitle(original == nil ? "New Movement" : "Rename Movement")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", systemImage: "xmark") { dismiss() }.tint(.white).disabled(vault.busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", systemImage: "checkmark") {
            Task {
              if await vault.saveCustomMovement(original: original, name: name, session: session) {
                dismiss()
              }
            }
          }.disabled(
            vault.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || name.count > 100)
        }
      }
      .onAppear { name = original?.metadata.name ?? "" }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked {
          name = ""
          dismiss()
        }
      }
      .vaultVideoErrorAlert()
    }.interactiveDismissDisabled(vault.busy)
  }
}

extension View {
  func vaultVideoErrorAlert() -> some View { modifier(VaultVideoErrorAlert()) }
}
private struct VaultVideoErrorAlert: ViewModifier {
  @EnvironmentObject private var vault: PhotoVaultStore
  func body(content: Content) -> some View {
    content.alert(
      "Unable to Complete Operation",
      isPresented: Binding(
        get: { vault.error != nil && vault.gate.phase == .unlocked },
        set: { if !$0 { vault.error = nil } })
    ) {
      Button("OK", role: .cancel) { vault.error = nil }
    } message: {
      Text(vault.error ?? "")
    }
  }
}
