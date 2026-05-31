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

struct AlarmActiveView: View {
    let alarm: Alarm
    let dismiss: () -> Void
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Динамический фон
            GlassBackground(theme: .dark)
                .opacity(animate ? 0.6 : 0.3)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Иконка и статус
                VStack(spacing: 16) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, options: .repeat(.infinite), value: animate)
                    
                    Text(alarm.title.isEmpty ? "БУДИЛЬНИК" : alarm.title.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .kerning(4)
                        .foregroundStyle(.white)
                }
                
                // Время
                Text(alarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .scaleEffect(animate ? 1.05 : 1.0)
                
                Spacer()
                
                // Кнопки управления
                VStack(spacing: 20) {
                    Button {
                        dismiss()
                    } label: {
                        Text("ПОДРЕМАТЬ")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.white.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("ВЫКЛЮЧИТЬ")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color.red.opacity(0.8), in: Capsule())
                            .shadow(color: .red.opacity(0.4), radius: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
