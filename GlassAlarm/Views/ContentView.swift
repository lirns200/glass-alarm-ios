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

    private var nextEnabledAlarm: Alarm? {
        alarmStore.alarms.first { $0.isEnabled }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(theme: theme)

                ScrollView {
                    VStack(spacing: 18) {
                        HeaderView(theme: theme)

                        if alarmStore.authorizationStatus != .authorized && alarmStore.authorizationStatus != .provisional {
                            PermissionCard {
                                Task { await alarmStore.requestNotifications() }
                            }
                        }

                        ThemePicker(selectedTheme: $selectedTheme)

                        AnimatedClockCard(nextAlarm: nextEnabledAlarm)

                        LazyVStack(spacing: 12) {
                            ForEach(alarmStore.alarms) { alarm in
                                AlarmRow(alarm: alarm) {
                                    Task { await alarmStore.setEnabled(alarm, isEnabled: $0) }
                                } delete: {
                                    Task { await alarmStore.delete(alarm) }
                                }
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
                            .font(.headline)
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(isPresented: $showingEditor) {
                AlarmEditorView(mode: .create) { alarm in
                    Task { await alarmStore.add(alarm) }
                }
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(mode: .edit(alarm)) { edited in
                    Task { await alarmStore.update(edited) }
                }
            }
        }
    }
}

private struct HeaderView: View {
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Wake softly")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Glass UI, calm motion, clean alarms")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: theme.icon)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

private struct PermissionCard: View {
    let request: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications are off")
                    .font(.headline)
                Text("Turn them on so alarms can ring.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Enable", action: request)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .glassCard()
    }
}

private struct ThemePicker: View {
    @Binding var selectedTheme: String

    var body: some View {
        Picker("Theme", selection: $selectedTheme) {
            ForEach(AppTheme.allCases) { theme in
                Label(theme.title, systemImage: theme.icon).tag(theme.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(8)
        .glassCard()
    }
}
