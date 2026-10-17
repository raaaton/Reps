import SwiftUI

// Scope the native alert's neutral tint to its own presenter. The underlying
// screen keeps its accent; destructive actions keep their native red role.
extension View {
  func sportConfirmation<Actions: View, Message: View>(
    _ title: String, isPresented: Binding<Bool>,
    @ViewBuilder actions: () -> Actions, @ViewBuilder message: () -> Message
  ) -> some View {
    background {
      Color.clear
        .alert(title, isPresented: isPresented, actions: actions, message: message)
        .tint(.primary)
        .frame(width: 0, height: 0)
    }
  }

  func sportConfirmation<Data, Actions: View, Message: View>(
    _ title: String, isPresented: Binding<Bool>, presenting data: Data?,
    @ViewBuilder actions: (Data) -> Actions, @ViewBuilder message: (Data) -> Message
  ) -> some View {
    background {
      Color.clear
        .alert(
          title, isPresented: isPresented, presenting: data, actions: actions, message: message
        )
        .tint(.primary)
        .frame(width: 0, height: 0)
    }
  }
}
