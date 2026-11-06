import AVFoundation
import CoreImage
import Foundation
import RepsCore

// Mutable capture state is confined to queue. Only the documented AVCaptureSession
// reference is shared with the main-thread preview layer; UI never mutates the session.
final class VaultCameraPipeline: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "com.raaaton.sport.private-camera")
  private let output = AVCapturePhotoOutput()
  private let frames = AVCaptureVideoDataOutput()
  private let imageContext = CIContext(options: [.cacheIntermediates: false])
  private var reference: VaultAlignmentImage?
  private var aspect = 0.75
  private var alignment: (@MainActor @Sendable (Bool) -> Void)?
  private var lastFrameTime = -Double.infinity
  private var stableMatches = 0
  private var input: AVCaptureDeviceInput?
  private var pending: (id: Int64, completion: @MainActor @Sendable (Data?) -> Void)?
  private var enabled = false

  func start(front: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
    queue.async { [self] in
      guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
        Task { @MainActor in completion(false) }
        return
      }
      do {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let position: AVCaptureDevice.Position = front ? .front : .back
        guard
          let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position)
        else {
          throw VaultMediaError.captureFailed
        }
        let next = try AVCaptureDeviceInput(device: device)
        if let input {
          session.removeInput(input)
          self.input = nil
        }
        guard session.canAddInput(next) else { throw VaultMediaError.captureFailed }
        session.addInput(next)
        input = next
        if !session.outputs.contains(output) {
          guard session.canAddOutput(output) else { throw VaultMediaError.captureFailed }
          session.addOutput(output)
          output.maxPhotoQualityPrioritization = .quality
        }
        if !session.outputs.contains(frames) {
          guard session.canAddOutput(frames) else { throw VaultMediaError.captureFailed }
          frames.alwaysDiscardsLateVideoFrames = true
          frames.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
          ]
          frames.setSampleBufferDelegate(self, queue: queue)
          session.addOutput(frames)
        }
        try device.lockForConfiguration()
        device.videoZoomFactor = 1
        device.unlockForConfiguration()
        for connection in [output.connection(with: .video), frames.connection(with: .video)] {
          guard let c = connection else { continue }
          if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
          if c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = front
          }
        }
      } catch {
        enabled = false
        if session.isRunning { session.stopRunning() }
        Task { @MainActor in completion(false) }
        return
      }
      enabled = true
      if !session.isRunning { session.startRunning() }
      let ready = session.isRunning
      Task { @MainActor in completion(ready) }
    }
  }
  func stop() {
    queue.async { [self] in
      enabled = false
      pending = nil
      reference = nil
      alignment = nil
      stableMatches = 0
      lastFrameTime = -Double.infinity
      if session.isRunning { session.stopRunning() }
    }
  }
  func setReference(
    _ reference: VaultAlignmentImage?, aspect: Double,
    completion: @escaping @MainActor @Sendable (Bool) -> Void
  ) {
    queue.async { [self] in
      self.reference = reference
      self.aspect = aspect
      alignment = completion
      stableMatches = 0
      lastFrameTime = -Double.infinity
    }
  }
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
    guard enabled, let reference, let alignment, time - lastFrameTime >= 0.3,
      let buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }
    lastFrameTime = time
    let matches =
      (try? BackupAutoreleasePool.withPool {
        let frame = CIImage(cvPixelBuffer: buffer)
        guard let image = imageContext.createCGImage(frame, from: frame.extent) else {
          return false
        }
        return VaultPhotoAlignment.evaluate(
          reference: reference,
          moving: try VaultCameraAlignment.grayscale(image, aspect: aspect)
        ).isReliable
      }) ?? false
    stableMatches = matches ? min(stableMatches + 1, 3) : 0
    let stable = stableMatches >= 3
    Task { @MainActor in alignment(stable) }
  }
  func capture(completion: @escaping @MainActor @Sendable (Data?) -> Void) {
    queue.async { [self] in
      guard enabled, session.isRunning, pending == nil else {
        Task { @MainActor in completion(nil) }
        return
      }
      let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
      pending = (settings.uniqueID, completion)
      settings.photoQualityPrioritization = .quality
      output.capturePhoto(with: settings, delegate: self)
    }
  }
  func cancelCapture() {
    queue.async { [self] in pending = nil }
  }
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    // This is an in-memory representation, never an app-authored plaintext file.
    let bytes = error == nil ? photo.fileDataRepresentation() : nil
    let id = photo.resolvedSettings.uniqueID
    queue.async { [self] in
      guard enabled, let pending, pending.id == id else { return }
      self.pending = nil
      Task { @MainActor in pending.completion(bytes) }
    }
  }
  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?
  ) {
    guard error != nil else { return }
    let id = resolvedSettings.uniqueID
    queue.async { [self] in
      guard enabled, let pending, pending.id == id else { return }
      self.pending = nil
      Task { @MainActor in pending.completion(nil) }
    }
  }
}
