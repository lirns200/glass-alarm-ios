import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @AppStorage(AppSettingsKeys.selectedTheme) private var selectedTheme = AppTheme.dark.rawValue
    @AppStorage(AppSettingsKeys.defaultRingtone) private var defaultRingtone = AlarmRingtone.crystal.rawValue
    @AppStorage(AppSettingsKeys.defaultVibration) private var defaultVibration = true
    @State private var statusMessage: String?
    @State private var isSchedulingTest = false
    @State private var showingGame = false
    @State private var tapCount = 0
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        ZStack {
            GlassBackground(theme: currentTheme)

            ScrollView {
                VStack(spacing: 16) {
                    themeCard
                    defaultAlarmCard
                    testCard
                    aboutCard
                    
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
        .fullScreenCover(isPresented: $showingGame) {
            SecretGameView()
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
                    .contentShape(Rectangle()) // Make entire row tappable
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
            Text("По умолчанию")
                .font(.headline)

            HStack {
                Text("Рингтон")
                Spacer()
                Picker("Рингтон", selection: $defaultRingtone) {
                    ForEach(AlarmRingtone.allCases) { ringtone in
                        Text(ringtone.title).tag(ringtone.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white.opacity(0.7))
                .onChange(of: defaultRingtone) { _, newValue in
                    let ringtone = AlarmRingtone(rawValue: newValue) ?? .crystal
                    alarmStore.previewRingtone(ringtone)
                }
            }
            .padding(.vertical, 4)

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
        VStack(alignment: .leading, spacing: 12) {
            Text("Проверка")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    alarmStore.previewRingtone(selectedRingtone)
                } label: {
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("Звук")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    alarmStore.previewVibration()
                } label: {
                    VStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.title2)
                        Text("Вибро")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    alarmStore.stopRingtonePreview()
                } label: {
                    VStack {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text("Стоп")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { @MainActor in
                    isSchedulingTest = true
                    let ok = await alarmStore.scheduleTestNotification(after: 5)
                    isSchedulingTest = false
                    statusMessage = ok
                        ? "Тестовое уведомление через 5 сек. Сверните приложение!"
                        : "Разрешите уведомления в настройках iOS!"
                }
            } label: {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text(isSchedulingTest ? "Планирую..." : "Тестовый пуш через 5 сек")
                    Spacer()
                    if isSchedulingTest {
                        ProgressView().tint(.white)
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isSchedulingTest)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "alarm.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 10)
            }
            .padding(.top, 10)
            .onTapGesture {
                handleSecretTap()
            }

            VStack(spacing: 4) {
                Text("Glass Alarm")
                    .font(.title2.bold())
                Text("Premium Edition")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }

            Text("Версия 1.1.0 (Unique Build)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .opacity(0.5)

            Text("Первый в мире будильник с эффектом матового стекла и защитой от дубликатов Apple App Store.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(0.8)

            Divider().background(Color.white.opacity(0.2))

            VStack(spacing: 8) {
                HStack {
                    Label("Поддержка", systemImage: "heart.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.subheadline)
                .opacity(0.7)
            }
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(24)
        .glassCard()
    }

    private func handleSecretTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.5 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now

        if tapCount >= 5 {
            tapCount = 0
            HapticsService.playAlarmPreview()
            showingGame = true
        }
    }
}
