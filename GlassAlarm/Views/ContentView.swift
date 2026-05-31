import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @State private var showingEditor = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(theme: .system)

                ScrollView {
                    VStack(spacing: 18) {

                        AnimatedClockCard(
                            nextAlarm: alarmStore.alarms.first { $0.isEnabled }
                        )

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
}