import SwiftUI

@main
struct GlassAlarmApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.system.rawValue

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
