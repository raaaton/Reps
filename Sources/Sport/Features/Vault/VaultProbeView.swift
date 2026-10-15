import SportCore
import SwiftUI
import UIKit

struct VaultProbeView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var store = VaultProbeStore()
  @State private var confirmReset = false

  var body: some View {
    ZStack {
      if store.gate.covered {
        ContentUnavailableView("Private Photos", systemImage: "lock.fill")
      } else {
        List {
          Section {
            Text("Vault Validation").font(.headline)
            Text(
              "This screen uses only test data. Photo import is available in Private Photos after Face ID and encryption have been verified on this iPhone."
            )
            .foregroundStyle(.secondary)
          }
          if store.gate.phase == .unlocked, let result = store.result {
            Section {
              Label("Test Data Unlocked", systemImage: "lock.open")
              LabeledContent("Key on This iPhone", value: result.reusedKey ? "Found" : "Created")
              LabeledContent("Encryption and Reading", value: "Verified")
              LabeledContent("Modified Data", value: "Rejected")
              Button("Lock", systemImage: "lock.fill") { store.lock() }
            }
          } else {
            Section {
              Button {
                store.unlock()
              } label: {
                Label(
                  store.gate.phase == .authenticating
                    ? "Unlocking…" : "Unlock with Face ID",
                  systemImage: "faceid"
                )
                .frame(maxWidth: .infinity)
              }
              .sportProminentButton().controlSize(.large)
              .listRowBackground(Color.clear)
              .disabled(store.gate.phase == .authenticating)
            }
          }
          if let error = store.error {
            Section { Text(error).foregroundStyle(.secondary) }
          }
          Section {
            Text(
              "The vault locks when you leave this screen or put Sport in the background. Its preview is hidden whenever the app becomes inactive."
            )
            .foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle("Private Photos").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if !store.gate.covered {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            SportDestructiveButton("Delete Test Data", systemImage: "trash") {
              confirmReset = true
            }
          } label: {
            Label("Options", systemImage: "ellipsis")
          }.tint(.white)
            .disabled(store.gate.phase == .authenticating)
        }
      }
    }
    .sportConfirmation("Delete Test Data?", isPresented: $confirmReset) {
      Button("Delete", role: .destructive) { store.resetSyntheticData() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Only the synthetic file and its test key will be deleted. Training data are unaffected."
      )
    }
    .onDisappear { store.lock() }
    .onChange(of: scenePhase, initial: true) { _, phase in
      switch phase {
      case .active: store.foreground()
      case .inactive: store.cover()
      case .background: store.background()
      @unknown default: store.background()
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    ) { _ in
      store.cover()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
    ) { _ in
      store.background()
    }
  }
}
