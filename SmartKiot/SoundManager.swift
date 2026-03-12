import Foundation
import AVFoundation
import AudioToolbox
import UIKit

struct AppSound {
    static func playIncomingMessage() {
        if !NotificationManager.shared.soundEnabled { return }
        AudioServicesPlaySystemSound(1007)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
