import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}

@main
struct GlassAlarmApp: App {
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
        }
    }
}
