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
  @Published var error: String?
  private var request = UUID()
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
  func shoot(delay: Int, aspect: Double) {
    guard ready, !working, countdown == nil, capture == nil else { return }
    let token = request
    working = true
    timer = Task { [weak self] in
      guard let self else { return }
      for value in stride(from: delay, through: 1, by: -1) {
        guard !Task.isCancelled, request == token else { return }
        countdown = value
        try? await Task.sleep(for: .seconds(1))
      }
      guard !Task.isCancelled, request == token else { return }
      countdown = nil
      pipeline.capture { [weak self] bytes in
        guard let self, self.request == token else { return }
        guard let bytes else {
          self.working = false
          self.error = "The photo could not be captured. Try again."
          return
        }
        Task {
          do {
            let prepared = try await Task.detached {
              try BackupAutoreleasePool.withPool {
                try VaultCameraPhoto.prepare(bytes, aspect: aspect)
              }
            }.value
            guard self.request == token else { return }
            guard let image = UIImage(data: prepared) else { throw VaultMediaError.captureFailed }
            self.capture = prepared
            self.capturedImage = image
            self.working = false
          } catch {
            guard self.request == token else { return }
            self.working = false
            self.error = "The photo could not be captured. Try again."
          }
        }
      }
    }
  }
  func cancelCountdown() {
    timer?.cancel()
    timer = nil
    countdown = nil
    working = false
  }
  func retake() {
    capture = nil
    capturedImage = nil
  }
  func stop() {
    request = UUID()
    cancelCountdown()
    ready = false
    retake()
    pipeline.stop()
  }
}
