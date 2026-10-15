import AudioToolbox
import Foundation
import UIKit

@MainActor
final class RestFeedback {
  private var sound: SystemSoundID = 0

  init() {
    if let url = Bundle.module.url(forResource: "RestComplete", withExtension: "wav") {
      if AudioServicesCreateSystemSoundID(url as CFURL, &sound) != noErr { sound = 0 }
    }
  }

  func play() {
    SportHaptics.shared.play(.success)
    if sound != 0 { AudioServicesPlaySystemSound(sound) }
  }
}
