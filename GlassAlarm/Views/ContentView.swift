import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.system.rawValue
    @State private var showingEditor = false
    @State private var editingAlarm: Alarm?

    private var theme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Glass Alarm")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    AlarmEditorView(mode: .create) { alarm in
                        Task {
                            await alarmStore.add(alarm)
                        }
                    }
                }
                .sheet(item: $editingAlarm) { alarm in
                    AlarmEditorView(mode: .edit(alarm)) { edited in
                        Task {
                            await alarmStore.update(edited)
                        }
                    }
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            GlassBackground(theme: theme)

            ScrollView {
                VStack(spacing: 18) {
                    HeaderView(theme: theme)

                    if alarmStore.authorizationStatus != .authorized &&
                        alarmStore.authorizationStatus != .provisional {

                        PermissionCard {
                            Task {
                                await alarmStore.requestNotifications()
                            }
                        }
                    }

                    ThemePicker(selectedTheme: $selectedTheme)

                    AnimatedClockCard(
                        nextAlarm: alarmStore.alarms.first { $0.isEnabled }
                    )

                    alarmList
                }
                .padding(20)
                .padding(.bottom, 96)
            }
        }
    }

    private var alarmList: some View {
        LazyVStack(spacing: 12) {
            ForEach(alarmStore.alarms) { alarm in
                AlarmRow(
                    alarm: alarm,
                    toggle: { enabled in
                        Task {
                            await alarmStore.setEnabled(
                                alarm,
                                isEnabled: enabled
                            )
                        }
                    },
                    delete: {
                        Task {
                            await alarmStore.delete(alarm)
                        }
                    }
                )
                .onTapGesture {
                    editingAlarm = alarm
                }
            }
        }
    }
}
