import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @State private var showingEditor = false
    @State private var editingAlarm: Alarm?
    @State private var refreshID = UUID()
    
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(theme: .system)

                ScrollView {
                    VStack(spacing: 18) {
                        
                        if alarmStore.authorizationStatus == .denied || alarmStore.authorizationStatus == .notDetermined {
                            Button {
                                Task { await alarmStore.requestNotifications() }
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

                        AnimatedClockCard(
                            nextAlarm: alarmStore.alarms.first { $0.isEnabled }
                        )
                        .id(refreshID)

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
                    .padding(20)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Стеклянный Будильник")
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
            .onReceive(timer) { _ in
                refreshID = UUID()
            }
        }
    }
}
