import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue
    @State private var showingEditor = false
    @State private var editingAlarm: Alarm?
    @State private var refreshID = UUID()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(theme: currentTheme)

                ScrollView {
                    VStack(spacing: 18) {
                        
                        if alarmStore.authorizationStatus == .denied || alarmStore.authorizationStatus == .notDetermined {
                            notificationWarningCard
                        }

                        AnimatedClockCard(
                            nextAlarm: alarmStore.alarms.first { $0.isEnabled }
                        )
                        .id(refreshID)

                        alarmsList
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
                
                // Полноэкранный режим будильника
                if let alarm = alarmStore.activeAlarm {
                    AlarmActiveView(alarm: alarm) {
                        alarmStore.activeAlarm = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("Стеклянный Будильник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if alarmStore.activeAlarm == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                AlarmEditorView(mode: .create) { alarm in
                    Task {
                        await alarmStore.add(alarm)
                    }
                }
                .environmentObject(alarmStore)
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(mode: .edit(alarm)) { edited in
                    Task {
                        await alarmStore.update(edited)
                    }
                }
                .environmentObject(alarmStore)
            }
            .onReceive(timer) { _ in
                refreshID = UUID()
            }
        }
    }

    private var notificationWarningCard: some View {
        Button {
            Task {
                _ = await alarmStore.requestNotifications()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Уведомления выключены")
                        .font(.headline)
                    Text("Включите их, чтобы будильник мог звенеть")
                        .font(.caption)
                }
                Spacer()
                Text("Включить")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private var alarmsList: some View {
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

    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .dark
    }
}
