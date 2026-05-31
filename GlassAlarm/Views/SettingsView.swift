import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue
    @AppStorage(AppSettingsKeys.defaultRingtone) private var defaultRingtone = AlarmRingtone.crystal.rawValue
    @AppStorage(AppSettingsKeys.defaultVibration) private var defaultVibration = true
    @State private var statusMessage: String?
    @State private var isSchedulingTest = false

    var body: some View {
        ZStack {
            GlassBackground(theme: currentTheme)

            ScrollView {
                VStack(spacing: 16) {
                    themeCard
                    defaultAlarmCard
                    testCard
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassCard()
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            alarmStore.stopRingtonePreview()
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .dark
    }

    private var selectedRingtone: AlarmRingtone {
        AlarmRingtone(rawValue: defaultRingtone) ?? .crystal
    }

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Тема")
                .font(.headline)

            ForEach(AppTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        selectedTheme = theme.rawValue
                    }
                } label: {
                    HStack {
                        Label(theme.title, systemImage: theme.icon)
                        Spacer()
                        if theme.rawValue == selectedTheme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(theme.rawValue == selectedTheme ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var defaultAlarmCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("По умолчанию для новых будильников")
                .font(.headline)

            Picker("Рингтон", selection: $defaultRingtone) {
                ForEach(AlarmRingtone.allCases) { ringtone in
                    Text(ringtone.title).tag(ringtone.rawValue)
                }
            }
            .tint(.white)
            .onChange(of: defaultRingtone) { _, newValue in
                let ringtone = AlarmRingtone(rawValue: newValue) ?? .crystal
                alarmStore.previewRingtone(ringtone)
            }

            Toggle(isOn: $defaultVibration) {
                Text("Вибрация")
            }
            .tint(Color.accentColor)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Проверка")
                .font(.headline)

            Button {
                alarmStore.previewRingtone(selectedRingtone)
            } label: {
                Label("Прослушать рингтон", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                alarmStore.previewVibration()
            } label: {
                Label("Проверить вибрацию", systemImage: "iphone.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { @MainActor in
                    isSchedulingTest = true
                    let ok = await alarmStore.scheduleTestNotification(after: 5)
                    isSchedulingTest = false
                    statusMessage = ok
                        ? "Тестовое уведомление будет через 5 секунд"
                        : "Разреши уведомления в настройках iOS, иначе будильник не сработает"
                }
            } label: {
                Label(isSchedulingTest ? "Планирую тест..." : "Тест звонка через 5 секунд", systemImage: "alarm")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSchedulingTest)

            Button {
                alarmStore.stopRingtonePreview()
            } label: {
                Label("Остановить звук", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }
}
