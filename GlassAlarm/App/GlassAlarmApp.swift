import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UNUserNotificationCenterDelegate {
    var alarmStore: AlarmStore?

    private var defaultVibration: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.defaultVibration) as? Bool ?? true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handleAlarmNotification(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleAlarmNotification(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func handleAlarmNotification(userInfo: [AnyHashable: Any]) {
        triggerVibrationIfNeeded(userInfo: userInfo)
        
        if let idString = userInfo["alarmId"] as? String,
           let id = UUID(uuidString: idString) {
            Task { @MainActor in
                if let alarm = self.alarmStore?.alarms.first(where: { $0.id == id }) {
                    self.alarmStore?.activeAlarm = alarm
                }
            }
        }
    }

    private func triggerVibrationIfNeeded(userInfo: [AnyHashable: Any]) {
        let vibrates = userInfo["vibrates"] as? Bool ?? defaultVibration
        guard vibrates else { return }
        HapticsService.playAlarmPreview()
    }
}

@main
struct GlassAlarmApp: App {
    private static let buildUniqueId = "ef0ece8351da2020e3ed656930bf7a0c"
    
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
                    appDelegate.alarmStore = alarmStore
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
