import SwiftUI
import UserNotifications
import AudioToolbox

class AppDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        triggerVibrationIfNeeded(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        triggerVibrationIfNeeded(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func triggerVibrationIfNeeded(userInfo: [AnyHashable: Any]) {
        let vibrates = userInfo["vibrates"] as? Bool ?? true
        guard vibrates else { return }

        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        feedback.notificationOccurred(.warning)
    }
}

@main
struct GlassAlarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var alarmStore = AlarmStore()
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.system.rawValue
    private let appDelegate = AppDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = appDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .preferredColorScheme(AppTheme(rawValue: selectedTheme)?.colorScheme)
                .task {
                    await alarmStore.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await alarmStore.appBecameActive()
                    }
                }
        }
    }
}
