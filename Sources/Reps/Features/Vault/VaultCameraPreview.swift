import AVFoundation
import SwiftUI
import UIKit

struct VaultCameraPreview: UIViewRepresentable {
  let session: AVCaptureSession
  let front: Bool
  func makeUIView(context: Context) -> Surface {
    let view = Surface()
    view.preview.session = session
    return view
  }
  func updateUIView(_ view: Surface, context: Context) {
    view.front = front
    view.setNeedsLayout()
  }
  final class Surface: UIView {
    var front = false
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
      super.layoutSubviews()
      preview.videoGravity = .resizeAspectFill
      if let c = preview.connection {
        if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        if c.isVideoMirroringSupported {
          c.automaticallyAdjustsVideoMirroring = false
          c.isVideoMirrored = front
        }
      }
    }
  }
}
