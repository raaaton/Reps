import RepsCore
import SwiftUI

struct VaultCameraRoute: Identifiable {
  let id = UUID()
  let session: UUID
  let plan: VaultPhotoCapturePlan?
  let day: Date
  let sequential: Bool
}

private struct VaultCameraStageID: Hashable {
  let stepID: String?
  let front: Bool
  let retry: UUID
  let active: Bool
}

struct VaultCameraView: View {
  @EnvironmentObject private var vault: PhotoVaultStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let route: VaultCameraRoute
  var onCompleted: () -> Void = {}
  @StateObject private var camera = VaultCameraModel()
  @State private var index = 0
  @State private var opacity = 0.5
  @State private var stencilVisible = true
  @State private var timerSeconds = 0
  @State private var saving = false
  @State private var referenceReady = false
  @State private var saved = 0
  @State private var retry = UUID()
  private var step: VaultPhotoCapturePlan.Step? {
    guard let steps = route.plan?.steps, steps.indices.contains(index) else { return nil }
    return steps[index]
  }
  private var aspect: Double {
    guard referenceReady, let image = vault.preview, image.size.height > 0 else { return 0.75 }
    return Double(image.size.width / image.size.height)
  }
  var body: some View {
    NavigationStack {
      VaultPrivacySurface {
        if vault.allows(route.session), let step {
          captureContent(step)
        } else if route.plan == nil {
          ContentUnavailableView(
            "No Photos to Repeat", systemImage: "photo.stack",
            description: Text(
              "Add a photo first, then start a session to repeat the latest daily photo folder."
            ))
        } else {
          ContentUnavailableView("Vault Locked", systemImage: "lock.fill")
        }
      }
      .navigationTitle(route.sequential ? "Photo Session" : "Take Photo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { close() }.disabled(saving)
        }
      }
      .alert(
        "Unable to Take Photo",
        isPresented: Binding(
          get: { camera.error != nil || vault.error != nil },
          set: {
            if !$0 {
              camera.error = nil
              vault.error = nil
            }
          })
      ) {
        Button("Retry") {
          camera.error = nil
          vault.error = nil
          retry = UUID()
        }
        Button("OK", role: .cancel) {
          camera.error = nil
          vault.error = nil
        }
      } message: {
        Text(camera.error ?? vault.error ?? "")
      }
      .task(
        id: VaultCameraStageID(
          stepID: step?.id, front: camera.front, retry: retry, active: scenePhase == .active)
      ) {
        if scenePhase == .active, vault.allows(route.session), step != nil {
          await prepareReference()
          guard !Task.isCancelled, vault.allows(route.session), scenePhase == .active else {
            return
          }
          if !camera.ready { await camera.start() }
        } else {
          camera.stop()
        }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active {
          camera.stop()
          vault.clearPreview()
          referenceReady = false
        }
      }
      .onChange(of: vault.gate.phase) { _, phase in
        if phase != .unlocked { close() }
      }
      .onDisappear {
        camera.stop()
        vault.clearPreview()
      }
    }.interactiveDismissDisabled(saving)
  }
  private func captureContent(_ step: VaultPhotoCapturePlan.Step) -> some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        ScrollView { cameraLayout(step, previewHeight: 260) }
      } else {
        cameraLayout(step)
      }
    }
  }
  private func cameraLayout(_ step: VaultPhotoCapturePlan.Step, previewHeight: CGFloat? = nil)
    -> some View
  {
    VStack(spacing: 12) {
      VStack(spacing: 4) {
        Text(step.pose?.label ?? "Unassigned Pose").font(.headline)
        if route.sequential, let plan = route.plan {
          Text("\(index + 1) of \(plan.steps.count) · \(saved) saved").font(.subheadline)
        }
        if let reference = step.reference {
          Text("Reference: \(WorkoutLabels.day(reference.metadata.dayKey))")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Text("First photo of this pose").font(.caption).foregroundStyle(.secondary)
        }
      }
      GeometryReader { geometry in
        ZStack {
          VaultCameraPreview(session: camera.pipeline.session, front: camera.front)
          if let image = camera.capturedImage {
            Image(uiImage: image).resizable().scaledToFit()
          } else if stencilVisible, let image = vault.preview, referenceReady {
            Image(uiImage: image).resizable().scaledToFit().opacity(opacity)
              .allowsHitTesting(false).accessibilityHidden(true)
          }
          if let value = camera.countdown {
            Text("\(value)").font(.system(size: 72, weight: .bold, design: .rounded))
              .foregroundStyle(.white).shadow(radius: 3)
              .accessibilityLabel("Photo in \(value) seconds")
              .accessibilityAddTraits(.updatesFrequently)
          }
          if !camera.ready, camera.capture == nil { ProgressView().tint(.white) }
        }
        .aspectRatio(aspect, contentMode: .fit).clipped()
        .background(.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          camera.countdown.map { "Photo in \($0) seconds" }
            ?? (camera.capture == nil ? "Camera preview with pose reference" : "Captured photo")
        )
        .accessibilityAddTraits(.updatesFrequently)
        .frame(width: geometry.size.width, height: geometry.size.height)
      }.frame(minHeight: 120).frame(height: previewHeight)
      if camera.capture != nil {
        reviewControls
      } else {
        liveControls(step)
      }
    }.padding()
  }
  private var reviewControls: some View {
    VStack(spacing: 12) {
      if saving { ProgressView("Encrypting and saving…") }
      Button(route.sequential ? "Save and Continue" : "Save Photo", systemImage: "checkmark") {
        Task { await save() }
      }.repsProminentButton().disabled(saving)
      Button("Retake", systemImage: "arrow.counterclockwise") { camera.retake() }
        .disabled(saving)
    }.frame(maxWidth: .infinity)
  }
  private func liveControls(_ step: VaultPhotoCapturePlan.Step) -> some View {
    VStack(spacing: 12) {
      if step.reference != nil {
        Toggle("Stencil", isOn: $stencilVisible).disabled(!referenceReady)
        HStack {
          Slider(value: $opacity, in: 0...1).accessibilityLabel("Stencil opacity")
            .accessibilityValue("\(Int(opacity * 100)) percent")
          Text("\(Int(opacity * 100))%").monospacedDigit().font(.caption)
        }.disabled(!referenceReady || !stencilVisible)
        if !referenceReady { Text("Loading reference…").font(.caption).foregroundStyle(.secondary) }
      }
      HStack {
        Menu {
          Picker("Timer", selection: $timerSeconds) {
            Text("Off").tag(0)
            Text("3 seconds").tag(3)
            Text("10 seconds").tag(10)
          }
        } label: {
          Label(timerSeconds == 0 ? "Timer Off" : "\(timerSeconds)s", systemImage: "timer")
        }
        .disabled(camera.working)
        Spacer()
        Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
          camera.flip()
        }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).disabled(camera.working)
      }
      if camera.countdown != nil {
        Button("Cancel Timer", systemImage: "xmark") { camera.cancelCountdown() }
      } else {
        Button("Take Photo", systemImage: "camera.shutter.button.fill") {
          camera.shoot(delay: timerSeconds, aspect: aspect)
        }.repsProminentButton().controlSize(.large)
          .disabled(!camera.ready || camera.working || !referenceReady)
      }
      if route.sequential {
        Button("Skip Photo", systemImage: "forward.end") { advance() }.disabled(camera.working)
      }
      Text("Photos are saved only in your encrypted vault.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
  private func prepareReference() async {
    referenceReady = false
    vault.clearPreview()
    guard vault.allows(route.session), let step, scenePhase == .active else { return }
    if let reference = step.reference {
      await vault.loadPreview(id: reference.id, session: route.session)
      guard !Task.isCancelled, vault.allows(route.session), scenePhase == .active,
        self.step?.id == step.id
      else { return }
      referenceReady = vault.preview != nil
    } else {
      referenceReady = true
    }
  }
  private func save() async {
    guard !saving, vault.allows(route.session), !vault.busy,
      let step, let bytes = camera.capture
    else { return }
    saving = true
    await vault.importCamera(bytes, day: route.day, pose: step.pose, session: route.session)
    saving = false
    guard vault.allows(route.session), vault.error == nil else { return }
    saved += 1
    advance()
  }
  private func advance() {
    camera.retake()
    vault.clearPreview()
    referenceReady = false
    if let steps = route.plan?.steps, index + 1 < steps.count {
      index += 1
    } else {
      close()
      onCompleted()
    }
  }
  private func close() {
    camera.stop()
    vault.clearPreview()
    dismiss()
  }
}
