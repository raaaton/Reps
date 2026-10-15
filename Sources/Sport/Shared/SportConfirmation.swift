import SwiftUI
import UIKit

// Keep SwiftUI's native alert and its original actions/bindings. Only neutralize
// its public UIKit tint; destructive actions keep their system role and red color.
extension View {
  func sportConfirmation<Actions: View, Message: View>(
    _ title: String, isPresented: Binding<Bool>,
    @ViewBuilder actions: () -> Actions, @ViewBuilder message: () -> Message
  ) -> some View {
    alert(title, isPresented: isPresented, actions: actions, message: message)
      .background {
        NeutralAlertTint(isPresented: isPresented.wrappedValue)
          .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
      }
  }

  func sportConfirmation<Data, Actions: View, Message: View>(
    _ title: String, isPresented: Binding<Bool>, presenting data: Data?,
    @ViewBuilder actions: (Data) -> Actions, @ViewBuilder message: (Data) -> Message
  ) -> some View {
    alert(title, isPresented: isPresented, presenting: data, actions: actions, message: message)
      .background {
        NeutralAlertTint(isPresented: isPresented.wrappedValue)
          .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
      }
  }
}

@MainActor
private struct NeutralAlertTint: UIViewControllerRepresentable {
  let isPresented: Bool
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    controller.view.backgroundColor = .clear
    controller.view.isUserInteractionEnabled = false
    return controller
  }
  func updateUIViewController(_ controller: UIViewController, context: Context) {
    context.coordinator.update(controller, isPresented: isPresented)
  }
  static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
    coordinator.update(controller, isPresented: false)
  }

  @MainActor
  final class Coordinator {
    private var task: Task<Void, Never>?
    private var wasPresented = false
    func update(_ controller: UIViewController, isPresented: Bool) {
      guard isPresented != wasPresented else { return }
      wasPresented = isPresented
      task?.cancel()
      task = nil
      guard isPresented else { return }
      // SwiftUI presents after the state update. Wait at most one second for
      // that controller; never poll indefinitely or inspect titles/content.
      task = Task { @MainActor [weak controller] in
        for _ in 0..<60 {
          guard !Task.isCancelled, UIApplication.shared.applicationState == .active else { return }
          if let controller,
            let alert = Self.alert(in: controller.viewIfLoaded?.window?.rootViewController)
          {
            alert.view.tintColor = .label
            return
          }
          do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
        }
      }
    }
    private static func alert(in controller: UIViewController?, depth: Int = 0)
      -> UIAlertController?
    {
      guard let controller, depth < 12 else { return nil }
      if let alert = controller as? UIAlertController, !alert.isBeingDismissed { return alert }
      if let alert = alert(in: controller.presentedViewController, depth: depth + 1) {
        return alert
      }
      for child in controller.children {
        if let alert = alert(in: child, depth: depth + 1) { return alert }
      }
      return nil
    }
  }
}
