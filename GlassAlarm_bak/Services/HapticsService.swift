import Foundation
import UIKit
import AudioToolbox

enum HapticsService {
    static func playAlarmPreview() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        feedback.notificationOccurred(.warning)
    }
}
