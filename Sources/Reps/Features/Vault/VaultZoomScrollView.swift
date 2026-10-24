import SwiftUI
import UIKit

struct VaultZoomCommand {
  let id = UUID()
  let scale: CGFloat
}

// UIKit owns pinch anchoring and pan; the surrounding screen remains SwiftUI.
struct VaultZoomScrollView: UIViewRepresentable {
  let image: UIImage
  let imageID: String
  let viewport: CGSize
  let command: VaultZoomCommand?
  var onAlternate: (() -> Void)?
  func makeCoordinator() -> Coordinator { Coordinator(onAlternate: onAlternate) }
  func makeUIView(context: Context) -> VaultZoomCanvas {
    let view = VaultZoomCanvas(frame: CGRect(origin: .zero, size: viewport))
    view.delegate = context.coordinator
    if onAlternate != nil {
      let tap = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.tapped))
      tap.numberOfTouchesRequired = 1
      tap.cancelsTouchesInView = false
      tap.require(toFail: view.panGestureRecognizer)
      view.addGestureRecognizer(tap)
    } else {
      let tap = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
      tap.numberOfTapsRequired = 2
      view.addGestureRecognizer(tap)
    }
    return view
  }
  func updateUIView(_ view: VaultZoomCanvas, context: Context) {
    view.configureViewport(viewport)
    context.coordinator.onAlternate = onAlternate
    if context.coordinator.imageID != imageID {
      view.photo.image = image
      context.coordinator.imageID = imageID
    }
    if let command, command.id != context.coordinator.commandID {
      view.layoutIfNeeded()
      guard view.bounds.width > 0, view.bounds.height > 0 else { return }
      context.coordinator.commandID = command.id
      let target = min(4, max(1, command.scale))
      let size = CGSize(width: view.bounds.width / target, height: view.bounds.height / target)
      let center = CGPoint(
        x: (view.contentOffset.x + view.bounds.width / 2) / view.zoomScale,
        y: (view.contentOffset.y + view.bounds.height / 2) / view.zoomScale)
      view.zoom(
        to: CGRect(
          x: center.x - size.width / 2, y: center.y - size.height / 2,
          width: size.width, height: size.height), animated: false)
    }
  }
  static func dismantleUIView(_ view: VaultZoomCanvas, coordinator: Coordinator) {
    view.photo.image = nil
    view.delegate = nil
    coordinator.onAlternate = nil
  }
  @MainActor final class Coordinator: NSObject, UIScrollViewDelegate {
    var onAlternate: (() -> Void)?
    var imageID: String?
    var commandID: UUID?
    init(onAlternate: (() -> Void)?) { self.onAlternate = onAlternate }
    @objc func tapped() { onAlternate?() }
    @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
      guard let view = gesture.view as? VaultZoomCanvas else { return }
      let target: CGFloat = view.zoomScale > 1.01 ? 1 : 2
      let point = gesture.location(in: view.canvas)
      let size = CGSize(width: view.bounds.width / target, height: view.bounds.height / target)
      view.zoom(
        to: CGRect(
          x: point.x - size.width / 2, y: point.y - size.height / 2,
          width: size.width, height: size.height), animated: false)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      (scrollView as? VaultZoomCanvas)?.canvas
    }
  }
}

final class VaultZoomCanvas: UIScrollView {
  let canvas = UIView()
  let photo = UIImageView()
  private var viewport = CGSize.zero
  override init(frame: CGRect) {
    super.init(frame: frame)
    minimumZoomScale = 1
    maximumZoomScale = 4
    bouncesZoom = true
    clipsToBounds = true
    showsHorizontalScrollIndicator = false
    showsVerticalScrollIndicator = false
    contentInsetAdjustmentBehavior = .never
    photo.contentMode = .scaleAspectFit
    photo.clipsToBounds = true
    canvas.addSubview(photo)
    addSubview(canvas)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  // Called only from SwiftUI's fixed GeometryReader viewport, never UIKit's pinch layout.
  func configureViewport(_ size: CGSize) {
    guard size.width > 0, size.height > 0, size != viewport else { return }
    let scale = min(4, max(1, zoomScale))
    let center =
      viewport == .zero
      ? CGPoint(x: 0.5, y: 0.5)
      : CGPoint(
        x: (contentOffset.x + viewport.width / 2) / (viewport.width * scale),
        y: (contentOffset.y + viewport.height / 2) / (viewport.height * scale))
    viewport = size
    setZoomScale(1, animated: false)
    canvas.frame = CGRect(origin: .zero, size: size)
    photo.frame = canvas.bounds
    contentSize = size
    setZoomScale(scale, animated: false)
    setContentOffset(
      CGPoint(
        x: min(max(0, center.x * size.width * scale - size.width / 2), size.width * (scale - 1)),
        y: min(max(0, center.y * size.height * scale - size.height / 2), size.height * (scale - 1))),
      animated: false)
  }
}
