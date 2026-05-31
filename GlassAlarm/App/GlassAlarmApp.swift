import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UNUserNotificationCenterDelegate {
    private var defaultVibration: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.defaultVibration) as? Bool ?? true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        triggerVibrationIfNeeded(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        triggerVibrationIfNeeded(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func triggerVibrationIfNeeded(userInfo: [AnyHashable: Any]) {
        let vibrates = userInfo["vibrates"] as? Bool ?? defaultVibration
        guard vibrates else { return }

        HapticsService.playAlarmPreview()
    }
}

@main
struct GlassAlarmApp: App {
    private static let buildUniqueId = "c359253391344974f299e490cdb145a8"
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var alarmStore = AlarmStore()
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue
    @AppStorage(AppSettingsKeys.didForceDarkThemeV1) private var didForceDarkThemeV1 = false
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
                    enforceDarkThemeMigrationIfNeeded()
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

    private func enforceDarkThemeMigrationIfNeeded() {
        guard !didForceDarkThemeV1 else { return }
        selectedTheme = AppTheme.dark.rawValue
        didForceDarkThemeV1 = true
    }
}
