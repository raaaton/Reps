import AVFoundation
import Foundation
import RepsCore
import SwiftUI
import UIKit

@MainActor
final class VaultCameraModel: ObservableObject {
  let pipeline = VaultCameraPipeline()
  @Published private(set) var ready = false
  @Published private(set) var working = false
  @Published private(set) var front = false
  @Published private(set) var capture: Data?
  @Published private(set) var capturedImage: UIImage?
  @Published private(set) var countdown: Int?
  @Published private(set) var stencilAligned = false
  @Published private(set) var alignmentAvailable = false
  @Published private(set) var alignmentAttempted = false
  @Published private(set) var usesAlignment = false
  @Published private(set) var alignedReference: UIImage?
  private var originalCapture: Data?
  private var originalImage: UIImage?
  private var alignedCapture: Data?
  private var alignedImage: UIImage?
  private var registration: VaultPhotoRegistration?
  private var referenceRequest = UUID()
  private var processing: Task<Void, Never>?
  private var preparation: Task<PhotoResult, Error>?
  @Published var error: String?
  private var request = UUID()
  private var captureRequest = UUID()
  private var timer: Task<Void, Never>?
  func start() async {
    let token = UUID()
    request = token
    ready = false
    let permitted: Bool
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: permitted = true
    case .notDetermined: permitted = await AVCaptureDevice.requestAccess(for: .video)
    default: permitted = false
    }
    guard token == request, !Task.isCancelled else { return }
    guard permitted else {
      error = "Allow camera access in the iOS settings for Reps."
      return
    }
    working = true
    pipeline.start(front: front) { [weak self] success in
      guard let self, self.request == token else { return }
      self.working = false
      self.ready = success
      if !success { self.error = "Camera unavailable. Close the camera and try again." }
    }
  }
  func flip() {
    guard !working, countdown == nil, capture == nil else { return }
    stop()
    front.toggle()
  }
  private struct PhotoResult: Sendable {
    let original: Data
    let aligned: VaultCameraAlignment.Prepared?
  }
  var selectedRegistration: VaultPhotoRegistration? { usesAlignment ? registration : nil }

  func setReference(_ image: UIImage?, aspect: Double) {
    let token = UUID()
    referenceRequest = token
    stencilAligned = false
    let reference = image?.cgImage.flatMap {
      try? VaultCameraAlignment.grayscale($0, aspect: aspect)
    }
    pipeline.setReference(reference, aspect: aspect) { [weak self] aligned in
      guard let self, self.referenceRequest == token, self.capture == nil else { return }
      self.stencilAligned = aligned
    }
  }

  func shoot(delay: Int, aspect: Double, reference: UIImage?, referenceID: String?) {
    guard ready, !working, countdown == nil, capture == nil else { return }
    let token = request
    let shot = UUID()
    captureRequest = shot
    working = true
    timer = Task { [weak self] in
      guard let self else { return }
      for value in stride(from: delay, through: 1, by: -1) {
        guard !Task.isCancelled, request == token, captureRequest == shot else { return }
        countdown = value
        try? await Task.sleep(for: .seconds(1))
      }
      guard !Task.isCancelled, request == token, captureRequest == shot else { return }
      countdown = nil
      pipeline.capture { [weak self] bytes in
        guard let self, self.request == token, self.captureRequest == shot else { return }
        guard let bytes else {
          self.working = false
          self.error = "The photo could not be captured. Try again."
          return
        }
        let referenceImage = reference?.cgImage
        let preparation = Task.detached {
          try BackupAutoreleasePool.withPool {
            try Task.checkCancellation()
            let original = try VaultCameraPhoto.prepare(bytes, aspect: aspect)
            try Task.checkCancellation()
            let aligned = referenceImage.flatMap {
              try? VaultCameraAlignment.prepare(original, reference: $0)
            }
            try Task.checkCancellation()
            return PhotoResult(original: original, aligned: aligned)
          }
        }
        self.preparation = preparation
        self.processing = Task { [weak self] in
          guard let self else { return }
          do {
            let result = try await preparation.value
            guard !Task.isCancelled, self.request == token, self.captureRequest == shot else {
              return
            }
            guard let image = UIImage(data: result.original) else {
              throw VaultMediaError.captureFailed
            }
            self.originalCapture = result.original
            self.originalImage = image
            self.alignmentAttempted = referenceImage != nil
            if let aligned = result.aligned, let reference, let referenceID,
              let alignedImage = UIImage(data: aligned.bytes),
              let croppedReference = try? VaultCameraAlignment.cropReference(
                reference, crop: aligned.crop)
            {
              self.alignedCapture = aligned.bytes
              self.alignedImage = alignedImage
              self.alignedReference = croppedReference
              self.registration = VaultPhotoRegistration(
                referenceID: referenceID, referenceCrop: aligned.crop)
              self.alignmentAvailable = true
            }
            self.selectAligned(self.alignmentAvailable)
            self.working = false
            self.preparation = nil
            self.processing = nil
          } catch {
            guard !Task.isCancelled, self.request == token, self.captureRequest == shot else {
              return
            }
            self.working = false
            self.preparation = nil
            self.processing = nil
            self.error = "The photo could not be captured. Try again."
          }
        }
      }
    }
  }
  func selectAligned(_ value: Bool) {
    usesAlignment = value && alignmentAvailable
    capture = usesAlignment ? alignedCapture : originalCapture
    capturedImage = usesAlignment ? alignedImage : originalImage
  }
  func cancelCountdown() {
    captureRequest = UUID()
    pipeline.cancelCapture()
    timer?.cancel()
    timer = nil
    countdown = nil
    working = false
  }
  func retake() {
    captureRequest = UUID()
    preparation?.cancel()
    preparation = nil
    processing?.cancel()
    processing = nil
    capture = nil
    capturedImage = nil
    originalCapture = nil
    originalImage = nil
    alignedCapture = nil
    alignedImage = nil
    alignedReference = nil
    registration = nil
    alignmentAvailable = false
    alignmentAttempted = false
    usesAlignment = false
    stencilAligned = false
  }
  func stop() {
    request = UUID()
    referenceRequest = UUID()
    cancelCountdown()
    ready = false
    retake()
    pipeline.stop()
  }
}
